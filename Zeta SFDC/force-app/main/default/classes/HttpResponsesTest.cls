/**
 * Tests for {@link HttpResponses}.
 */
@IsTest(IsParallel=true)
private class HttpResponsesTest {
  @IsTest
  private static void ok() {
    HttpResponse response = HttpResponses.ok('body');

    Assert.areEqual(200, response.getStatusCode());
    Assert.areEqual('OK', response.getStatus());
    Assert.areEqual('body', response.getBody());
  }

  @IsTest
  private static void created() {
    HttpResponse response = HttpResponses.created('{"task": {"id": "123"}}');

    Assert.areEqual(201, response.getStatusCode());
    Assert.areEqual('Created', response.getStatus());
    Assert.areEqual('{"task": {"id": "123"}}', response.getBody());
  }

  @IsTest
  private static void accepted() {
    HttpResponse response = HttpResponses.accepted('{"task": {"id": "123"}}');

    Assert.areEqual(202, response.getStatusCode());
    Assert.areEqual('Accepted', response.getStatus());
    Assert.areEqual('{"task": {"id": "123"}}', response.getBody());
  }

  @IsTest
  private static void noContent() {
    HttpResponse response = HttpResponses.noContent();

    Assert.areEqual(204, response.getStatusCode());
    Assert.areEqual('No Content', response.getStatus());
    Assert.areEqual('', response.getBody());
  }

  @IsTest
  private static void badRequest() {
    HttpResponse response = HttpResponses.badRequest('{"error": "bad request"}');

    Assert.areEqual(400, response.getStatusCode());
    Assert.areEqual('Bad Request', response.getStatus());
    Assert.areEqual('{"error": "bad request"}', response.getBody());
  }

  @IsTest
  private static void notFound() {
    HttpResponse response = HttpResponses.notFound('{"error": "not found"}');

    Assert.areEqual(404, response.getStatusCode());
    Assert.areEqual('Not Found', response.getStatus());
    Assert.areEqual('{"error": "not found"}', response.getBody());
  }

  @IsTest
  private static void internalServerError() {
    HttpResponse response = HttpResponses.internalServerError('body');

    Assert.areEqual(500, response.getStatusCode());
    Assert.areEqual('Internal Server Error', response.getStatus());
    Assert.areEqual('body', response.getBody());
  }

  @IsTest
  private static void newBuilder() {
    HttpResponses.Builder builder = HttpResponses.newBuilder()
      .setStatusCode(401)
      .setStatus('Unauthorized')
      .setBody('body')
      .addHeader('Content-Type', 'application/json');

    HttpResponse response = builder.build();

    Assert.areEqual(401, response.getStatusCode());
    Assert.areEqual('Unauthorized', response.getStatus());
    Assert.areEqual('body', response.getBody());
    Assert.areEqual('application/json', response.getHeader('Content-Type'));
  }
}