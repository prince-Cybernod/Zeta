/**
 * Enumeration of HTTP request methods.
 *
 * Each value is prefixed with `HTTP_` because some of the values are reserved keywords in Apex.
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Methods
 */
public enum HttpMethod {
  /**
   * GET
   *
   * The GET method requests a representation of the specified resource. Requests using GET
   * should only retrieve data and should not contain a request content.
   */
  HTTP_GET,
  /**
   * HEAD
   *
   * The HEAD method asks for a response identical to a GET request, but without a response body.
   */
  HTTP_HEAD,
  /**
   * POST
   *
   * The POST method submits an entity to the specified resource, often causing a change in
   * state or side effects on the server.
   */
  HTTP_POST,
  /**
   * PUT
   *
   * The PUT method replaces all current representations of the target resource with the
   * request content.
   */
  HTTP_PUT,
  /**
   * DELETE
   *
   * The DELETE method deletes the specified resource.
   */
  HTTP_DELETE,
  /**
   * CONNECT
   *
   * The CONNECT method establishes a tunnel to the server identified by the target resource.
   */
  HTTP_CONNECT,
  /**
   * OPTIONS
   *
   * The OPTIONS method describes the communication options for the target resource.
   */
  HTTP_OPTIONS,
  /**
   * TRACE
   *
   * The TRACE method performs a message loop-back test along the path to the target resource.
   */
  HTTP_TRACE,
  /**
   * PATCH
   *
   * The PATCH method applies partial modifications to a resource.
   */
  HTTP_PATCH
}