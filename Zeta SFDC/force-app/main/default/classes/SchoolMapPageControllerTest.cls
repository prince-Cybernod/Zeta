@IsTest(IsParallel=true)
private class SchoolMapPageControllerTest {
  @IsTest
  private static void apiKey_returnsConfiguredValue() {
    SchoolMapPageController.configOverride = new Google_Maps_Config__mdt(
      Browser_Api_Key__c = 'test-browser-key-value'
    );

    SchoolMapPageController ctrl = new SchoolMapPageController();

    Assert.areEqual('test-browser-key-value', ctrl.apiKey);
  }

  @IsTest
  private static void apiKey_returnsNullWhenConfigMissing() {
    SchoolMapPageController.configOverride = null;

    SchoolMapPageController ctrl = new SchoolMapPageController();

    Google_Maps_Config__mdt deployed = Google_Maps_Config__mdt.getInstance(
      'Default'
    );
    String expected = deployed == null ? null : deployed.Browser_Api_Key__c;
    Assert.areEqual(expected, ctrl.apiKey);
  }

  @IsTest
  private static void apiKey_returnsNullWhenFieldBlank() {
    SchoolMapPageController.configOverride = new Google_Maps_Config__mdt(
      Browser_Api_Key__c = null
    );

    SchoolMapPageController ctrl = new SchoolMapPageController();

    Assert.areEqual(null, ctrl.apiKey);
  }
}