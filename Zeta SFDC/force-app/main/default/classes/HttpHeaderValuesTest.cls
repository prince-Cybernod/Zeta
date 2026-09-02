/**
 * Tests for {@link HttpHeaderValues}.
 */
@IsTest(IsParallel=true)
private class HttpHeaderValuesTest {
  @IsTest
  static void testBearer_ReturnsFormattedHeader() {
    String token = 'abc123token';

    String result = HttpHeaderValues.bearer(token);

    Assert.areEqual('Bearer abc123token', result);
  }

  @IsTest
  static void testBasicAuth_ReturnsFormattedHeader() {
    String username = 'testuser';
    String password = 'testpass';

    String result = HttpHeaderValues.basicAuth(username, password);

    String expectedCredentials = EncodingUtil.base64Encode(Blob.valueOf('testuser:testpass'));
    Assert.areEqual('Basic ' + expectedCredentials, result);
  }

  @IsTest
  static void testApiKey_ReturnsFormattedHeader() {
    String apiKey = 'my-api-key-123';

    String result = HttpHeaderValues.apiKey(apiKey);

    Assert.areEqual('ApiKey my-api-key-123', result);
  }

  @IsTest
  static void testCustomAuth_ReturnsFormattedHeader() {
    String scheme = 'Custom';
    String credentials = 'my-custom-token';

    String result = HttpHeaderValues.customAuth(scheme, credentials);

    Assert.areEqual('Custom my-custom-token', result);
  }

  @IsTest
  static void testContentTypeWithCharset_ReturnsFormattedHeader() {
    String mediaType = 'application/json';
    String charset = 'UTF-8';

    String result = HttpHeaderValues.contentTypeWithCharset(mediaType, charset);

    Assert.areEqual('application/json; charset=UTF-8', result);
  }

  @IsTest
  static void testContentTypeWithCharset_BlankCharset_ReturnsMediaTypeOnly() {
    String mediaType = 'application/json';
    String charset = '';

    String result = HttpHeaderValues.contentTypeWithCharset(mediaType, charset);

    Assert.areEqual('application/json', result);
  }

  @IsTest
  static void testMultipartFormData_ReturnsFormattedHeader() {
    String boundary = 'boundary123';

    String result = HttpHeaderValues.multipartFormData(boundary);

    Assert.areEqual('multipart/form-data; boundary=boundary123', result);
  }

  @IsTest
  static void testAccept_ReturnsFormattedHeader() {
    List<String> mediaTypes = new List<String>{
      'application/json',
      'text/html;q=0.9',
      'text/plain;q=0.8'
    };

    String result = HttpHeaderValues.accept(mediaTypes);

    Assert.areEqual('application/json, text/html;q=0.9, text/plain;q=0.8', result);
  }

  @IsTest
  static void testAcceptWithQuality_QualityOne_ReturnsMediaTypeOnly() {
    String mediaType = 'application/json';
    Decimal quality = 1.0;

    String result = HttpHeaderValues.acceptWithQuality(mediaType, quality);

    Assert.areEqual('application/json', result);
  }

  @IsTest
  static void testAcceptWithQuality_QualityLessThanOne_ReturnsWithQuality() {
    String mediaType = 'application/json';
    Decimal quality = 0.9;

    String result = HttpHeaderValues.acceptWithQuality(mediaType, quality);

    Assert.areEqual('application/json;q=0.9', result);
  }

  @IsTest
  static void testCacheControlMaxAge_ReturnsFormattedHeader() {
    Integer maxAgeSeconds = 3600;

    String result = HttpHeaderValues.cacheControlMaxAge(maxAgeSeconds);

    Assert.areEqual('max-age=3600', result);
  }

  @IsTest
  static void testCacheControl_ReturnsFormattedHeader() {
    List<String> directives = new List<String>{ 'no-cache', 'no-store', 'must-revalidate' };

    String result = HttpHeaderValues.cacheControl(directives);

    Assert.areEqual('no-cache, no-store, must-revalidate', result);
  }

  @IsTest
  static void testUserAgent_AllParameters_ReturnsFormattedHeader() {
    String applicationName = 'MyApp';
    String version = '1.0.0';
    String additionalInfo = 'Salesforce Integration';

    String result = HttpHeaderValues.userAgent(applicationName, version, additionalInfo);

    Assert.areEqual('MyApp/1.0.0 (Salesforce Integration)', result);
  }

  @IsTest
  static void testUserAgent_NoAdditionalInfo_ReturnsNameAndVersion() {
    String applicationName = 'MyApp';
    String version = '1.0.0';

    String result = HttpHeaderValues.userAgent(applicationName, version, null);

    Assert.areEqual('MyApp/1.0.0', result);
  }

  @IsTest
  static void testUserAgent_TwoParameters_ReturnsNameAndVersion() {
    String applicationName = 'MyApp';
    String version = '1.0.0';

    String result = HttpHeaderValues.userAgent(applicationName, version);

    Assert.areEqual('MyApp/1.0.0', result);
  }

  @IsTest
  static void testUserAgent_NoVersion_ReturnsNameOnly() {
    String applicationName = 'MyApp';
    String version = '';
    String additionalInfo = 'Salesforce Integration';

    String result = HttpHeaderValues.userAgent(applicationName, version, additionalInfo);

    Assert.areEqual('MyApp (Salesforce Integration)', result);
  }

  @IsTest
  static void testAcceptLanguage_ReturnsFormattedHeader() {
    List<String> languages = new List<String>{ 'en-US', 'en;q=0.9', 'fr;q=0.8' };

    String result = HttpHeaderValues.acceptLanguage(languages);

    Assert.areEqual('en-US, en;q=0.9, fr;q=0.8', result);
  }

  @IsTest
  static void testAcceptEncoding_ReturnsFormattedHeader() {
    List<String> encodings = new List<String>{ 'gzip', 'deflate', 'br' };

    String result = HttpHeaderValues.acceptEncoding(encodings);

    Assert.areEqual('gzip, deflate, br', result);
  }

  @IsTest
  static void testCookie_MapInput_ReturnsFormattedHeader() {
    Map<String, String> cookies = new Map<String, String>{
      'sessionId' => '123456',
      'theme' => 'dark',
      'language' => 'en'
    };

    String result = HttpHeaderValues.cookie(cookies);

    Assert.isTrue(result.contains('sessionId=123456'));
    Assert.isTrue(result.contains('theme=dark'));
    Assert.isTrue(result.contains('language=en'));
    Assert.isTrue(result.contains('; '));
  }

  @IsTest
  static void testCookie_SingleCookie_ReturnsFormattedHeader() {
    String name = 'sessionId';
    String value = '123456';

    String result = HttpHeaderValues.cookie(name, value);

    Assert.areEqual('sessionId=123456', result);
  }

  @IsTest
  static void testCookie_NullValue_ReturnsEmptyValue() {
    String name = 'sessionId';
    String value = null;

    String result = HttpHeaderValues.cookie(name, value);

    Assert.areEqual('sessionId=', result);
  }
}