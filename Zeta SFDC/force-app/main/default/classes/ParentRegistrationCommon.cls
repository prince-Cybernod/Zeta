/**
 * Abstract base class for parent registration functionality
 * Contains shared utilities and data structures
 */
public abstract inherited sharing class ParentRegistrationCommon {

  /**
   * Class for handling initial registration requests
   */
  public class RegistrationRequest {
    @InvocableVariable(Required=true)
    public String firstName;

    @InvocableVariable(Required=true)
    public String lastName;

    @InvocableVariable
    public String phone;

    @InvocableVariable
    public String email;

    @InvocableVariable
    public String contactId;

    @InvocableVariable
    public String startUrl;
    @InvocableVariable
    public String street;
    @InvocableVariable
    public String city;
    @InvocableVariable
    public String state;
    @InvocableVariable
    public String postalCode;
    @InvocableVariable
    public String country;
  }

  /**
   * Class for handling code confirmation requests
   */
  public class CodeConfirmationRequest {
    @InvocableVariable(Required=true)
    public String selfRegId;

    @InvocableVariable(Required=true)
    public String code;

    @InvocableVariable
    public String phone;

    @InvocableVariable
    public String email;

    @InvocableVariable
    public String startUrl;

    @InvocableVariable
    public String contactId;
  }

  /**
   * Class for registration responses
   */
  public class RegistrationResponse {
    @InvocableVariable
    public String selfRegId;

    @InvocableVariable
    public String contactId;

    @InvocableVariable
    public String accountId;

    @InvocableVariable
    public String errorMessage;

    public RegistrationResponse(String errorMessage) {
      this.errorMessage = errorMessage;
    }

    public RegistrationResponse(String selfRegId, String contactId, String accountId) {
      this.selfRegId = selfRegId;
      this.contactId = contactId;
      this.accountId = accountId;
    }
  }

  /**
   * Class for confirmation responses
   */
  public class ConfirmationResponse {
    @InvocableVariable
    public String errorMessage;

    @InvocableVariable
    public String redirectUrl;

    @InvocableVariable
    public String accountId;

    @InvocableVariable
    public String userId;

    public ConfirmationResponse(String errorMessage) {
      this.errorMessage = errorMessage;
    }

    public ConfirmationResponse(PageReference redirect, String accountId, String userId) {
      this.redirectUrl = redirect?.getUrl();
      this.accountId = accountId;
      this.userId = userId;
    }

    public ConfirmationResponse(PageReference redirect) {
      this.redirectUrl = redirect?.getUrl();
    }
  }

}