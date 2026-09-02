/**
 * Constants for HTTP headers.
 */
public with sharing class HttpHeaderConstants {
  public static final Map<String, HttpHeaderKey> HEADER_KEY_MAP {
    get {
      if (HEADER_KEY_MAP == null) {
        HEADER_KEY_MAP = new Map<String, HttpHeaderKey>{
          'Authorization' => HttpHeaderKey.AUTHORIZATION,
          'Content-Type' => HttpHeaderKey.CONTENT_TYPE,
          'Accept' => HttpHeaderKey.ACCEPT,
          'User-Agent' => HttpHeaderKey.USER_AGENT,
          'Cache-Control' => HttpHeaderKey.CACHE_CONTROL,
          'Content-Length' => HttpHeaderKey.CONTENT_LENGTH,
          'Accept-Encoding' => HttpHeaderKey.ACCEPT_ENCODING,
          'Connection' => HttpHeaderKey.CONNECTION,
          'Host' => HttpHeaderKey.HOST,
          'If-Modified-Since' => HttpHeaderKey.IF_MODIFIED_SINCE,
          'If-None-Match' => HttpHeaderKey.IF_NONE_MATCH,
          'Referer' => HttpHeaderKey.REFERER,
          'X-Requested-With' => HttpHeaderKey.X_REQUESTED_WITH,
          'X-Forwarded-For' => HttpHeaderKey.X_FORWARDED_FOR,
          'Accept-Language' => HttpHeaderKey.ACCEPT_LANGUAGE,
          'Cookie' => HttpHeaderKey.COOKIE,
          'Set-Cookie' => HttpHeaderKey.SET_COOKIE
        };
      }
      return HEADER_KEY_MAP;
    }
    private set;
  }

  public static final Map<HttpHeaderKey, String> HEADER_KEY_REVERSE_MAP {
    get {
      if (HEADER_KEY_REVERSE_MAP == null) {
        HEADER_KEY_REVERSE_MAP = new Map<HttpHeaderKey, String>();
        for (String key : HEADER_KEY_MAP.keySet()) {
          HEADER_KEY_REVERSE_MAP.put(HEADER_KEY_MAP.get(key), key);
        }
      }
      return HEADER_KEY_REVERSE_MAP;
    }
    private set;
  }

  public static final Map<String, HttpHeaderValue> HEADER_VALUE_MAP {
    get {
      if (HEADER_VALUE_MAP == null) {
        HEADER_VALUE_MAP = new Map<String, HttpHeaderValue>{
          'application/json' => HttpHeaderValue.APPLICATION_JSON,
          'application/xml' => HttpHeaderValue.APPLICATION_XML,
          'text/html' => HttpHeaderValue.TEXT_HTML,
          'text/plain' => HttpHeaderValue.TEXT_PLAIN,
          'application/x-www-form-urlencoded' => HttpHeaderValue.APPLICATION_FORM_URLENCODED,
          'multipart/form-data' => HttpHeaderValue.MULTIPART_FORM_DATA,
          'no-cache' => HttpHeaderValue.NO_CACHE,
          'no-store' => HttpHeaderValue.NO_STORE,
          'max-age=0' => HttpHeaderValue.MAX_AGE_ZERO,
          'keep-alive' => HttpHeaderValue.KEEP_ALIVE,
          'close' => HttpHeaderValue.CLOSE,
          'gzip' => HttpHeaderValue.GZIP,
          'deflate' => HttpHeaderValue.DEFLATE,
          'br' => HttpHeaderValue.BROTLI,
          'XMLHttpRequest' => HttpHeaderValue.XMLHTTPREQUEST
        };
      }
      return HEADER_VALUE_MAP;
    }
    private set;
  }

  public static final Map<HttpHeaderValue, String> HEADER_VALUE_REVERSE_MAP {
    get {
      if (HEADER_VALUE_REVERSE_MAP == null) {
        HEADER_VALUE_REVERSE_MAP = new Map<HttpHeaderValue, String>();
        for (String key : HEADER_VALUE_MAP.keySet()) {
          HEADER_VALUE_REVERSE_MAP.put(HEADER_VALUE_MAP.get(key), key);
        }
      }
      return HEADER_VALUE_REVERSE_MAP;
    }
    private set;
  }

  /**
   * Gets the string representation of an HTTP header key.
   */
  public static String getHeaderKey(HttpHeaderKey headerKey) {
    return HEADER_KEY_REVERSE_MAP.get(headerKey);
  }

  /**
   * Gets the enum representation of an HTTP header key string.
   */
  public static HttpHeaderKey getHeaderKey(String headerKeyString) {
    return HEADER_KEY_MAP.get(headerKeyString);
  }

  /**
   * Gets the string representation of an HTTP header value.
   */
  public static String getHeaderValue(HttpHeaderValue headerValue) {
    return HEADER_VALUE_REVERSE_MAP.get(headerValue);
  }

  /**
   * Gets the enum representation of an HTTP header value string.
   */
  public static HttpHeaderValue getHeaderValue(String headerValueString) {
    return HEADER_VALUE_MAP.get(headerValueString);
  }
}