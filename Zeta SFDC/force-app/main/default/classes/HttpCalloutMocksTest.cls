/**
 * Tests for {@link HttpCalloutMocks}.
 */
@IsTest(IsParallel=true)
private class HttpCalloutMocksTest {
  @IsTest
  private static void ok_validBody_returnsHttpCalloutMock() {
    String body = '{"message":"success"}';
    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://example.com');
    request.setMethod('GET');
    HttpCalloutMock mock = HttpCalloutMocks.ok(body);
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    HttpResponse response = new Http().send(request);
    Test.stopTest();

    Assert.areEqual(200, response.getStatusCode(), 'Status code should be 200');
    Assert.areEqual('{"message":"success"}', response.getBody(), 'Response body should match');
  }

  @IsTest
  private static void ok_noArgs_returnsOkWithEmptyBody() {
    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://example.com');
    request.setMethod('GET');
    HttpCalloutMock mock = HttpCalloutMocks.ok();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    HttpResponse response = new Http().send(request);
    Test.stopTest();

    Assert.areEqual(200, response.getStatusCode());
    Assert.areEqual('', response.getBody());
  }

  @IsTest
  private static void created_validBody_returnsHttpCalloutMock() {
    String body = '{"message":"created"}';
    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://example.com');
    request.setMethod('GET');
    HttpCalloutMock mock = HttpCalloutMocks.created(body);
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    HttpResponse response = new Http().send(request);
    Test.stopTest();

    Assert.areEqual(201, response.getStatusCode(), 'Status code should be 201');
    Assert.areEqual('{"message":"created"}', response.getBody(), 'Response body should match');
  }

  @IsTest
  private static void noContent_returnsHttpCalloutMock() {
    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://example.com');
    request.setMethod('GET');
    HttpCalloutMock mock = HttpCalloutMocks.noContent();
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    HttpResponse response = new Http().send(request);
    Test.stopTest();

    Assert.areEqual(204, response.getStatusCode(), 'Status code should be 204');
    Assert.areEqual('', response.getBody(), 'Response body should be empty');
  }

  @IsTest
  private static void badRequest_validBody_returnsHttpCalloutMock() {
    String body = '{"error":"bad request"}';
    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://example.com');
    request.setMethod('GET');
    HttpCalloutMock mock = HttpCalloutMocks.badRequest(body);
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    HttpResponse response = new Http().send(request);
    Test.stopTest();

    Assert.areEqual(400, response.getStatusCode(), 'Status code should be 400');
    Assert.areEqual('{"error":"bad request"}', response.getBody(), 'Response body should match');
  }

  @IsTest
  private static void notFound_validBody_returnsHttpCalloutMock() {
    String body = '{"error":"not found"}';
    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://example.com');
    request.setMethod('GET');
    HttpCalloutMock mock = HttpCalloutMocks.notFound(body);
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    HttpResponse response = new Http().send(request);
    Test.stopTest();

    Assert.areEqual(404, response.getStatusCode(), 'Status code should be 404');
    Assert.areEqual('{"error":"not found"}', response.getBody(), 'Response body should match');
  }

  @IsTest
  private static void internalServerError_validBody_returnsHttpCalloutMock() {
    String body = '{"error":"internal server error"}';
    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://example.com');
    request.setMethod('GET');
    HttpCalloutMock mock = HttpCalloutMocks.internalServerError(body);
    Test.setMock(HttpCalloutMock.class, mock);

    Test.startTest();
    HttpResponse response = new Http().send(request);
    Test.stopTest();

    Assert.areEqual(500, response.getStatusCode(), 'Status code should be 500');
    Assert.areEqual(
      '{"error":"internal server error"}',
      response.getBody(),
      'Response body should match'
    );
  }

  @IsTest
  private static void withResponses_validResponses_returnsHttpCalloutMock() {
    HttpResponse firstResponse = new HttpResponse();
    firstResponse.setStatusCode(200);
    firstResponse.setBody('{"message":"first response"}');
    HttpResponse secondResponse = new HttpResponse();
    secondResponse.setStatusCode(404);
    secondResponse.setBody('{"error":"not found"}');
    List<HttpResponse> responses = new List<HttpResponse>{ firstResponse, secondResponse };
    HttpCalloutMock mock = HttpCalloutMocks.withResponses(responses);
    Test.setMock(HttpCalloutMock.class, mock);
    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://example.com');
    request.setMethod('GET');

    Test.startTest();
    HttpResponse response1 = new Http().send(request);
    HttpResponse response2 = new Http().send(request);
    Test.stopTest();

    Assert.areEqual(200, response1.getStatusCode(), 'First response status code should be 200');
    Assert.areEqual(
      '{"message":"first response"}',
      response1.getBody(),
      'First response body should match'
    );
    Assert.areEqual(404, response2.getStatusCode(), 'Second response status code should be 404');
    Assert.areEqual(
      '{"error":"not found"}',
      response2.getBody(),
      'Second response body should match'
    );
  }

  @IsTest
  private static void withResponses_noResponses_throwsCalloutException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      CalloutException.class,
      'No mock responses available.'
    );
    List<HttpResponse> responses = new List<HttpResponse>();
    HttpCalloutMock mock = HttpCalloutMocks.withResponses(responses);
    Test.setMock(HttpCalloutMock.class, mock);
    HttpRequest request = new HttpRequest();
    request.setEndpoint('https://example.com');
    request.setMethod('GET');

    Test.startTest();
    try {
      new Http().send(request);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    Test.stopTest();

    throwing.assertHasThrown();
  }
}