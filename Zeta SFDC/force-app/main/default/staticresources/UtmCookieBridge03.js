/*
 * Head Markup bridge for the UTM source cookies. Loaded from the parent portal's
 * Head Markup as a same-origin static resource, so it runs outside Lightning
 * Web Security, which hides cookies written by other scripts from Lightning
 * components. zetaApplication asks with a 'utmbridge:request' event on
 * document; this answers with a 'utmbridge:value' event carrying
 * { utmSource } as
 * "utm_first: utm_source,utm_medium,utm_campaign | utm_last: utm_source,utm_medium,utm_campaign"
 * (a missing field keeps its comma slot so the csv stays positional; null
 * when both cookies are absent, so the ?utm_source URL value still applies).
 */
(function () {
  'use strict';

  // The tag manager must write these on .zetaschools.org for the portal to see them,
  // each as a JSON object: {"utm_source":"...","utm_medium":"...","utm_campaign":"..."}.
  const FIRST_COOKIE = 'utm_first';
  const LAST_COOKIE = 'utm_last';
  const MAX_FIELD_LENGTH = 255;
  const FIELDS = ['utm_source', 'utm_medium', 'utm_campaign'];

  function decode(value) {
    let decoded = value;
    for (let i = 0; i < 2 && /%[0-9a-f]{2}/i.test(decoded); i++) {
      try {
        decoded = decodeURIComponent(decoded);
      } catch (e) {
        break;
      }
    }
    return decoded;
  }

  function sanitize(value) {
    return typeof value === 'string'
      ? decode(value).replace(/[|,]/g, '/').trim().slice(0, MAX_FIELD_LENGTH)
      : '';
  }

  // Builds the "utm_source,utm_medium,utm_campaign" csv for one cookie. A
  // missing field, or a missing/unparsable cookie, keeps its slot blank
  // rather than shifting the remaining fields.
  function csvFrom(raw) {
    let parsed = null;
    if (typeof raw === 'string') {
      try {
        parsed = JSON.parse(decode(raw.trim()));
      } catch (e) {
        parsed = null;
      }
    }
    const fields = parsed && typeof parsed === 'object' ? parsed : {};
    return FIELDS.map((field) => sanitize(fields[field])).join(',');
  }

  function readCookie(name) {
    try {
      const pairs = document.cookie ? document.cookie.split(';') : [];
      for (const pair of pairs) {
        const index = pair.indexOf('=');
        if (index < 0 || pair.slice(0, index).trim() !== name) {
          continue;
        }
        return pair.slice(index + 1);
      }
    } catch (e) {
      /* cookies unavailable */
    }
    return null;
  }

  function answer() {
    const firstRaw = readCookie(FIRST_COOKIE);
    const lastRaw = readCookie(LAST_COOKIE);
    const utmSource =
      firstRaw === null && lastRaw === null
        ? null
        : 'utm_first: ' +
          csvFrom(firstRaw) +
          ' | utm_last: ' +
          csvFrom(lastRaw);
    document.dispatchEvent(
      new CustomEvent('utmbridge:value', { detail: { utmSource } })
    );
  }

  document.addEventListener('utmbridge:request', answer);
  answer();
})();
