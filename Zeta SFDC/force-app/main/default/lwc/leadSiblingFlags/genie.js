/**
 * Geometry for the toast's macOS-style genie dismissal.
 *
 * The toast is restaged as a stack of thin horizontal slices, each clipped to
 * its own band of the panel and given its own translate and scale at six shared
 * keyframe stops sampled from a funnel curve. The stack is therefore a
 * piecewise-affine approximation of a genuinely non-affine warp: the side walls
 * curve inward, the neck travels, and the top edge trails last. The slices share
 * one animation with no stagger - the shape comes from their geometry, not from
 * their timing, which is what keeps neighbouring bands edge-continuous.
 */
const STOPS = 6;
const MIN_STRIPS = 28;
const MAX_STRIPS = 48;
const STRIP_PER_PX = 1 / 11;
const OVERLAP = 0.5; // px of extra band each side, kills sub-pixel hairlines
const SPREAD = 0.55; // peak share of the path the panel is smeared over
const NECK = 2.2; // funnel exponent, higher is a tighter neck
const NECK_LAG = 0.25; // the neck forms at the bottom of the panel first
const NECK_RAMP = 0.34;
const TAIL_WIDTH = 0.055; // width at the target, as a share of the panel
const MIN_SCALE = 0.02;
const MIN_SPAN = 1.25; // shortest travel worth animating, in panel heights
const MAX_SPAN = 9; // longest, so an off-screen banner cannot smear forever

export const GENIE_HEADING = "Possible siblings or duplicates";
export const GENIE_BODY =
  "It looks as if duplicates or siblings exist for this Lead.";
export const GENIE_ACTION = "View Here";

const clamp01 = (value) => Math.min(1, Math.max(0, value));
const smooth = (value) => {
  const t = clamp01(value);
  return t * t * (3 - 2 * t);
};
const trim = (value) => Math.round(value * 1000) / 1000;

/** Where the panel's top edge sits on the path at progress p. */
const head = (p) => Math.pow(p, 1.8);
/** How much of the path the panel is smeared over at progress p. */
const reach = (p, rest) =>
  rest * (1 - p) + SPREAD * Math.sin(Math.PI * Math.pow(p, 0.85));
/** Funnel half-width at path fraction f, as a share of the panel width. */
const funnel = (f) => TAIL_WIDTH + (1 - TAIL_WIDTH) * Math.pow(1 - f, NECK);

/** A child's offset box, with the toast-pump scale divided back out. */
function inset(rect, node, scale) {
  const box = node?.getBoundingClientRect();
  if (!box || !box.width || !box.height) return undefined;
  return {
    left: (box.left - rect.left) / scale,
    top: (box.top - rect.top) / scale,
    width: box.width / scale,
    height: box.height / scale
  };
}

/**
 * Reads the toast's resting geometry. `toast-pump` is an infinite scale about
 * the centre, so the rect is usually read mid-pump; offsetWidth/offsetHeight
 * are layout values that ignore transforms, which both gives the true box and
 * yields the factor to divide the child offsets by.
 * @returns {object|undefined} undefined when nothing has been laid out yet.
 */
export function measureToast(toast) {
  const rect = toast.getBoundingClientRect();
  const width = toast.offsetWidth;
  const height = toast.offsetHeight;
  if (!width || !height || !rect.width) return undefined;
  const scale = rect.width / width;
  const copy = inset(rect, toast.querySelector(".slds-notify__content"), scale);
  const glyph = inset(rect, toast.querySelector("lightning-icon"), scale);
  if (!copy || !glyph) return undefined;
  return {
    width,
    height,
    top: rect.top + rect.height / 2 - height / 2,
    centreX: rect.left + rect.width / 2,
    copy,
    glyph
  };
}

function stopVars(band) {
  const { depthTop, depthBottom, top, height, travel, drift, rest } = band;
  const depth = (depthTop + depthBottom) / 2;
  const vars = [];
  for (let stop = 1; stop <= STOPS; stop += 1) {
    const p = stop / STOPS;
    const spread = reach(p, rest);
    const edgeTop = clamp01(head(p) + depthTop * spread);
    const edgeBottom = clamp01(head(p) + depthBottom * spread);
    const middle = (edgeTop + edgeBottom) / 2;
    const neck = smooth((p - NECK_LAG * (1 - depth)) / NECK_RAMP);
    const stretch = (travel * (edgeBottom - edgeTop)) / height;
    vars.push(
      `--x${stop}:${trim(neck * drift * Math.pow(middle, 1.35))}px`,
      `--y${stop}:${trim(travel * middle - top - height / 2)}px`,
      `--a${stop}:${trim(1 - neck * (1 - funnel(middle)))}`,
      `--b${stop}:${trim(Math.max(MIN_SCALE, stretch))}`
    );
  }
  return vars;
}

/**
 * Precomputes the slice stack.
 * @param {object} box result of measureToast
 * @param {DOMRect} banner rect of the element the toast is drawn into
 * @returns {object|undefined} undefined when there is nothing sensible to
 * animate, in which case the caller leaves the toast's own collapse to play.
 */
export function buildGenie(box, banner) {
  if (!box || !banner?.height) return undefined;
  const { width, height, copy, glyph } = box;
  const span = banner.top + banner.height / 2 - box.top;
  if (span < height * MIN_SPAN) return undefined;
  const travel = Math.min(span, height * MAX_SPAN);
  const drift = banner.left + banner.width / 2 - box.centreX;
  const count = Math.min(
    MAX_STRIPS,
    Math.max(MIN_STRIPS, Math.round(width * STRIP_PER_PX))
  );
  const rest = height / travel;
  const strips = [];

  for (let index = 0; index < count; index += 1) {
    const top = (index * height) / count;
    strips.push({
      key: `genie-${index}`,
      style: [
        `top:${trim(top - OVERLAP)}px`,
        `height:${trim(height / count + OVERLAP * 2)}px`,
        `z-index:${count - index}`,
        `--face-y:${trim(OVERLAP - top)}px`,
        ...stopVars({
          depthTop: index / count,
          depthBottom: (index + 1) / count,
          top,
          height: height / count,
          travel,
          drift,
          rest
        })
      ].join(";")
    });
  }

  return {
    strips,
    heading: GENIE_HEADING,
    body: GENIE_BODY,
    action: GENIE_ACTION,
    stageStyle: [
      `--genie-w:${trim(width)}px`,
      `--genie-h:${trim(height)}px`,
      `--copy-x:${trim(copy.left)}px`,
      `--copy-y:${trim(copy.top)}px`,
      `--copy-w:${trim(copy.width)}px`,
      `--glyph-x:${trim(glyph.left)}px`,
      `--glyph-y:${trim(glyph.top)}px`,
      `--glyph-w:${trim(glyph.width)}px`,
      `--glyph-h:${trim(glyph.height)}px`
    ].join(";")
  };
}
