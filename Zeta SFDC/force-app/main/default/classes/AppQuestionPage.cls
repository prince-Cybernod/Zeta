public class AppQuestionPage {
  @AuraEnabled
  public String developerName;
  @AuraEnabled
  public String label;
  @AuraEnabled
  public String description;
  @AuraEnabled
  public Integer sortOrder;
  @AuraEnabled
  public String pageType;
  @AuraEnabled
  public String componentName;

  public static AppQuestionPage fromCmdt(Application_Page__mdt p) {
    AppQuestionPage dto = new AppQuestionPage();
    dto.developerName = p.DeveloperName;
    dto.label = p.Display_Label__c;
    dto.description = p.Description__c;
    dto.sortOrder = p.Sort_Order__c != null ? Integer.valueOf(p.Sort_Order__c) : null;
    dto.pageType = p.Page_Type__c;
    dto.componentName = p.Component_Name__c;
    return dto;
  }
}