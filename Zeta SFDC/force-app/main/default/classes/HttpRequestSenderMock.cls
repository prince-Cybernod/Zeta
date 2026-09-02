/**
 * {@link Mock} implementation of {@link HttpRequestSender}.
 */
@IsTest
@SuppressWarnings('PMD.CognitiveComplexity')
public class HttpRequestSenderMock extends Mock implements HttpRequestSender {
  public final Method method = new Method();

  public HttpResponse send(HttpRequest httpRequest) {
    return (HttpResponse) mockedCall(
      method.send(),
      new Map<String, Object>{ 'httpRequest' => httpRequest }
    );
  }

  public HttpResponse send(HttpRequest httpRequest, Integer expectedStatusCode) {
    return (HttpResponse) mockedCall(
      method.send(),
      new Map<String, Object>{
        'httpRequest' => httpRequest,
        'expectedStatusCode' => expectedStatusCode
      }
    );
  }

  public HttpResponse send(HttpRequest httpRequest, Set<Integer> expectedStatusCodes) {
    return (HttpResponse) mockedCall(
      method.send(),
      new Map<String, Object>{
        'httpRequest' => httpRequest,
        'expectedStatusCodes' => expectedStatusCodes
      }
    );
  }

  public class Method {
    public String send() {
      return new ExecutionInfo().getFullName();
    }
  }
}