/**
 * Tests for {@link HttpRequestSenderImpl}.
 */
@IsTest(IsParallel=true)
private class HttpRequestSenderImplTest {
  private static final HttpRequestSenderImpl HTTP_REQUEST_SENDER_IMPL;

  static {
    HTTP_REQUEST_SENDER_IMPL = new HttpRequestSenderImpl();
  }

  @IsTest
  private static void send_statusCode200_throwsCalloutException() {
    HttpRequest request = HttpRequestBuilder.newBuilder()
      .setEndpoint('https://example.com')
      .setMethod(HttpMethod.HTTP_GET)
      .build();
    String responseBody = '{"status":"ok"}';
    Test.setMock(HttpCalloutMock.class, HttpCalloutMocks.ok(responseBody));

    Test.startTest();
    HttpResponse actualResponse = HTTP_REQUEST_SENDER_IMPL.send(request);
    Test.stopTest();

    Assert.areEqual(200, actualResponse.getStatusCode(), 'Status code should be 200');
    Assert.areEqual(responseBody, actualResponse.getBody(), 'Response body should match');
  }

  @IsTest
  private static void send_statusCode400_throwsCalloutException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      CalloutException.class,
      'Unexpected HTTP status code: 400 Bad Request - {"status":"error"}'
    );
    HttpRequest request = HttpRequestBuilder.newBuilder()
      .setEndpoint('https://example.com')
      .setMethod(HttpMethod.HTTP_GET)
      .build();
    String responseBody = '{"status":"error"}';
    Test.setMock(HttpCalloutMock.class, HttpCalloutMocks.badRequest(responseBody));

    Test.startTest();
    try {
      HTTP_REQUEST_SENDER_IMPL.send(request);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    Test.stopTest();

    throwing.assertHasThrown();
  }

  @IsTest
  private static void send_singleExpectedStatusCode_returnsHttpResponse() {
    HttpRequest request = HttpRequestBuilder.newBuilder()
      .setEndpoint('https://example.com')
      .setMethod(HttpMethod.HTTP_GET)
      .build();
    Integer expectedStatusCode = 200;
    String responseBody = '{"status":"ok"}';
    Test.setMock(HttpCalloutMock.class, HttpCalloutMocks.ok(responseBody));

    Test.startTest();
    HttpResponse actualResponse = HTTP_REQUEST_SENDER_IMPL.send(request, expectedStatusCode);
    Test.stopTest();

    Assert.areEqual(200, actualResponse.getStatusCode(), 'Status code should be 200');
    Assert.areEqual(responseBody, actualResponse.getBody(), 'Response body should match');
  }

  @IsTest
  private static void send_singleUnexpectedStatusCode_throwsCalloutException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      CalloutException.class,
      'Unexpected HTTP status code: 500 Internal Server Error - {"status":"error"}'
    );
    HttpRequest request = HttpRequestBuilder.newBuilder()
      .setEndpoint('https://example.com')
      .setMethod(HttpMethod.HTTP_GET)
      .build();
    Integer expectedStatusCode = 200;
    String responseBody = '{"status":"error"}';
    Test.setMock(HttpCalloutMock.class, HttpCalloutMocks.internalServerError(responseBody));

    Test.startTest();
    try {
      HTTP_REQUEST_SENDER_IMPL.send(request, expectedStatusCode);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    Test.stopTest();

    throwing.assertHasThrown();
  }

  @IsTest
  private static void send_expectedStatusCode_returnsHttpResponse() {
    HttpRequest request = HttpRequestBuilder.newBuilder()
      .setEndpoint('https://example.com')
      .setMethod(HttpMethod.HTTP_GET)
      .build();
    Set<Integer> expectedStatusCodes = new Set<Integer>{ 200 };
    String responseBody = '{"status":"ok"}';
    Test.setMock(HttpCalloutMock.class, HttpCalloutMocks.ok(responseBody));

    Test.startTest();
    HttpResponse actualResponse = HTTP_REQUEST_SENDER_IMPL.send(request, expectedStatusCodes);
    Test.stopTest();

    Assert.areEqual(200, actualResponse.getStatusCode(), 'Status code should be 200');
    Assert.areEqual(responseBody, actualResponse.getBody(), 'Response body should match');
  }

  @IsTest
  private static void send_unexpectedStatusCode_throwsCalloutException() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      CalloutException.class,
      'Unexpected HTTP status code: 500 Internal Server Error - {"status":"error"}'
    );
    HttpRequest request = HttpRequestBuilder.newBuilder()
      .setEndpoint('https://example.com')
      .setMethod(HttpMethod.HTTP_GET)
      .build();
    Set<Integer> expectedStatusCodes = new Set<Integer>{ 200 };
    String responseBody = '{"status":"error"}';
    Test.setMock(HttpCalloutMock.class, HttpCalloutMocks.internalServerError(responseBody));

    Test.startTest();
    try {
      HTTP_REQUEST_SENDER_IMPL.send(request, expectedStatusCodes);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }
    Test.stopTest();

    throwing.assertHasThrown();
  }
}