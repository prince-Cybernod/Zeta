/**
 * Implementation of {@link HttpRequestSender}.
 */
public with sharing class HttpRequestSenderImpl implements HttpRequestSender {
  public HttpResponse send(HttpRequest httpRequest) {
    HttpResponse httpResponse = sendRequest(httpRequest);

    if (httpResponse.getStatusCode() >= 300) {
      throwUnexpectedStatusCode(httpResponse);
    }

    return httpResponse;
  }

  public HttpResponse send(HttpRequest httpRequest, Integer expectedStatusCode) {
    return send(httpRequest, new Set<Integer>{ expectedStatusCode });
  }

  public HttpResponse send(HttpRequest httpRequest, Set<Integer> expectedStatusCodes) {
    HttpResponse httpResponse = sendRequest(httpRequest);

    if (!expectedStatusCodes.contains(httpResponse.getStatusCode())) {
      throwUnexpectedStatusCode(httpResponse);
    }

    return httpResponse;
  }

  private static HttpResponse sendRequest(HttpRequest httpRequest) {
    Http http = new Http();
    return http.send(httpRequest);
  }

  private static void throwUnexpectedStatusCode(HttpResponse httpResponse) {
    throw new CalloutException(
      String.format(
        'Unexpected HTTP status code: {0} {1} - {2}',
        new List<Object>{
          httpResponse.getStatusCode(),
          httpResponse.getStatus(),
          httpResponse.getBody()
        }
      )
    );
  }
}