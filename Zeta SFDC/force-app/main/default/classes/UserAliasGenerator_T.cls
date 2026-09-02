@IsTest
private class UserAliasGenerator_T {

  @IsTest
  static void longLastNameUsesFirstInitialPlusSevenChars() {
    String firstName = 'John';
    String lastName = 'Richardson';

    String alias = UserAliasGenerator.getAlias(firstName, lastName);

    Assert.areEqual('jrichard', alias, 'Long last name should use first initial + 7 chars');
  }

  @IsTest
  static void shortLastNameUsesMoreFirstNameChars() {
    String firstName = 'Robert';
    String lastName = 'Lee';

    String alias = UserAliasGenerator.getAlias(firstName, lastName);

    Assert.areEqual('roberlee', alias, 'Short last name should use more chars from first name');
  }

  @IsTest
  static void blankFirstNameUsesLastName() {
    String firstName = '';
    String lastName = 'Smith';

    String alias = UserAliasGenerator.getAlias(firstName, lastName);

    Assert.areEqual('smith', alias, 'Blank first name should use last name');
  }

  @IsTest
  static void blankLastNameUsesFirstName() {
    String firstName = 'Robert';
    String lastName = '';

    String alias = UserAliasGenerator.getAlias(firstName, lastName);

    Assert.areEqual('robert', alias, 'Blank last name should use first name');
  }

  @IsTest
  static void specialCharactersAreRemoved() {
    String firstName = 'Mary-Jane';
    String lastName = 'O\'Connor';

    String alias = UserAliasGenerator.getAlias(firstName, lastName);

    Assert.areEqual('moconnor', alias, 'Special characters should be removed');
  }

  @IsTest
  static void veryShortNamesArePaddedToMinLength() {
    String firstName = 'Jo';
    String lastName = 'Li';

    String alias = UserAliasGenerator.getAlias(firstName, lastName);

    Assert.areEqual('joli', alias, 'Very short names should be padded to minimum length');
  }

  @IsTest
  static void bothNamesEmptyReturnsDefault() {
    String bothEmpty = UserAliasGenerator.getAlias('', '');
    String bothNull = UserAliasGenerator.getAlias(null, null);
    String onlySpecialChars = UserAliasGenerator.getAlias('!@#', '$%^');

    Assert.areEqual('na', bothEmpty, 'Both empty inputs should return na');
    Assert.areEqual('na', bothNull, 'Both null inputs should return na');
    Assert.areEqual('na', onlySpecialChars, 'Names with only special characters should return na');
  }

}