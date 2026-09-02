@IsTest
private class FormatPhoneInvocable_T {

  @IsTest
  static void testFormatPhoneInvocable() {
    List<FormatPhoneInvocable.FormatPhoneRequest> requests = new List<FormatPhoneInvocable.FormatPhoneRequest>();

    FormatPhoneInvocable.FormatPhoneRequest request1 = new FormatPhoneInvocable.FormatPhoneRequest();
    request1.phoneNumber = '5551234567';
    requests.add(request1);

    FormatPhoneInvocable.FormatPhoneRequest request2 = new FormatPhoneInvocable.FormatPhoneRequest();
    request2.phoneNumber = '+15551234567';
    requests.add(request2);

    FormatPhoneInvocable.FormatPhoneRequest request3 = new FormatPhoneInvocable.FormatPhoneRequest();
    request3.phoneNumber = '+64221234567';
    requests.add(request3);

    FormatPhoneInvocable.FormatPhoneRequest request4 = new FormatPhoneInvocable.FormatPhoneRequest();
    request4.phoneNumber = '';
    requests.add(request4);

    FormatPhoneInvocable.FormatPhoneRequest request5 = new FormatPhoneInvocable.FormatPhoneRequest();
    request5.phoneNumber = null;
    requests.add(request5);

    Test.startTest();
    List<FormatPhoneInvocable.FormatPhoneResponse> responses = FormatPhoneInvocable.formatPhone(requests);
    Test.stopTest();

    Assert.areEqual(5, responses.size(), 'Should return 5 responses');

    Assert.areEqual(
      UserService.formatPhone('5551234567'),
      responses[0].formattedPhoneNumber,
      'Should format US number without country code'
    );

    Assert.areEqual(
      UserService.formatPhone('+15551234567'),
      responses[1].formattedPhoneNumber,
      'Should format US number with country code'
    );

    Assert.areEqual(
      UserService.formatPhone('+64221234567'),
      responses[2].formattedPhoneNumber,
      'Should format New Zealand number with country code'
    );

    Assert.areEqual(
      UserService.formatPhone(''),
      responses[3].formattedPhoneNumber,
      'Should handle empty string'
    );

    Assert.areEqual(
      UserService.formatPhone(null),
      responses[4].formattedPhoneNumber,
      'Should handle null value'
    );
  }

}