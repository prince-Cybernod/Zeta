public class UserEmailConfirmationResponse {
  @InvocableVariable(Label='User Id')
  public String userId;

  @InvocableVariable(Label='Success')
  public Boolean success;

  @InvocableVariable(Label='Error Message')
  public String errorMessage;
}