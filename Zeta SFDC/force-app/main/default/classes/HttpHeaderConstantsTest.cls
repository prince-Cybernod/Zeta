/**
 * Tests for {@link HttpHeaderConstants}.
 */
@IsTest(IsParallel=true)
private class HttpHeaderConstantsTest {
  @IsTest
  private static void headerKeyMap_isNotNull() {
    Assert.isNotNull(HttpHeaderConstants.HEADER_KEY_MAP);
  }

  @IsTest
  private static void headerKeyReverseMap_isNotNull() {
    Assert.isNotNull(HttpHeaderConstants.HEADER_KEY_REVERSE_MAP);
  }

  @IsTest
  private static void headerValueMap_isNotNull() {
    Assert.isNotNull(HttpHeaderConstants.HEADER_VALUE_MAP);
  }

  @IsTest
  private static void headerValueReverseMap_isNotNull() {
    Assert.isNotNull(HttpHeaderConstants.HEADER_VALUE_REVERSE_MAP);
  }

  @IsTest
  private static void getHeaderKey_enum_returnsString() {
    HttpHeaderKey key = HttpHeaderKey.AUTHORIZATION;

    String value = HttpHeaderConstants.getHeaderKey(key);

    Assert.areEqual('Authorization', value);
  }

  @IsTest
  private static void getHeaderKey_string_returnsEnum() {
    String key = 'Authorization';

    HttpHeaderKey value = HttpHeaderConstants.getHeaderKey(key);

    Assert.areEqual(HttpHeaderKey.AUTHORIZATION, value);
  }

  @IsTest
  private static void getHeaderValue_enum_returnsString() {
    HttpHeaderValue value = HttpHeaderValue.APPLICATION_JSON;

    String result = HttpHeaderConstants.getHeaderValue(value);

    Assert.areEqual('application/json', result);
  }

  @IsTest
  private static void getHeaderValue_string_returnsEnum() {
    String value = 'application/json';

    HttpHeaderValue result = HttpHeaderConstants.getHeaderValue(value);

    Assert.areEqual(HttpHeaderValue.APPLICATION_JSON, result);
  }
}