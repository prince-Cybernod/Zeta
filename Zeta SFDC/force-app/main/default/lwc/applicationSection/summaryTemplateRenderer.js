// Token grammar for Application_Section__mdt.Summary_Template__c.
//
// Supported tokens:
//   {QuestionDevName}                    — value lookup; if blank, leading separator
//                                          in the following literal collapses.
//   {Q ? "yes-text" : "no-text"}         — ternary; yes-text when the answer is
//                                          truthy (non-blank, non-false), else
//                                          no-text. Works for booleans AND for
//                                          value-presence gates (e.g. showing a
//                                          separator only when a text answer is
//                                          filled).
//   {address:Q}                          — format an Address-question answer
//                                          ({street, subpremise, city, province,
//                                          postalCode, country}) as
//                                          "Street, Apt N, City, State Zip".
//
// Blank-token rule: when a token evaluates to empty/null, the leading separator
// chars of the following literal (`,`, ` · `, `-`, `|`, whitespace) are stripped
// so we don't strand separators. The result is then trimmed.

const TOKEN_RE = /\{([^}]+)\}/g;
const LEADING_SEPARATOR_RE = /^[\s,·\-•|]+/;
const TRAILING_SEPARATOR_RE = /[\s,·\-•|]+$/;
const TERNARY_RE =
  /^([A-Za-z_][A-Za-z0-9_]*)\s*\?\s*"([^"]*)"\s*:\s*"([^"]*)"$/;
const ADDRESS_RE = /^address:([A-Za-z_][A-Za-z0-9_]*)$/;

export function renderSummary(template, answers) {
  if (!template) {
    return '';
  }
  const parts = [];
  let lastEnd = 0;
  let match;
  TOKEN_RE.lastIndex = 0;
  while ((match = TOKEN_RE.exec(template)) !== null) {
    parts.push({
      type: 'literal',
      value: template.slice(lastEnd, match.index)
    });
    parts.push({
      type: 'token',
      value: evaluateToken(match[1].trim(), answers || {})
    });
    lastEnd = match.index + match[0].length;
  }
  parts.push({ type: 'literal', value: template.slice(lastEnd) });

  for (let i = 0; i < parts.length; i++) {
    const p = parts[i];
    if (p.type === 'token' && isBlank(p.value)) {
      // Strip the separator that would have followed this token. Don't touch
      // the preceding literal — that's what separates the previous token from
      // whatever comes after this blank one, and removing it smushes them
      // together ("John Smith · " + "" + " · Father" -> "John SmithFather").
      const next = parts[i + 1];
      if (next && next.type === 'literal' && next.value !== '') {
        next.value = next.value.replace(LEADING_SEPARATOR_RE, '');
      } else if (i > 0) {
        // Blank token at the tail (no useful next literal) — drop the
        // trailing separator from the preceding literal so we don't end
        // with a stranded " · ".
        const prev = parts[i - 1];
        if (prev && prev.type === 'literal') {
          prev.value = prev.value.replace(TRAILING_SEPARATOR_RE, '');
        }
      }
    }
  }

  return parts
    .map((p) =>
      (p.value === null || p.value === undefined ? '' : String(p.value))
    )
    .join('')
    .replace(LEADING_SEPARATOR_RE, '')
    .replace(TRAILING_SEPARATOR_RE, '')
    .trim();
}

function evaluateToken(expr, answers) {
  const ternary = expr.match(TERNARY_RE);
  if (ternary) {
    const [, q, yesText, noText] = ternary;
    // Truthy = present, non-empty, and not boolean false. This lets a ternary
    // gate on ANY answer — including a free-text value like "Anything else" —
    // decide whether to render its separator, not just boolean checkboxes.
    // Booleans are unchanged: true -> yes-text, false -> no-text.
    const value = answers[q];
    return !isBlank(value) && value !== false ? yesText : noText;
  }
  const address = expr.match(ADDRESS_RE);
  if (address) {
    return formatAddress(answers[address[1]]);
  }
  const value = answers[expr];
  if (value === null || value === undefined || value === false) {
    return '';
  }
  if (value === true) {
    return 'Yes';
  }
  if (typeof value === 'object') {
    return '';
  }
  return String(value);
}

function formatAddress(addr) {
  if (!addr || typeof addr !== 'object') {
    return '';
  }
  const parts = [];
  if (addr.street) {
    let line = String(addr.street);
    if (addr.subpremise) {
      line += `, Apt ${addr.subpremise}`;
    }
    parts.push(line);
  } else if (addr.subpremise) {
    parts.push(`Apt ${addr.subpremise}`);
  }
  if (addr.city) {
    parts.push(String(addr.city));
  }
  const stateZip = [addr.province, addr.postalCode]
    .filter((v) => v !== null && v !== undefined && v !== '')
    .join(' ');
  if (stateZip) {
    parts.push(stateZip);
  }
  return parts.join(', ');
}

function isBlank(value) {
  if (value === null || value === undefined) return true;
  if (typeof value === 'string') return value === '';
  return false;
}