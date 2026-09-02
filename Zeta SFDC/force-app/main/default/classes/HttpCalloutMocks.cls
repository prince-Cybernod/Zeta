/**
 * Returns mock responses for HTTP callouts.
 */
public with sharing class HttpCalloutMocks {
  /**
   * Returns a mock OK response.
   */
  public static HttpCalloutMock ok(String body) {
    return new HttpCalloutMockImpl(new List<HttpResponse>{ HttpResponses.ok(body) });
  }

  public static HttpCalloutMock ok() {
    return ok('');
  }

  /**
   * Returns a mock Created response.
   */
  public static HttpCalloutMock created(String body) {
    return new HttpCalloutMockImpl(new List<HttpResponse>{ HttpResponses.created(body) });
  }

  /**
   * Returns a mock No Content response.
   */
  public static HttpCalloutMock noContent() {
    return new HttpCalloutMockImpl(new List<HttpResponse>{ HttpResponses.noContent() });
  }

  /**
   * Returns a mock Bad Request response.
   */
  public static HttpCalloutMock badRequest(String body) {
    return new HttpCalloutMockImpl(new List<HttpResponse>{ HttpResponses.badRequest(body) });
  }

  /**
   * Returns a mock Not Found response.
   */
  public static HttpCalloutMock notFound(String body) {
    return new HttpCalloutMockImpl(new List<HttpResponse>{ HttpResponses.notFound(body) });
  }

  /**
   * Returns a mock Internal Server Error response.
   */
  public static HttpCalloutMock internalServerError(String body) {
    return new HttpCalloutMockImpl(
      new List<HttpResponse>{ HttpResponses.internalServerError(body) }
    );
  }

  /**
   * Returns mock responses based on the given list of responses.
   */
  public static HttpCalloutMock withResponses(List<HttpResponse> responses) {
    return new HttpCalloutMockImpl(responses);
  }

  private class HttpCalloutMockImpl implements HttpCalloutMock {
    private final List<HttpResponse> responses;

    private HttpCalloutMockImpl(List<HttpResponse> responses) {
      this.responses = responses;
    }

    public HttpResponse respond(HttpRequest request) {
      if (responses.isEmpty()) {
        throw new CalloutException('No mock responses available.');
      }

      return responses.remove(0);
    }
  }
}