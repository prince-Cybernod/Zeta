/**
 * Invocable wrapper for UserService.formatPhone method
 * Allows the method to be called from Flow, Process Builder, etc.
 */
public inherited sharing class FormatPhoneInvocable {

  /**
   * Request class for format phone invocable
   */
  public class FormatPhoneRequest {
    @InvocableVariable(Required=true Label='Phone Number' Description='The phone number to format')
    public String phoneNumber;
  }

  /**
   * Response class for format phone invocable
   */
  public class FormatPhoneResponse {
    @InvocableVariable(Label='Formatted Phone Number' Description='The formatted phone number')
    public String formattedPhoneNumber;

    public FormatPhoneResponse(String formattedPhoneNumber) {
      this.formattedPhoneNumber = formattedPhoneNumber;
    }
  }

  /**
   * Formats phone numbers for use in Flow, Process Builder, etc.
   * @param requests List of FormatPhoneRequest objects containing phone numbers to format
   * @return List of FormatPhoneResponse objects containing formatted phone numbers
   */
  @InvocableMethod(
    Label='Format Phone Number'
    Description='Formats a phone number according to country code standards'
    Category='User Management'
  )
  public static List<FormatPhoneResponse> formatPhone(List<FormatPhoneRequest> requests) {
    List<FormatPhoneResponse> responses = new List<FormatPhoneResponse>();

    for (FormatPhoneRequest request : requests) {
      String formattedPhone = UserService.formatPhone(request.phoneNumber);
      responses.add(new FormatPhoneResponse(formattedPhone));
    }

    return responses;
  }

}