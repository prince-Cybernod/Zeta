public with sharing class UserEmailConfirmationInvocable {
  public class UserEmailConfirmationRequest {
    @InvocableVariable(Label='User Ids' Required=true)
    public List<String> userIds;

    @InvocableVariable(Label='Email Template Id')
    public String emailTemplateId;

    @InvocableVariable(Label='Network Id')
    public String networkId;

    @InvocableVariable(Label='Start Url')
    public String startUrl;
  }

  @InvocableMethod(
    Label='Send Async Email Confirmation'
    Description='Sends email confirmation to users'
  )
  public static List<List<UserEmailConfirmationResponse>> sendAsyncEmailConfirmation(
    List<UserEmailConfirmationRequest> requests
  ) {
    List<List<UserEmailConfirmationResponse>> results = new List<List<UserEmailConfirmationResponse>>();

    for (UserEmailConfirmationRequest request : requests) {
      List<UserEmailConfirmationResponse> requestResponses = new List<UserEmailConfirmationResponse>();
      for (String userId : request.userIds) {
        UserEmailConfirmationResponse response = new UserEmailConfirmationResponse();
        response.userId = userId;
        try {
          response.success = UserManagement.sendAsyncEmailConfirmation(
            userId,
            request.emailTemplateId,
            request.networkId,
            request.startUrl
          );
        } catch (Exception e) {
          response.success = false;
          response.errorMessage = e.getMessage();
        }
        requestResponses.add(response);
      }
      results.add(requestResponses);
    }
    return results;
  }
}