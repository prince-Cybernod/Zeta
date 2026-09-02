/**
 * Utility class for building common HTTP header values.
 */
public with sharing class HttpHeaderValues {
  /**
   * Builds a Bearer token authorization header value.
   *
   * @param token The bearer token
   * @return Authorization header value in format "Bearer {token}"
   */
  public static String bearer(String token) {
    Preconditions.checkArgument(String.isNotBlank(token), 'Token cannot be blank');
    return 'Bearer ' + token;
  }

  /**
   * Builds a Basic authentication authorization header value.
   *
   * @param username The username
   * @param password The password
   * @return Authorization header value in format "Basic {base64(username:password)}"
   */
  public static String basicAuth(String username, String password) {
    Preconditions.checkArgument(String.isNotBlank(username), 'Username cannot be blank');
    Preconditions.checkArgument(String.isNotBlank(password), 'Password cannot be blank');
    String credentials = username + ':' + password;
    String encodedCredentials = EncodingUtil.base64Encode(Blob.valueOf(credentials));
    return 'Basic ' + encodedCredentials;
  }

  /**
   * Builds an API key authorization header value.
   *
   * @param apiKey The API key
   * @return Authorization header value in format "ApiKey {apiKey}"
   */
  public static String apiKey(String apiKey) {
    Preconditions.checkArgument(String.isNotBlank(apiKey), 'API key cannot be blank');
    return 'ApiKey ' + apiKey;
  }

  /**
   * Builds a custom authorization header value.
   *
   * @param scheme The authorization scheme (e.g., "Bearer", "Basic", "Custom")
   * @param credentials The credentials
   * @return Authorization header value in format "{scheme} {credentials}"
   */
  public static String customAuth(String scheme, String credentials) {
    Preconditions.checkArgument(String.isNotBlank(scheme), 'Scheme cannot be blank');
    Preconditions.checkArgument(String.isNotBlank(credentials), 'Credentials cannot be blank');
    return scheme + ' ' + credentials;
  }

  /**
   * Builds a Content-Type header value with charset.
   *
   * @param mediaType The media type (e.g., "application/json", "text/html")
   * @param charset The character set (e.g., "UTF-8", "ISO-8859-1")
   * @return Content-Type header value in format "{mediaType}; charset={charset}"
   */
  public static String contentTypeWithCharset(String mediaType, String charset) {
    Preconditions.checkArgument(String.isNotBlank(mediaType), 'Media type cannot be blank');
    if (String.isBlank(charset)) {
      return mediaType;
    }
    return mediaType + '; charset=' + charset;
  }

  /**
   * Builds a Content-Type header value with boundary (for multipart forms).
   *
   * @param boundary The boundary string
   * @return Content-Type header value in format "multipart/form-data; boundary={boundary}"
   */
  public static String multipartFormData(String boundary) {
    Preconditions.checkArgument(String.isNotBlank(boundary), 'Boundary cannot be blank');
    return 'multipart/form-data; boundary=' + boundary;
  }

  /**
   * Builds an Accept header value with quality values.
   *
   * @param mediaTypes List of media types with optional quality values
   * @return Accept header value (e.g., "application/json, text/html;q=0.9, text/plain;q=0.8")
   */
  public static String accept(List<String> mediaTypes) {
    Preconditions.checkNotNull(mediaTypes, 'Media types list cannot be null');
    Preconditions.checkArgument(!mediaTypes.isEmpty(), 'Media types list cannot be empty');
    return String.join(mediaTypes, ', ');
  }

  /**
   * Builds an Accept header value with a single media type and quality.
   *
   * @param mediaType The media type
   * @param quality The quality value (0.0 to 1.0)
   * @return Accept header value in format "{mediaType};q={quality}"
   */
  public static String acceptWithQuality(String mediaType, Decimal quality) {
    Preconditions.checkArgument(String.isNotBlank(mediaType), 'Media type cannot be blank');
    Preconditions.checkNotNull(quality, 'Quality cannot be null');
    Preconditions.checkArgument(
      quality >= 0 && quality <= 1,
      'Quality must be between 0.0 and 1.0'
    );
    if (quality == 1.0) {
      return mediaType;
    }
    return mediaType + ';q=' + String.valueOf(quality);
  }

  /**
   * Builds a Cache-Control header value with max-age.
   *
   * @param maxAgeSeconds The maximum age in seconds
   * @return Cache-Control header value in format "max-age={maxAgeSeconds}"
   */
  public static String cacheControlMaxAge(Integer maxAgeSeconds) {
    Preconditions.checkNotNull(maxAgeSeconds, 'Max age cannot be null');
    Preconditions.checkArgument(maxAgeSeconds >= 0, 'Max age must be a non-negative integer');
    return 'max-age=' + maxAgeSeconds;
  }

  /**
   * Builds a Cache-Control header value with multiple directives.
   *
   * @param directives List of cache control directives
   * @return Cache-Control header value (e.g., "no-cache, no-store, must-revalidate")
   */
  public static String cacheControl(List<String> directives) {
    Preconditions.checkNotNull(directives, 'Directives list cannot be null');
    Preconditions.checkArgument(!directives.isEmpty(), 'Directives list cannot be empty');
    return String.join(directives, ', ');
  }

  /**
   * Builds a User-Agent header value.
   *
   * @param applicationName The application name
   * @param version The application version
   * @param additionalInfo Optional additional information
   * @return User-Agent header value
   */
  public static String userAgent(String applicationName, String version, String additionalInfo) {
    Preconditions.checkArgument(
      String.isNotBlank(applicationName),
      'Application name cannot be blank'
    );
    String userAgent = applicationName;
    if (String.isNotBlank(version)) {
      userAgent += '/' + version;
    }
    if (String.isNotBlank(additionalInfo)) {
      userAgent += ' (' + additionalInfo + ')';
    }
    return userAgent;
  }

  /**
   * Builds a User-Agent header value with just application name and version.
   *
   * @param applicationName The application name
   * @param version The application version
   * @return User-Agent header value in format "{applicationName}/{version}"
   */
  public static String userAgent(String applicationName, String version) {
    return userAgent(applicationName, version, null);
  }

  /**
   * Builds an Accept-Language header value.
   *
   * @param languages List of language codes with optional quality values
   * @return Accept-Language header value (e.g., "en-US, en;q=0.9, fr;q=0.8")
   */
  public static String acceptLanguage(List<String> languages) {
    Preconditions.checkNotNull(languages, 'Languages list cannot be null');
    Preconditions.checkArgument(!languages.isEmpty(), 'Languages list cannot be empty');
    return String.join(languages, ', ');
  }

  /**
   * Builds an Accept-Encoding header value.
   *
   * @param encodings List of encoding methods
   * @return Accept-Encoding header value (e.g., "gzip, deflate, br")
   */
  public static String acceptEncoding(List<String> encodings) {
    Preconditions.checkNotNull(encodings, 'Encodings list cannot be null');
    Preconditions.checkArgument(!encodings.isEmpty(), 'Encodings list cannot be empty');
    return String.join(encodings, ', ');
  }

  /**
   * Builds a Cookie header value from a map of cookie names and values.
   *
   * @param cookies Map of cookie names to values
   * @return Cookie header value (e.g., "name1=value1; name2=value2")
   */
  public static String cookie(Map<String, String> cookies) {
    Preconditions.checkNotNull(cookies, 'Cookies map cannot be null');
    Preconditions.checkArgument(!cookies.isEmpty(), 'Cookies map cannot be empty');
    List<String> cookieStrings = new List<String>();
    for (String name : cookies.keySet()) {
      if (String.isNotBlank(name) && cookies.get(name) != null) {
        cookieStrings.add(name + '=' + cookies.get(name));
      }
    }
    return String.join(cookieStrings, '; ');
  }

  /**
   * Builds a single cookie string.
   *
   * @param name The cookie name
   * @param value The cookie value
   * @return Cookie string in format "name=value"
   */
  public static String cookie(String name, String value) {
    Preconditions.checkArgument(String.isNotBlank(name), 'Cookie name cannot be blank');
    if (value == null) {
      value = '';
    }
    return name + '=' + value;
  }
}