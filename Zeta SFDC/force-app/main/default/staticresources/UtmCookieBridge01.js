/*
 * Head Markup bridge for the UTM source cookie. Loaded from the parent portal's
 * Head Markup as a same-origin static resource, so it runs outside Lightning
 * Web Security, which hides cookies written by other scripts from Lightning
 * components. zetaApplication asks with a 'utmbridge:request' event on
 * document; this answers with a 'utmbridge:value' event carrying
 * { utmSource } (null when the cookie is missing or empty).
 */
(function () {
  'use strict';

  // First-party cookie the site's tag manager stores the UTM source in.
  const COOKIE_NAME = 'utm_source';

  function readCookie(name) {
    try {
      const pairs = document.cookie ? document.cookie.split(';') : [];
      for (const pair of pairs) {
        const index = pair.indexOf('=');
        if (index < 0 || pair.slice(0, index).trim() !== name) {
          continue;
        }
        let value = pair.slice(index + 1).trim();
        if (
          value.length > 1 &&
          value[0] === '"' &&
          value[value.length - 1] === '"'
        ) {
          value = value.slice(1, -1);
        }
        try {
          value = decodeURIComponent(value);
        } catch (e) {
          /* malformed escape - keep the raw value */
        }
        value = value.trim();
        return value || null;
      }
    } catch (e) {
      /* cookies unavailable */
    }
    return null;
  }

  function answer() {
    document.dispatchEvent(
      new CustomEvent('utmbridge:value', {
        detail: { utmSource: readCookie(COOKIE_NAME) }
      })
    );
  }

  document.addEventListener('utmbridge:request', answer);
  answer();
})();
