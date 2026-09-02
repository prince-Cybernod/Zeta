/**
 * Enumeration of common HTTP header keys.
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/HTTP/Reference/Headers
 */
public enum HttpHeaderKey {
  /**
   * AUTHORIZATION
   *
   * Contains the credentials to authenticate a user agent with a server.
   */
  AUTHORIZATION,
  /**
   * CONTENT_TYPE
   *
   * Indicates the media type of the resource or data.
   */
  CONTENT_TYPE,
  /**
   * ACCEPT
   *
   * Informs the server about the types of data that can be sent back.
   */
  ACCEPT,
  /**
   * USER_AGENT
   *
   * Contains a characteristic string that allows network peers to identify the application.
   */
  USER_AGENT,
  /**
   * CACHE_CONTROL
   *
   * Specifies directives for caching mechanisms in both requests and responses.
   */
  CACHE_CONTROL,
  /**
   * CONTENT_LENGTH
   *
   * Indicates the size of the entity-body in bytes.
   */
  CONTENT_LENGTH,
  /**
   * ACCEPT_ENCODING
   *
   * Indicates which content encodings the client is able to understand.
   */
  ACCEPT_ENCODING,
  /**
   * CONNECTION
   *
   * Controls whether the network connection stays open after the current transaction finishes.
   */
  CONNECTION,
  /**
   * HOST
   *
   * Specifies the domain name of the server and the TCP port number.
   */
  HOST,
  /**
   * IF_MODIFIED_SINCE
   *
   * Makes the request conditional: returns 304 if resource hasn't been modified.
   */
  IF_MODIFIED_SINCE,
  /**
   * IF_NONE_MATCH
   *
   * Makes the request conditional based on the ETag identifier.
   */
  IF_NONE_MATCH,
  /**
   * REFERER
   *
   * Contains the address of the page making the request.
   */
  REFERER,
  /**
   * X_REQUESTED_WITH
   *
   * Used to identify Ajax requests made by JavaScript frameworks.
   */
  X_REQUESTED_WITH,
  /**
   * X_FORWARDED_FOR
   *
   * Identifies the originating IP address of a client connecting through a proxy.
   */
  X_FORWARDED_FOR,
  /**
   * ACCEPT_LANGUAGE
   *
   * Indicates the natural language and locale that the client prefers.
   */
  ACCEPT_LANGUAGE,
  /**
   * COOKIE
   *
   * Contains stored HTTP cookies previously sent by the server.
   */
  COOKIE,
  /**
   * SET_COOKIE
   *
   * Sends cookies from the server to the client.
   */
  SET_COOKIE
}