/**
 * DTO carrying the visibility-criteria formula expression to the client
 * so the LWC can evaluate it locally instead of making a server round trip.
 */
public class AppQuestionVisibility {
  @AuraEnabled
  public String masterLabel;
  @AuraEnabled
  public String formulaExpression;
  @AuraEnabled
  public String entityApiName;

  public static AppQuestionVisibility fromCriteria(SObject_Field_Criteria__mdt criteria) {
    if (criteria == null || String.isBlank(criteria.Formula_Expression__c)) {
      return null;
    }
    AppQuestionVisibility dto = new AppQuestionVisibility();
    dto.masterLabel = criteria.MasterLabel;
    dto.formulaExpression = criteria.Formula_Expression__c;
    dto.entityApiName = criteria.Entity_Definition__r != null
      ? criteria.Entity_Definition__r.QualifiedApiName
      : null;
    return dto;
  }
}