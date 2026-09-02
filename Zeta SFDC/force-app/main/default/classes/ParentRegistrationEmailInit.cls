public without sharing class ParentRegistrationEmailInit extends ParentRegistrationCommon {

  @TestVisible enum TestScenario {
    SUCCESS,
    WITH_EXISTING_CONTACT,
    THROW_EXCEPTION
  }
  @TestVisible static TestScenario scenario;

  @InvocableMethod(
    Label='Init Self Registration By Email'
    Description='Init self registration by Email'
  )
  public static List<RegistrationResponse> initSelfRegistrationByEmail(
    List<RegistrationRequest> requests
  ) {
    List<RegistrationResponse> responses = new List<RegistrationResponse>();

    for (RegistrationRequest req : requests) {
      String email = req.email;
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
          when WITH_EXISTING_CONTACT {
            contactId = req.contactId != null ? req.contactId : 'test-contact-id';
            accountId = 'test-account-id';
          }
          when THROW_EXCEPTION {
            throw new NullPointerException();
          }
          when else {
            if (req.contactId == null) {
              Account account = AccountService.getNewAccount(
                email,
                firstName,
                lastName,
                phone,
                req.street,
                req.city,
                req.state,
                req.postalCode,
                req.country
              );
              accountId = account?.Id;
              contactId = account?.PersonContactId;
            } else {
              accountId = AccountService.getAccountByContactId(req.contactId)?.Id;
              contactId = req.contactId;
            }

            User u = UserService.getUser(email, phone, firstName, lastName, null, contactId);
            selfRegId = System.UserManagement.initSelfRegistration(Auth.VerificationMethod.EMAIL, u);
          }
        }

        responses.add(new RegistrationResponse(selfRegId, contactId, accountId));
      } catch (Exception e) {
        Logger.error('Exception when initialising self-registration via Email. Email: ' + email, e);
        Logger.saveLog();
        responses.add(new RegistrationResponse('Registration Exception. Please contact support.'));
      }
    }

    return responses;
  }

}