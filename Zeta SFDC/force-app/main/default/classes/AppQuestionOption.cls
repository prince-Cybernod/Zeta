public class AppQuestionOption {
  @AuraEnabled
  public String label;
  @AuraEnabled
  public String value;

  public static List<AppQuestionOption> fromDescribe(DescribeFieldResult fieldDescribe) {
    List<AppQuestionOption> options = new List<AppQuestionOption>();
    for (PicklistEntry entry : fieldDescribe.getPicklistValues()) {
      if (entry.isActive()) {
        AppQuestionOption option = new AppQuestionOption();
        option.label = entry.getLabel();
        option.value = entry.getValue();
        options.add(option);
      }
    }
    return options;
  }
}