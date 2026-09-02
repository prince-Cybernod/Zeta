/**
 * Enumeration of common HTTP header values.
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers
 */
public enum HttpHeaderValue {
  /**
   * APPLICATION_JSON
   *
   * Media type for JSON data format.
   */
  APPLICATION_JSON,
  /**
   * APPLICATION_XML
   *
   * Media type for XML data format.
   */
  APPLICATION_XML,
  /**
   * TEXT_HTML
   *
   * Media type for HTML documents.
   */
  TEXT_HTML,
  /**
   * TEXT_PLAIN
   *
   * Media type for plain text.
   */
  TEXT_PLAIN,
  /**
   * APPLICATION_FORM_URLENCODED
   *
   * Media type for form data encoded as key-value pairs.
   */
  APPLICATION_FORM_URLENCODED,
  /**
   * MULTIPART_FORM_DATA
   *
   * Media type for form data that can contain files.
   */
  MULTIPART_FORM_DATA,
  /**
   * NO_CACHE
   *
   * Cache control directive that prevents caching.
   */
  NO_CACHE,
  /**
   * NO_STORE
   *
   * Cache control directive that prevents storing the response.
   */
  NO_STORE,
  /**
   * MAX_AGE_ZERO
   *
   * Cache control directive that sets maximum age to zero.
   */
  MAX_AGE_ZERO,
  /**
   * KEEP_ALIVE
   *
   * Connection value that keeps the connection open.
   */
  KEEP_ALIVE,
  /**
   * CLOSE
   *
   * Connection value that closes the connection after the response.
   */
  CLOSE,
  /**
   * GZIP
   *
   * Compression encoding method.
   */
  GZIP,
  /**
   * DEFLATE
   *
   * Compression encoding method.
   */
  DEFLATE,
  /**
   * BROTLI
   *
   * Compression encoding method.
   */
  BROTLI,
  /**
   * XMLHTTPREQUEST
   *
   * Standard value for X-Requested-With header indicating an Ajax request.
   */
  XMLHTTPREQUEST
}