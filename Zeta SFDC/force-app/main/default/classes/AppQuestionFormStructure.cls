public class AppQuestionFormStructure {
  @AuraEnabled
  public AppQuestionPage page;
  @AuraEnabled
  public List<AppQuestionSection> sections;
  @AuraEnabled
  public List<String> controllingQuestionDevNames;
}