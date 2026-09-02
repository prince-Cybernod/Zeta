/**
 * Tests for {@link HttpMethod}.
 */
@IsTest(IsParallel=true)
private class HttpMethodTest {
  @IsTest
  private static void values_allArePrefixedWithHttp() {
    for (HttpMethod method : HttpMethod.values()) {
      Assert.isTrue(
        method.name().startsWith('HTTP_'),
        'Expected the HttpMethod name to start with HTTP_'
      );
    }
  }
}