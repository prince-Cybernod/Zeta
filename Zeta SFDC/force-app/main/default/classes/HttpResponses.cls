/**
 * Common {@link HttpResponse} objects.
 */
public with sharing class HttpResponses {
  /**
   * Returns a response indicating that the request has succeeded.
   *
   * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/200
   */
  public static HttpResponse ok(String body) {
    return newBuilder().setStatusCode(200).setStatus('OK').setBody(body).build();
  }

  /**
   * Returns a response indicating that the request has been fulfilled and has resulted in one or more new resources being created.
   *
   * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/201
   */
  public static HttpResponse created(String body) {
    return newBuilder().setStatusCode(201).setStatus('Created').setBody(body).build();
  }

  /**
   * Returns a response indicating that the request has been accepted for processing, but the processing has not been completed.
   *
   * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/202
   */
  public static HttpResponse accepted(String body) {
    return newBuilder().setStatusCode(202).setStatus('Accepted').setBody(body).build();
  }

  /**
   * Returns a response indicating that the server successfully processed the request, but is not returning any content.
   *
   * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/204
   */
  public static HttpResponse noContent() {
    return newBuilder().setStatusCode(204).setStatus('No Content').build();
  }

  /**
   * Returns a response indicating that the request was not understood due to invalid syntax.
   *
   * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/400
   */
  public static HttpResponse badRequest(String body) {
    return newBuilder().setStatusCode(400).setStatus('Bad Request').setBody(body).build();
  }

  /**
   * Returns a response indicating that the server can not find the requested resource.
   *
   * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/404
   */
  public static HttpResponse notFound(String body) {
    return newBuilder().setStatusCode(404).setStatus('Not Found').setBody(body).build();
  }

  /**
   * Returns a response indicating that the server encountered an unexpected error.
   *
   * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Status/500
   */
  public static HttpResponse internalServerError(String body) {
    return newBuilder().setStatusCode(500).setStatus('Internal Server Error').setBody(body).build();
  }

  /**
   * Returns a new builder for constructing a response.
   */
  public static Builder newBuilder() {
    return new Builder();
  }

  /**
   * Builder for constructing a response.
   */
  public class Builder {
    private final Map<String, String> header = new Map<String, String>();
    private String body = '';
    private Integer statusCode;
    private String status;

    /**
     * Sets the body of the response, returning the builder for chaining.
     */
    public Builder setBody(String body) {
      this.body = body;
      return this;
    }

    /**
     * Sets the status code of the response, returning the builder for chaining.
     */
    public Builder setStatusCode(Integer statusCode) {
      this.statusCode = statusCode;
      return this;
    }

    /**
     * Sets the status of the response, returning the builder for chaining.
     */
    public Builder setStatus(String status) {
      this.status = status;
      return this;
    }

    /**
     * Adds a header to the response, returning the builder for chaining.
     */
    public Builder addHeader(String key, String value) {
      this.header.put(key, value);
      return this;
    }

    /**
     * Builds and returns a response.
     */
    public HttpResponse build() {
      HttpResponse response = new HttpResponse();
      response.setBody(body);
      response.setStatusCode(statusCode);
      response.setStatus(status);

      for (String key : header.keySet()) {
        response.setHeader(key, header.get(key));
      }

      return response;
    }

    private Builder() {
    }
  }

  private HttpResponses() {
  }
}