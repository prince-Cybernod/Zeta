/**
 * Invocable method to initiate verification method registration via Email for an existing user
 */
public without sharing class RegisterVerificationMethodEmailInit {

  /**
   * Initiates registering email verification method for the current user
   * @param requests List of Request objects
   * @return List of Response objects
   */
  @InvocableMethod(
    Label='Init Register Verification Method By Email'
    Description='Initiates registration of Email verification method for an existing user'
    Category='User Management'
  )
  public static List<RegisterVerificationMethodInit.Response> initRegisterVerificationMethodEmail(
  ) {
    List<RegisterVerificationMethodInit.Request> initRequests =
      new List<RegisterVerificationMethodInit.Request>();

    RegisterVerificationMethodInit.Request req = new RegisterVerificationMethodInit.Request();
    req.method = 'EMAIL';
    initRequests.add(req);

    return RegisterVerificationMethodInit.initRegisterVerificationMethod(initRequests);
  }
}