/**
 * Builds {@link HttpRequest} objects.
 */
public with sharing class HttpRequestBuilder {
  private final Map<String, String> header = new Map<String, String>();
  private String body;
  private Blob bodyBlob;
  private String endpoint;
  private HttpMethod method;
  private Integer timeout;

  /**
   * Returns a new http request builder.
   */
  public static HttpRequestBuilder newBuilder() {
    return new HttpRequestBuilder();
  }

  /**
   * Adds a request header, returning the request builder for chaining.
   */
  public HttpRequestBuilder addHeader(HttpHeaderKey key, HttpHeaderValue value) {
    return addHeader(
      HttpHeaderConstants.getHeaderKey(key),
      HttpHeaderConstants.getHeaderValue(value)
    );
  }

  /**
   * Adds a request header, returning the request builder for chaining.
   */
  public HttpRequestBuilder addHeader(HttpHeaderKey key, String value) {
    return addHeader(HttpHeaderConstants.getHeaderKey(key), value);
  }

  /**
   * Adds a request header, returning the request builder for chaining.
   */
  public HttpRequestBuilder addHeader(String key, HttpHeaderValue value) {
    return addHeader(key, HttpHeaderConstants.getHeaderValue(value));
  }

  /**
   * Adds a request header, returning the request builder for chaining.
   */
  public HttpRequestBuilder addHeader(String key, String value) {
    this.header.put(key, value);
    return this;
  }

  /**
   * Sets the request body, returning the request builder for chaining.
   */
  public HttpRequestBuilder setBody(String body) {
    this.body = body;
    return this;
  }

  /**
   * Sets the request body, returning the request builder for chaining.
   */
  public HttpRequestBuilder setBody(Blob body) {
    this.bodyBlob = body;
    return this;
  }

  /**
   * Sets the request endpoint, returning the request builder for chaining.
   */
  public HttpRequestBuilder setEndpoint(String endpoint) {
    this.endpoint = endpoint;
    return this;
  }

  /**
   * Sets the request method, returning the request builder for chaining.
   */
  public HttpRequestBuilder setMethod(HttpMethod method) {
    this.method = method;
    return this;
  }

  /**
   * Sets the request timeout, returning the request builder for chaining.
   */
  public HttpRequestBuilder setTimeout(Integer timeout) {
    this.timeout = timeout;
    return this;
  }

  /**
   * Builds and returns the request.
   */
  public HttpRequest build() {
    HttpRequest request = new HttpRequest();
    for (String key : header.keySet()) {
      request.setHeader(key, header.get(key));
    }

    if (bodyBlob != null) {
      // Note: Do NOT set Content-Length manually when using setBodyAsBlob().
      // Salesforce sets it automatically, and manually setting it breaks
      // AWS SigV4 signature calculation when using Named Credentials.
      request.setBodyAsBlob(bodyBlob);
    } else if (String.isNotBlank(body)) {
      request.setBody(body);
    }

    if (String.isNotBlank(endpoint)) {
      request.setEndpoint(endpoint);
    }

    if (method != null) {
      request.setMethod(method.name().remove('HTTP_'));
    }

    if (timeout != null) {
      request.setTimeout(timeout);
    }

    return request;
  }

  private HttpRequestBuilder() {
  }
}