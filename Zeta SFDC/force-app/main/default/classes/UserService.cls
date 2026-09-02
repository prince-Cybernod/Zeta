public inherited sharing class UserService {

  public static final String PROFILE = 'Zeta Parent Portal User';

  public static String formatPhone(String identifier) {
    if (String.isBlank(identifier)) {
      return null;
    }

    // Check if this is a non-US number that already has a space after country code
    // Example: "+64 123456789"
    if (identifier.startsWith('+') && !identifier.startsWith('+1') &&
      identifier.indexOf(' ') > 0 && identifier.indexOf(' ') <= 4) {
      return identifier; // Return as-is to preserve existing format
    }

    // Strip all non-digit characters except the + sign
    String digitsOnly = identifier.replaceAll('[^\\d+]', '');

    // Basic validation - must have at least 7 digits total
    if (!Pattern.matches('^\\+?\\d{7,15}$', digitsOnly)) {
      return null;
    }

    try {
      String countryCode;
      String phoneNumber;
      String formattedNumber;

      // Handle numbers with or without country code
      if (digitsOnly.startsWith('+')) {
        // Extract country code - match the + and 1-3 digits
        Pattern countryPattern = Pattern.compile('^\\+(\\d{1,3})(.*)$');
        Matcher matcher = countryPattern.matcher(digitsOnly);

        if (matcher.matches()) {
          // Group 1 = the digits of the country code (without +)
          // Group 2 = the rest of the phone number
          countryCode = matcher.group(1);
          phoneNumber = matcher.group(2);
        } else {
          // Fallback if regex fails (shouldn't happen given our initial check)
          return digitsOnly;
        }
      } else {
        // Default to US country code if none provided
        countryCode = '1';
        phoneNumber = digitsOnly;
      }

      // Use Salesforce's built-in formatter with extracted parts
      formattedNumber = System.UserManagement.formatPhoneNumber(countryCode, phoneNumber);

      // For US numbers, ensure there's a space after the country code
      if (countryCode == '1') {
        // If the formatted number doesn't have a space after +1, add it
        if (formattedNumber.startsWith('+1') && !formattedNumber.startsWith('+1 ')) {
          formattedNumber = '+1 ' + formattedNumber.substring(2);
        }
      }

      return formattedNumber;
    } catch (System.InvalidParameterValueException e) {
      // Fall back to the basic formatted version if the system formatter fails
      if (digitsOnly.startsWith('+')) {
        // For US numbers with country code, ensure there's a space
        if (digitsOnly.startsWith('+1')) {
          return '+1 ' + digitsOnly.substring(2);
        }
        return digitsOnly;
      } else {
        // For US numbers without country code, add +1 with a space
        return '+1 ' + digitsOnly;
      }
    }
  }

  public static User getUser(String email, String phone, String firstName, String lastName, String identifier, Id contactId) {
    String alias = UserAliasGenerator.getAlias(firstName, lastName);
    String nickname = alias + Math.abs(Crypto.getRandomInteger());
    String username = nickname + '@zetaschools.org';

    User u = new User();
    u.Email = email;
    u.LastName = lastName;
    u.FirstName = firstName;
    u.MobilePhone = phone;
    u.Phone = phone;
    u.Alias = alias;
    u.CommunityNickname = nickname;
    u.Username = username;
    u.LanguageLocaleKey = UserInfo.getLocale();
    u.LocaleSidKey = UserInfo.getLocale();
    u.EmailEncodingKey = 'UTF-8';
    u.TimeZoneSidKey = 'America/Los_Angeles';
    u.ProfileId = [SELECT Id FROM Profile WHERE Name = :PROFILE]?.Id;
    u.ContactId = contactId;
    u.FederationIdentifier = identifier;
    return u;
  }

//  public static void setPortalUser(String contactId) {
//    if (contactId != null) {
//      setPortalUser(contactId, [SELECT Id FROM User WHERE ContactId = :contactId]?.Id);
//    }
//  }

//  public static void setPortalUser(String contactId, Id userId) {
//    if (contactId != null && userId != null) {
//      update new Contact(
//        Id = contactId
//      );
//    }
//  }

  public static Id getUserIdByContactId(Id contactId) {
    if (contactId == null) {
      return null;
    }
    List<User> users = [SELECT Id FROM User WHERE ContactId = :contactId LIMIT 1];
    return users.isEmpty() ? null : users[0].Id;
  }

  public static String getUniqueEmailAddress() {
    String ret = String.format(
      '{0}_{1}_{2}@{3}.invalid',
      new List<String>{
        'user',
        String.valueOf(Datetime.now().getTime()),
        String.valueOf((Integer) Math.rint(Math.random() * 1000000)),
        UserInfo.getOrganizationId()
      }
    );
    if ([SELECT COUNT() FROM User WHERE Email = :ret] > 0) {
      return getUniqueEmailAddress();
    }
    return ret;
  }

  public static TwoFactorMethodsInfo getTwoFactorMethodsInfo(Id userId) {
    List<TwoFactorMethodsInfo> verifiedInfo = [
      SELECT
        HasUserVerifiedMobileNumber,
        HasUserVerifiedEmailAddress
      FROM TwoFactorMethodsInfo
      WHERE UserId = :userId
    ];
    return verifiedInfo.isEmpty() ? null : verifiedInfo[0];
  }

  public static List<ThirdPartyAccountLink> getAuthProviders(Id userId) {
    List<ThirdPartyAccountLink> userAuthProviders = [
      SELECT
        SsoProvider.SsoKickoffUrl,
        SsoProvider.DeveloperName
      FROM
        ThirdPartyAccountLink
      WHERE UserId = :userId
    ];
    return userAuthProviders;
  }

}