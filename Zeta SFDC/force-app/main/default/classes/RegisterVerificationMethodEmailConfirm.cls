/**
 * Invocable method to verify registration of Email verification method for an existing user
 */
public without sharing class RegisterVerificationMethodEmailConfirm {
  /**
   * Request structure for verifying email verification method registration
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
   * Verifies the verification code for registering Email verification method
   * @param requests List of Request objects
   * @return List of Response objects
   */
  @InvocableMethod(
    Label='Verify Register Verification Method By Email'
    Description='Verifies verification code for registering Email verification method for an existing user'
    Category='User Management'
  )
  public static List<RegisterVerificationMethodConfirm.Response> verifyRegisterVerificationMethodEmail(
    List<Request> requests
  ) {
    List<RegisterVerificationMethodConfirm.Request> confirmRequests =
      new List<RegisterVerificationMethodConfirm.Request>();

    for (Request i : requests) {
      RegisterVerificationMethodConfirm.Request req =
        new RegisterVerificationMethodConfirm.Request();
      req.code = i.code;
      req.method = 'EMAIL';
      confirmRequests.add(req);
    }

    return RegisterVerificationMethodConfirm.verifyRegisterVerificationMethod(confirmRequests);
  }
}