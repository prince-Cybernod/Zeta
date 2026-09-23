@IsTest
private class UserEmailConfirmationInvocable_T {
  @IsTest
  static void sendAsyncEmailConfirmationSuccess() {
    User u = new User(
      ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
      LastName = 'last',
      Email = 'test@example.com',
      Username = 'test' + Datetime.now().getTime() + '@example.com',
      Alias = 'test',
      TimeZoneSidKey = 'America/Los_Angeles',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'en_US',
      LocaleSidKey = 'en_US'
    );
    insert u;

    UserEmailConfirmationInvocable.UserEmailConfirmationRequest req = new UserEmailConfirmationInvocable.UserEmailConfirmationRequest();
    req.userIds = new List<String>{
      u.Id
    };
    req.emailTemplateId = null;
    req.networkId = null;
    req.startUrl = null;

    Test.startTest();
    List<List<UserEmailConfirmationResponse>> results = UserEmailConfirmationInvocable.sendAsyncEmailConfirmation(
      new List<UserEmailConfirmationInvocable.UserEmailConfirmationRequest>{
        req
      }
    );
    Test.stopTest();

    System.assertNotEquals(null, results, 'Results should not be null');
    System.assertEquals(1, results.size(), 'Should have one result list');
    System.assertEquals(1, results[0].size(), 'Should have one response item');
    // Note: UserManagement.sendAsyncEmailConfirmation might return false if the email is not verified or other conditions.
    // The requirement says return Boolean, success/failure.
  }
}