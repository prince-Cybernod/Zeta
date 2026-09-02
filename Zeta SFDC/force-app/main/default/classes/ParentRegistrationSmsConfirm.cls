public without sharing class ParentRegistrationSmsConfirm extends ParentRegistrationCommon {

  @TestVisible enum TestScenario {
    SUCCESS,
    INVALID_TOKEN,
    THROW_EXCEPTION
  }
  @TestVisible static TestScenario scenario;

  @InvocableMethod(
    Label='Verify Self Registration By SMS'
    Description='Verify self registration by SMS'
  )
  public static List<ConfirmationResponse> verifySelfRegistrationSMS(
    List<CodeConfirmationRequest> requests
  ) {
    List<ConfirmationResponse> responses = new List<ConfirmationResponse>();

    for (CodeConfirmationRequest req : requests) {
      Auth.VerificationResult res;
      String selfRegId = req.selfRegId;
      String code = req.code;
      String startUrl = req.startUrl;
      String contactId = req.contactId;

      try {
        switch on scenario {
          when SUCCESS {
            res = new Auth.VerificationResult(new PageReference('/s/test-success'), true, null);
          }
          when INVALID_TOKEN {
            res = new Auth.VerificationResult(null, false, 'Token not valid');
          }
          when THROW_EXCEPTION {
            throw new NullPointerException();
          }
          when else {
            res = System.UserManagement.verifySelfRegistration(
              Auth.VerificationMethod.SMS,
              selfRegId,
              code,
              startUrl
            );
          }
        }

        if (res.success) {
//          UserService.setPortalUser(contactId);

          Id userId = UserService.getUserIdByContactId(contactId);
          Id accountId = [SELECT AccountId FROM Contact WHERE Id = :contactId LIMIT 1]?.AccountId;

          responses.add(new ConfirmationResponse(res.redirect, accountId, userId));
        } else {
          if (res.message == 'Token not valid') {
            responses.add(new ConfirmationResponse(res.message));
          } else {
            Logger.error('Error when verifying self-registration via SMS. Contact Id: ' + contactId, res.message);
            Logger.saveLog();
            responses.add(new ConfirmationResponse('Registration Exception. Please contact support.'));
          }
        }
      } catch (Exception e) {
        Logger.error('Exception when confirming self-registration via SMS. Contact Id: ' + contactId, e);
        Logger.saveLog();
        responses.add(new ConfirmationResponse('Registration Exception. Please contact support.'));
      }
    }

    return responses;
  }

}