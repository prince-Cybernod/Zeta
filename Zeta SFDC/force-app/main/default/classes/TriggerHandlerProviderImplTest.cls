/**
 * Tests for {@link TriggerHandlerProviderImpl}.
 */
@IsTest(IsParallel=true)
private class TriggerHandlerProviderImplTest {
  private static final TriggerHandlerProviderImpl TRIGGER_HANDLER_PROVIDER_IMPL;

  static {
    TRIGGER_HANDLER_PROVIDER_IMPL = new TriggerHandlerProviderImpl();
  }

  @IsTest
  private static void get_opportunitySObjectType_returnsOpportunityTriggerHandlers() {
    SObjectType sobjectType = Opportunity.SObjectType;

    List<TriggerHandler> triggerHandlers = TRIGGER_HANDLER_PROVIDER_IMPL.get(sobjectType);

    // The assert will depend on if the org actually has a TriggerHandler for Opportunity. We can't
    // mock the query result because Type.forName() expects to construct a real class and we don't
    // want to make a real class because it's likely that the org will want to create their own
    // OpportunityTriggerHandler. This one was picked because it's likely to be a popular choice.
    Assert.areEqual(getOpportunityTriggerHandlerCount(), triggerHandlers.size());
  }

  private static Integer getOpportunityTriggerHandlerCount() {
    List<ApexTypeImplementor> implementors = TriggerHandlerProviderImpl.getApexTypeImplementors();

    Integer count = 0;
    for (ApexTypeImplementor implementor : implementors) {
      TriggerHandler triggerHandler = TriggerHandlerProviderImpl.buildTriggerHandler(implementor);
      if (triggerHandler.getSObjectType() == Opportunity.SObjectType) {
        count++;
      }
    }

    return count;
  }
}