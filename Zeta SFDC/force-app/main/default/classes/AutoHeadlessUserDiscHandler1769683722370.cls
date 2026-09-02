/*
 * Auto Generated Headless User Discovery Handler
 */
global class AutoHeadlessUserDiscHandler1769683722370 implements Auth.HeadlessUserDiscoveryHandler {


	/*
	* This method handles the logic to determine the user account based on the loginHint and verificationMethod
	*/
	global Auth.HeadlessUserDiscoveryResponse discoverUserFromLoginHint(Id networkId, String loginHint, Auth.VerificationAction verificationAction, String customDataJson, Map<String,String>requestAttributes) {
		if (verificationAction == Auth.VerificationAction.EMAIL) {
			return doLookupByVerifiedEmail(loginHint, verificationAction);
		} else if (verificationAction == Auth.VerificationAction.SMS) {
			return doLookupByVerifiedMobile(loginHint, verificationAction);
		} else {
			return new Auth.HeadlessUserDiscoveryResponse(null, 'Unsupported Auth.VerificationAction');
		}
	}

	private Auth.HeadlessUserDiscoveryResponse doLookupByVerifiedEmail(String loginHint, Auth.VerificationAction verificationAction) {
		if (String.isBlank(loginHint) || !isValidEmail(loginHint)) {
			return new Auth.HeadlessUserDiscoveryResponse(null, 'Invalid email sent as loginHint: ' + loginHint);
		}
		// Search for an user account by email
		List<User> users = [SELECT Id FROM User WHERE Email = :loginHint AND IsActive = TRUE];
		if (!users.isEmpty() && users.size() == 1) {
			Id userId = users[0].Id;
			// Check if the user has a verified email
			List<TwoFactorMethodsInfo> verifiedInfo = [SELECT HasUserVerifiedEmailAddress FROM TwoFactorMethodsInfo WHERE UserId = :userId];
			if (!verifiedInfo.isEmpty() && verifiedInfo[0].HasUserVerifiedEmailAddress == true) {
				// Prepare and return HeadlessUserDiscoveryResponse with userId
				return new Auth.HeadlessUserDiscoveryResponse(new Set<Id>{userId}, null);
			} else {
				// Return HeadlessUserDiscoveryResponse with error message
				return new Auth.HeadlessUserDiscoveryResponse(null, 'Email ' + loginHint + ' not verified for the given user account');
			}
		} else {
			if (users.isEmpty()) {
				return new Auth.HeadlessUserDiscoveryResponse(null, 'No user identified for the email: ' + loginHint);
			} else {
				return new Auth.HeadlessUserDiscoveryResponse(null, 'Multiple users identified for the email: ' + loginHint);
			}
		}
	}

	private Auth.HeadlessUserDiscoveryResponse doLookupByVerifiedMobile(String loginHint, Auth.VerificationAction verificationAction) {
		String formattedSms = !String.isBlank(loginHint) ? getFormattedSms(loginHint) : null;
		if (String.isBlank(formattedSms)) {
			return new Auth.HeadlessUserDiscoveryResponse(null, 'Invalid phone number sent as loginHint: ' + loginHint);
		}
		// Search for an user account by phone
		List<User> users = [SELECT Id FROM User WHERE MobilePhone = :loginHint AND IsActive = TRUE];
		if (!users.isEmpty() && users.size() == 1) {
			Id userId = users[0].Id;
			// Check if the user has a verified phone
			List<TwoFactorMethodsInfo> verifiedInfo = [SELECT HasUserVerifiedMobileNumber FROM TwoFactorMethodsInfo WHERE UserId = :userId];
			if (!verifiedInfo.isEmpty() && verifiedInfo[0].HasUserVerifiedMobileNumber == true) {
				// Prepare and return HeadlessUserDiscoveryResponse with userId
				return new Auth.HeadlessUserDiscoveryResponse(new Set<Id>{userId}, null);
			} else {
				// Return HeadlessUserDiscoveryResponse with error message
				return new Auth.HeadlessUserDiscoveryResponse(null, ' ' + loginHint + ' not verified for the given user account');
			}
		} else {
			if (users.isEmpty()) {
				return new Auth.HeadlessUserDiscoveryResponse(null, 'No user identified for the phone number: ' + loginHint);
			} else {
				return new Auth.HeadlessUserDiscoveryResponse(null, 'Multiple users identified for the phone number: ' + loginHint);
			}
		}
	}

	private boolean isValidEmail(String identifier) {
		String emailRegex = '^[a-zA-Z0-9._|\\\\%#~`=?&/$^*!}{+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,4}$';
		// source: http://www.regular-expressions.info/email.html 
		Pattern EmailPattern = Pattern.compile(emailRegex);
		Matcher EmailMatcher = EmailPattern.matcher(identifier);
		if (EmailMatcher.matches()) { return true; }
		else { return false; }
	}

	private String getFormattedSms(String identifier) {
		// Accept SMS input formats with 1 or 2 digits country code, 3 digits area code and 7 digits number
		// You can customize the SMS regex to allow different formats
		String smsRegex = '^(\\+?\\d{1,2}?[\\s-])?(\\(?\\d{3}\\)?[\\s-]?\\d{3}[\\s-]?\\d{4})$';
		Pattern smsPattern = Pattern.compile(smsRegex);
		Matcher smsMatcher = SmsPattern.matcher(identifier);
		if (smsMatcher.matches()) {
			try {
				// Format user input into the verified SMS format '+xx xxxxxxxxxx' before DB lookup
				// Append US country code +1 by default if no country code is provided
				String countryCode = smsMatcher.group(1) == null ? '+1' : smsMatcher.group(1);
				return System.UserManagement.formatPhoneNumber(countryCode, smsMatcher.group(2));
			} catch(System.InvalidParameterValueException e) {
				return null;
			}
		} else { return null; }
	}

}