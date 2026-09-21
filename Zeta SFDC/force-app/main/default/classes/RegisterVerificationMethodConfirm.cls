/**
 * Invocable method to verify registration of a verification method for an existing user
 */
public without sharing class RegisterVerificationMethodConfirm {
  @TestVisible
  public enum TestScenario {
    SUCCESS,
    INVALID_TOKEN,
    THROW_EXCEPTION
  }

  /**
   * Request structure for verifying verification method registration
   */
  public class Request {
    @InvocableVariable(
      Label='Verification Code'
      Description='The verification code entered by the user'
      Required=true
    )
    public String code;

    @InvocableVariable(
      Label='Verification Method'
      Description='Verification method: EMAIL, SMS, SALESFORCE_AUTHENTICATOR, TOTP, etc.'
      Required=true
    )
    public String method;
  }

  /**
   * Response structure for verifying verification method registration
   */
  public class Response {
    @InvocableVariable(
      Label='Success'
      Description='Indicates if verification was successful'
    )
    public Boolean success;

    @InvocableVariable(
      Label='Redirect URL'
      Description='Redirect URL after successful verification if applicable'
    )
    public String redirectUrl;

    @InvocableVariable(
      Label='Error Message'
      Description='Error message if verification failed'
    )
    public String errorMessage;

    public Response() {
      this.success = false;
    }

    public Response(Boolean success, String redirectUrl) {
      this.success = success;
      this.redirectUrl = redirectUrl;
    }

    public Response(String errorMessage) {
      this.success = false;
      this.errorMessage = errorMessage;
    }
  }

//  private static final Logger LOGGER = new Logger('RegisterVerificationMethodConfirm');

  @TestVisible
  private static TestScenario scenario;

  /**
   * Verifies the verification code for registering a verification method
   * @param requests List of Request objects
   * @return List of Response objects
   */
  @InvocableMethod(
    Label='Verify Register Verification Method'
    Description='Verifies verification code for registering a verification method for an existing user'
    Category='User Management'
  )
  public static List<Response> verifyRegisterVerificationMethod(List<Request> requests) {
    List<Response> responses = new List<Response>();

    for (Request i : requests) {
      Auth.VerificationResult res = new Auth.VerificationResult(null, false, null);
      String code = i.code;
      String method = i.method;

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
            Auth.VerificationMethod verificationMethod = RegisterVerificationMethodInit.toVerificationMethod(
              method
            );
            String redirectUrl = System.UserManagement.verifyRegisterVerificationMethod(
              code,
              verificationMethod
            );
            responses.add(new Response(true, redirectUrl));
            continue;
          }
        }
      } catch (Exception e) {
//        LOGGER.log(
//          e,
//          'Exception when verifying register verification method. Method: ' + method
//        );
        responses.add(
          new Response(e.getMessage() ?? 'Registration Exception. Please contact support.')
        );
        continue;
      }

      if (res.success) {
        responses.add(new Response(true, res.redirect?.getUrl()));
      } else {
        if (res.message == 'Token not valid') {
          responses.add(new Response(res.message));
        } else {
//          LOGGER.log(
//            res.message,
//            'Error when verifying register verification method. Method: ' + method
//          );
          responses.add(
            new Response(res.message ?? 'Registration Exception. Please contact support.')
          );
        }
      }
    }

    return responses;
  }
}