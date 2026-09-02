/**
 * Sends {@link HttpRequest}s
 */
public interface HttpRequestSender {
  /**
   * Sends the request, returning the response.
   *
   * @throws CalloutException when the response status code is 300 or greater
   */
  HttpResponse send(HttpRequest httpRequest);

  /**
   * Sends the request, returning the response.
   *
   * @throws CalloutException when response status code is not the expected status code
   */
  HttpResponse send(HttpRequest httpRequest, Integer expectedStatusCode);

  /**
   * Sends the request, returning the response.
   *
   * @throws CalloutException when response status code is not expected
   */
  HttpResponse send(HttpRequest httpRequest, Set<Integer> expectedStatusCodes);
}