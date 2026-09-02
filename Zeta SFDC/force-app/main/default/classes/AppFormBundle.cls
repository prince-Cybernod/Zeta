/**
 * Bundled response for the application-form initial load.
 * Combines form structure, existing answers, guardian defaults, and submission warnings
 * into a single cacheable Aura response to eliminate sequential round-trips.
 */
public class AppFormBundle {
  @AuraEnabled
  public AppQuestionFormStructure formStructure;
  @AuraEnabled
  public Map<String, Object> existingAnswers;
  @AuraEnabled
  public Map<String, String> guardianDefaults;
  @AuraEnabled
  public Map<String, Boolean> submissionWarnings;
}