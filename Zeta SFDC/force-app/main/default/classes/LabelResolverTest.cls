/**
 * Tests for {@link LabelResolver}.
 */
@IsTest
private class LabelResolverTest {
  @IsTest
  private static void resolve_withKnownLabel_returnsValue() {
    String result = LabelResolver.resolve('AppUI_FieldName');

    Assert.areEqual(System.Label.AppUI_FieldName, result, 'Should resolve known Custom Label to its value');
  }

  @IsTest
  private static void resolve_returnsLabelInRunningUsersLanguage() {
    User spanishUser = new User(
      ProfileId = [SELECT Id FROM Profile WHERE Name = 'Standard User'].Id,
      LastName = 'LabelResolver',
      Email = 'labelresolver@example.com',
      Username = 'labelresolver' + Datetime.now().getTime() + '@example.com',
      Alias = 'lblres',
      TimeZoneSidKey = 'America/New_York',
      EmailEncodingKey = 'UTF-8',
      LanguageLocaleKey = 'es',
      LocaleSidKey = 'en_US'
    );
    insert spanishUser;

    System.runAs(spanishUser) {
      Assert.areEqual(
        System.Label.get('', 'AppUI_FieldName', 'es'),
        LabelResolver.resolve('AppUI_FieldName'),
        'Should resolve the label in the running user\'s language'
      );
    }
  }

  @IsTest
  private static void resolve_withBlankInput_returnsBlank() {
    Assert.areEqual(null, LabelResolver.resolve(null), 'Should return null for null input');
    Assert.areEqual('', LabelResolver.resolve(''), 'Should return empty for empty input');
    Assert.areEqual('  ', LabelResolver.resolve('  '), 'Should return whitespace for whitespace input');
  }

  @IsTest
  private static void resolve_withUnknownLabel_returnsInput() {
    String result = LabelResolver.resolve('Not_A_Real_Label_Name');

    Assert.areEqual('Not_A_Real_Label_Name', result, 'Should return input when label not found');
  }
}