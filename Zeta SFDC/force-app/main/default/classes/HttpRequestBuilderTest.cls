/**
 * Tests for {@link HttpRequestBuilder}.
 */
@IsTest(IsParallel=true)
private class HttpRequestBuilderTest {
  @IsTest
  private static void newBuilder() {
    HttpRequestBuilder builder = HttpRequestBuilder.newBuilder()
      .addHeader('key', 'value')
      .setBody('body')
      .setBody(Blob.valueOf('body'))
      .setEndpoint('endpoint')
      .setMethod(HttpMethod.HTTP_GET)
      .setTimeout(100);

    HttpRequest request = builder.build();

    System.assertEquals('value', request.getHeader('key'));
    System.assertEquals('body', request.getBody());
    System.assertEquals(Blob.valueOf('body'), request.getBodyAsBlob());
    System.assertEquals('endpoint', request.getEndpoint());
    System.assertEquals('GET', request.getMethod());
    // There is no request.getTimeout() method, so we can't test that one :(
  }

  @IsTest
  private static void addHeader_withKeyAndValueEnums_setsHeader() {
    HttpRequestBuilder builder = HttpRequestBuilder.newBuilder()
      .addHeader(HttpHeaderKey.CONTENT_TYPE, HttpHeaderValue.APPLICATION_JSON);

    HttpRequest request = builder.build();

    System.assertEquals('application/json', request.getHeader('Content-Type'));
  }

  @IsTest
  private static void addHeader_withKeyEnumAndStringValue_setsHeader() {
    HttpRequestBuilder builder = HttpRequestBuilder.newBuilder()
      .addHeader(HttpHeaderKey.CONTENT_TYPE, 'custom/type');

    HttpRequest request = builder.build();

    System.assertEquals('custom/type', request.getHeader('Content-Type'));
  }

  @IsTest
  private static void addHeader_withStringKeyAndValueEnum_setsHeader() {
    HttpRequestBuilder builder = HttpRequestBuilder.newBuilder()
      .addHeader('Accept', HttpHeaderValue.APPLICATION_JSON);

    HttpRequest request = builder.build();

    System.assertEquals('application/json', request.getHeader('Accept'));
  }

  @IsTest
  private static void addHeader_withStringKeyAndValue_setsHeader() {
    HttpRequestBuilder builder = HttpRequestBuilder.newBuilder()
      .addHeader('Custom-Header', 'custom-value');

    HttpRequest request = builder.build();

    System.assertEquals('custom-value', request.getHeader('Custom-Header'));
  }
}