public without sharing class ParentRegistrationSmsInit extends ParentRegistrationCommon {

  @TestVisible enum TestScenario {
    SUCCESS,
    WITH_EXISTING_CONTACT,
    WITHOUT_EMAIL,
    THROW_EXCEPTION
  }
  @TestVisible static TestScenario scenario;

  @InvocableMethod(
    Label='Init Self Registration By SMS'
    Description='Init self registration by SMS'
  )
  public static List<RegistrationResponse> initSelfRegistrationBySMS(
    List<RegistrationRequest> requests
  ) {
    List<RegistrationResponse> responses = new List<RegistrationResponse>();

    for (RegistrationRequest req : requests) {
      String email = req.email ?? UserService.getUniqueEmailAddress();
      try {
        String firstName = req.firstName;
        String lastName = req.lastName;
        String phone = UserService.formatPhone(req.phone);
        String accountId;
        String contactId;
        String selfRegId = null;

        switch on scenario {
          when SUCCESS {
            contactId = 'test-contact-id';
            accountId = 'test-account-id';
          }
          when THROW_EXCEPTION {
            throw new NullPointerException();
          }
          when WITH_EXISTING_CONTACT {
            contactId = req.contactId != null ? req.contactId : 'test-contact-id';
            accountId = 'test-account-id';
          }
          when WITHOUT_EMAIL {
            contactId = 'test-contact-id';
            accountId = 'test-account-id';
          }
          when else {
            if (req.contactId == null) {
              Account account = AccountService.getNewAccount(email, firstName, lastName, phone, req.street, req.city, req.state, req.postalCode, req.country);
              accountId = account?.Id;
              contactId = account?.PersonContactId;
            } else {
              accountId = AccountService.getAccountByContactId(req.contactId)?.Id;
              contactId = req.contactId;
            }

            User u = UserService.getUser(email, phone, firstName, lastName, null, contactId);
            selfRegId = System.UserManagement.initSelfRegistration(Auth.VerificationMethod.SMS, u);
          }
        }

        responses.add(new RegistrationResponse(selfRegId, contactId, accountId));
      } catch (Exception e) {
        Logger.error('Exception when initialising self-registration via SMS. Contact Id: ' + req.contactId, e);
        Logger.saveLog();
        responses.add(new RegistrationResponse('Registration Exception. Please contact support.'));
      }
    }

    return responses;
  }

}