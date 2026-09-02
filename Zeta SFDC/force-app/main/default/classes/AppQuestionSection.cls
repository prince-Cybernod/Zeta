public class AppQuestionSection {
  @AuraEnabled
  public String developerName;
  @AuraEnabled
  public String label;
  @AuraEnabled
  public String description;
  @AuraEnabled
  public Integer sortOrder;
  @AuraEnabled
  public Integer columns;
  @AuraEnabled
  public String variant;
  @AuraEnabled
  public Boolean collapsible;
  @AuraEnabled
  public Boolean autoCollapseWhenComplete;
  @AuraEnabled
  public String summaryTemplate;
  @AuraEnabled
  public List<AppQuestionInput> questions;
  @AuraEnabled
  public Boolean hasVisibilityRule;
  @AuraEnabled
  public AppQuestionVisibility visibilityCriteria;

  public static AppQuestionSection fromCmdt(
    Application_Section__mdt s,
    List<AppQuestionInput> questions
  ) {
    AppQuestionSection dto = new AppQuestionSection();
    dto.developerName = s.DeveloperName;
    dto.label = s.Display_Label__c;
    dto.description = s.Description__c;
    dto.sortOrder = s.Sort_Order__c != null ? Integer.valueOf(s.Sort_Order__c) : null;
    dto.columns = s.Columns__c != null ? Integer.valueOf(s.Columns__c) : 1;
    dto.variant = s.Variant__c;
    dto.collapsible = s.Collapsible__c == true;
    dto.autoCollapseWhenComplete = s.Auto_Collapse_When_Complete__c == true;
    dto.summaryTemplate = s.Summary_Template__c;
    dto.questions = questions;
    dto.hasVisibilityRule =
      s.Visibility_Criteria__r != null &&
      String.isNotBlank(s.Visibility_Criteria__r.Formula_Expression__c);
    dto.visibilityCriteria = AppQuestionVisibility.fromCriteria(s.Visibility_Criteria__r);
    return dto;
  }
}