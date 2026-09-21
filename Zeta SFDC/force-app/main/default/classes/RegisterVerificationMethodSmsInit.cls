/**
 * Invocable method to initiate verification method registration via SMS for an existing user
 */
public without sharing class RegisterVerificationMethodSmsInit {

  /**
   * Initiates registering SMS verification method for the current user
   * @param requests List of Request objects
   * @return List of Response objects
   */
  @InvocableMethod(
    Label='Init Register Verification Method By SMS'
    Description='Initiates registration of SMS verification method for an existing user'
    Category='User Management'
  )
  public static List<RegisterVerificationMethodInit.Response> initRegisterVerificationMethodSMS(
  ) {
    List<RegisterVerificationMethodInit.Request> initRequests =
      new List<RegisterVerificationMethodInit.Request>();

      RegisterVerificationMethodInit.Request req = new RegisterVerificationMethodInit.Request();
      req.method = 'SMS';
      initRequests.add(req);

    return RegisterVerificationMethodInit.initRegisterVerificationMethod(initRequests);
  }
}