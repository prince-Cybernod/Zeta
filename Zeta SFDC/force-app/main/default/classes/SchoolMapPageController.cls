public with sharing class SchoolMapPageController {
  @TestVisible
  private static Google_Maps_Config__mdt configOverride;

  public String apiKey {
    get {
      Google_Maps_Config__mdt cfg = configOverride != null
        ? configOverride
        : Google_Maps_Config__mdt.getInstance('Default');
      return cfg?.Browser_Api_Key__c;
    }
  }
}