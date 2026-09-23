/**
 * Invocable method to initiate verification method registration for an existing user
 */
public without sharing class RegisterVerificationMethodInit {
  @TestVisible
  public enum TestScenario {
    SUCCESS,
    THROW_EXCEPTION
  }

  /**
   * Request structure for initiating verification method registration
   */
  public class Request {
    @InvocableVariable(
      Label='Verification Method'
      Description='Verification method: EMAIL, SMS'
      Required=true
    )
    public String method;
  }

  /**
   * Response structure for initiating verification method registration
   */
  public class Response {
    @InvocableVariable(
      Label='Success'
      Description='Indicates if the init request succeeded'
    )
    public Boolean success;

    @InvocableVariable(
      Label='Redirect URL'
      Description='Redirect URL returned by init method if applicable'
    )
    public String redirectUrl;

    @InvocableVariable(
      Label='Error Message'
      Description='Error message if init request failed'
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

  @TestVisible
  private static TestScenario scenario;

  /**
   * Initiates registering a verification method for the current user
   * @param requests List of Request objects
   * @return List of Response objects
   */
  @InvocableMethod(
    Label='Init Register Verification Method'
    Description='Initiates registration of a verification method for an existing user'
    Category='User Management'
  )
  public static List<Response> initRegisterVerificationMethod(List<Request> requests) {
    List<Response> responses = new List<Response>();

    for (Request i : requests) {
      try {
        switch on scenario {
          when SUCCESS {
            responses.add(new Response(true, '/s/test-verify'));
          }
          when THROW_EXCEPTION {
            throw new NullPointerException();
          }
          when else {
            Auth.VerificationMethod verificationMethod = toVerificationMethod(i.method);

            String redirectUrl = System.UserManagement.initRegisterVerificationMethod(
              verificationMethod
            );
            responses.add(new Response(true, redirectUrl));
          }
        }
      } catch (Exception e) {
        Logger.error(
          'Exception when initialising register verification method. Method: ' + i.method,
          e
        );
        Logger.saveLog();
        responses.add(
          new Response(e.getMessage() ?? 'Registration Exception. Please contact support.')
        );
      }
    }

    return responses;
  }

  /**
   * Helper method to convert string to Auth.VerificationMethod enum
   * @param methodStr String representation of the verification method
   * @return Auth.VerificationMethod corresponding enum
   */
  public static Auth.VerificationMethod toVerificationMethod(String methodStr) {
    if (String.isBlank(methodStr)) {
      return Auth.VerificationMethod.EMAIL;
    }
    String normalized = methodStr.trim().toUpperCase();
    if (normalized == 'EMAIL') {
      return Auth.VerificationMethod.EMAIL;
    } else if (normalized == 'SMS') {
      return Auth.VerificationMethod.SMS;
    } else if (
      normalized == 'SALESFORCE_AUTHENTICATOR' ||
      normalized == 'SALESFORCEAUTHENTICATOR' ||
      normalized == 'AUTHENTICATOR'
    ) {
      return Auth.VerificationMethod.SALESFORCE_AUTHENTICATOR;
    } else if (normalized == 'TOTP') {
      return Auth.VerificationMethod.TOTP;
    } else if (normalized == 'U2F') {
      return Auth.VerificationMethod.U2F;
    } else if (normalized == 'PASSWORD') {
      return Auth.VerificationMethod.PASSWORD;
    }

    for (Auth.VerificationMethod m : Auth.VerificationMethod.values()) {
      if (m.name().equalsIgnoreCase(normalized)) {
        return m;
      }
    }

    throw new IllegalArgumentException('Unsupported verification method: ' + methodStr);
  }
}