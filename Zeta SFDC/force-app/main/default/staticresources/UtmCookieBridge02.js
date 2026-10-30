/*
 * Head Markup bridge for the UTM source cookies. Loaded from the parent portal's
 * Head Markup as a same-origin static resource, so it runs outside Lightning
 * Web Security, which hides cookies written by other scripts from Lightning
 * components. zetaApplication asks with a 'utmbridge:request' event on
 * document; this answers with a 'utmbridge:value' event carrying
 * { utmSource } as "first | last" (a missing side is blank; null when both
 * are missing, so the ?utm_source URL value still applies).
 */
(function () {
  'use strict';

  // The tag manager must write these on .zetaschools.org for the portal to see them.
  const FIRST_COOKIE = 'utm_first';
  const LAST_COOKIE = 'utm_last';
  const MAX_SIDE_LENGTH = 255;

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

  // The cookie format is not fixed: accept a bare source, a
  // utm_source=..&utm_medium=.. string, or a JSON object.
  function sourceFrom(raw) {
    let value = decode(raw.trim());
    if (
      value.length > 1 &&
      value[0] === '"' &&
      value[value.length - 1] === '"'
    ) {
      value = value.slice(1, -1);
    }
    value = value.trim();
    if (value[0] === '{') {
      try {
        const parsed = JSON.parse(value);
        const source = parsed && (parsed.utm_source || parsed.source);
        value = typeof source === 'string' ? source : '';
      } catch (e) {
        /* not JSON - keep the raw value */
      }
    } else if (value.indexOf('=') >= 0) {
      const params = new URLSearchParams(value.replace(/^\?/, ''));
      value = params.get('utm_source') || params.get('source') || '';
    }
    return value.replace(/\|/g, '/').trim().slice(0, MAX_SIDE_LENGTH);
  }

  function readCookie(name) {
    try {
      const pairs = document.cookie ? document.cookie.split(';') : [];
      for (const pair of pairs) {
        const index = pair.indexOf('=');
        if (index < 0 || pair.slice(0, index).trim() !== name) {
          continue;
        }
        return sourceFrom(pair.slice(index + 1));
      }
    } catch (e) {
      /* cookies unavailable */
    }
    return '';
  }

  function answer() {
    const first = readCookie(FIRST_COOKIE);
    const last = readCookie(LAST_COOKIE);
    document.dispatchEvent(
      new CustomEvent('utmbridge:value', {
        detail: { utmSource: first || last ? first + ' | ' + last : null }
      })
    );
  }

  document.addEventListener('utmbridge:request', answer);
  answer();
})();
