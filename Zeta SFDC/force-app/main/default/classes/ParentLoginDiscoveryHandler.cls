public inherited sharing class ParentLoginDiscoveryHandler implements Auth.LoginDiscoveryHandler {

  public PageReference login(
    String identifier,
    String startUrl,
    Map<String, String> requestAttributes
  ) {
    if (identifier == null) {
      throw new Auth.LoginDiscoveryException('Invalid Identifier');
    }

    if (identifier.contains('@')) {
      List<User> users = SOQL_User.query()
        .byProfileName(UserService.PROFILE)
        .byEmail(identifier)
        .isActive()
        .toList();

      if (!users.isEmpty() && users.size() == 1) {
        User user = users[0];
        TwoFactorMethodsInfo method = Test.isRunningTest()
          ? ParentLoginDiscoveryHandler_T.getTwoFactorMethodsInfo(user.Id)
          : UserService.getTwoFactorMethodsInfo(user.Id);

        if (method?.HasUserVerifiedEmailAddress == true) {
          return discoveryResult(user, Auth.VerificationMethod.EMAIL, startUrl);
        } else if (method?.HasUserVerifiedMobileNumber == true) {
          return discoveryResult(user, Auth.VerificationMethod.SMS, startUrl);
        } else {
          throw new Auth.LoginDiscoveryException('No verified 2FA method found for user.');
        }
      } else {
        throw new Auth.LoginDiscoveryException('No unique user found. User count=' + users.size());
      }
    }

    String formattedPhone = UserService.formatPhone(identifier);
    if (formattedPhone != null) {
      List<User> users = SOQL_User.query()
        .byProfileName(UserService.PROFILE)
        .byMobilePhone(formattedPhone)
        .isActive()
        .toList();

      if (!users.isEmpty() && users.size() == 1) {
        User user = users[0];
        TwoFactorMethodsInfo method = Test.isRunningTest()
          ? ParentLoginDiscoveryHandler_T.getTwoFactorMethodsInfo(user.Id)
          : UserService.getTwoFactorMethodsInfo(user.Id);

        if (method?.HasUserVerifiedMobileNumber == true) {
          return discoveryResult(user, Auth.VerificationMethod.SMS, startUrl);
        } else if (method?.HasUserVerifiedEmailAddress == true) {
          return discoveryResult(user, Auth.VerificationMethod.EMAIL, startUrl);
        } else {
          throw new Auth.LoginDiscoveryException('No verified 2FA method found for user.');
        }
      } else {
        throw new Auth.LoginDiscoveryException('No unique user found. User count=' + users.size());
      }
    }

    throw new Auth.LoginDiscoveryException('Invalid Identifier');
  }

  private static PageReference discoveryResult(
    User user,
    Auth.VerificationMethod method,
    String startUrl
  ) {
    PageReference passwordlessRedirect = Site.passwordlessLogin(
      user.Id,
      new List<Auth.VerificationMethod>{ method },
      startUrl
    );

    if (passwordlessRedirect != null) {
      return passwordlessRedirect;
    } else {
      throw new Auth.LoginDiscoveryException(
        'No Passwordless Login redirect URL returned for verification method: ' + method
      );
    }
  }

}