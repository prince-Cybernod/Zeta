/**
 * Invocable method to verify registration of SMS verification method for an existing user
 */
public without sharing class RegisterVerificationMethodSmsConfirm {
  /**
   * Request structure for verifying SMS verification method registration
   */
  public class Request {
    @InvocableVariable(
      Label='Verification Code'
      Description='The verification code entered by the user'
      Required=true
    )
    public String code;
  }

  /**
   * Verifies the verification code for registering SMS verification method
   * @param requests List of Request objects
   * @return List of Response objects
   */
  @InvocableMethod(
    Label='Verify Register Verification Method By SMS'
    Description='Verifies verification code for registering SMS verification method for an existing user'
    Category='User Management'
  )
  public static List<RegisterVerificationMethodConfirm.Response> verifyRegisterVerificationMethodSMS(
    List<Request> requests
  ) {
    List<RegisterVerificationMethodConfirm.Request> confirmRequests =
      new List<RegisterVerificationMethodConfirm.Request>();

    for (Request i : requests) {
      RegisterVerificationMethodConfirm.Request req =
        new RegisterVerificationMethodConfirm.Request();
      req.code = i.code;
      req.method = 'SMS';
      confirmRequests.add(req);
    }

    return RegisterVerificationMethodConfirm.verifyRegisterVerificationMethod(confirmRequests);
  }
}