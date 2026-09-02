public class AppQuestionInput {
  private static final Set<String> PICKLIST_INPUT_TYPES = new Set<String>{
    'Dropdown',
    'MultiCheckbox'
  };
  private static final String ADDRESS_INPUT_TYPE = 'Address';

  @AuraEnabled
  public String developerName;
  @AuraEnabled
  public String label;
  @AuraEnabled
  public String inputType;
  @AuraEnabled
  public String targetObject;
  @AuraEnabled
  public String targetField;
  @AuraEnabled
  public Boolean isRequired;
  @AuraEnabled
  public String helpText;
  @AuraEnabled
  public String placeholder;
  @AuraEnabled
  public String defaultValue;
  @AuraEnabled
  public String validationMessage;
  @AuraEnabled
  public String validationPattern;
  @AuraEnabled
  public Integer maxLength;
  @AuraEnabled
  public Integer sortOrder;
  @AuraEnabled
  public Integer columnSpan;
  @AuraEnabled
  public List<AppQuestionOption> options;
  @AuraEnabled
  public Boolean hasVisibilityRule;
  @AuraEnabled
  public AppQuestionVisibility visibilityCriteria;
  @AuraEnabled
  public Map<String, String> fieldBindings;
  @AuraEnabled
  public String companionQuestionDevName;
  @AuraEnabled
  public Boolean invertDisplay;

  public static AppQuestionInput fromCmdt(Application_Question__mdt q) {
    AppQuestionInput dto = new AppQuestionInput();
    dto.developerName = q.DeveloperName;
    dto.label = q.Display_Label__c;
    dto.inputType = q.Input_Type__c;
    dto.isRequired = q.Is_Required__c;
    dto.helpText = q.Help_Text__c;
    dto.placeholder = q.Placeholder__c;
    dto.validationMessage = q.Validation_Message__c;
    dto.validationPattern = q.Validation_Pattern__c;
    dto.defaultValue = q.Default_Value__c;
    dto.maxLength = q.Max_Length__c != null ? Integer.valueOf(q.Max_Length__c) : null;
    dto.sortOrder = q.Sort_Order__c != null ? Integer.valueOf(q.Sort_Order__c) : null;
    dto.columnSpan = q.Column_Span__c != null ? Integer.valueOf(q.Column_Span__c) : 1;
    dto.options = new List<AppQuestionOption>();
    dto.hasVisibilityRule =
      q.Visibility_Criteria__r != null &&
      String.isNotBlank(q.Visibility_Criteria__r.Formula_Expression__c);
    dto.visibilityCriteria = AppQuestionVisibility.fromCriteria(q.Visibility_Criteria__r);
    dto.companionQuestionDevName = String.isNotBlank(q.Companion_Question__c)
      ? q.Companion_Question__c
      : null;
    dto.invertDisplay = q.Invert_Display__c == true;

    // Compound inputs (e.g., Address) intentionally have no Target_Field
    // mapping — they render multi-field UI bound to the parent record via the
    // LWC layer rather than to a single SObject field.
    if (q.Target_Field__r != null) {
      SObjectType targetSObjectType = SObjectFieldCmdtParser.getSObjectType(q.Target_Field__r);
      SObjectField sObjectField = SObjectFieldCmdtParser.getSObjectField(q.Target_Field__r);
      DescribeFieldResult fieldDescribe = sObjectField.getDescribe();
      dto.targetObject = targetSObjectType.getDescribe().getName();
      dto.targetField = fieldDescribe.getName();

      if (PICKLIST_INPUT_TYPES.contains(q.Input_Type__c)) {
        dto.options = AppQuestionOption.fromDescribe(fieldDescribe);
      }
    }

    if (ADDRESS_INPUT_TYPE.equals(q.Input_Type__c) && String.isNotBlank(q.Field_Bindings__c)) {
      try {
        Map<String, Object> raw = (Map<String, Object>) JSON.deserializeUntyped(
          q.Field_Bindings__c
        );
        Map<String, String> bindings = new Map<String, String>();
        for (String slot : raw.keySet()) {
          Object value = raw.get(slot);
          bindings.put(slot, value == null ? null : String.valueOf(value));
        }
        dto.fieldBindings = bindings;
      } catch (Exception e) {
        // Leave fieldBindings null; LWC will treat as un-bound.
      }
    }

    return dto;
  }
}