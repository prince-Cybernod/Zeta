@IsTest
private class ActionPlanBulkWhereClauseTest {
    
    @TestSetup
    static void setupTestData() {
        // Create a template with a WHERE clause
        ActionPlanTemplate__c template = new ActionPlanTemplate__c(
            Name = 'Smith Action Plan',
            Target_Object_API_Name__c = 'Account',
            Where_Clause__c = 'Name LIKE \'Smith%\'',
            SkipWeekends__c = false,
            Archived__c = false
        );
        insert template;
        
        // Add a task to the template
        APTemplateTask__c task = new APTemplateTask__c(
            Action_Plan_Template__c = template.Id,
            Subject__c = 'Welcome Smith',
            Priority__c = 'Normal',
            Type__c = 'Email',
            DaysFromStart__c = 1,
            Dependent__c = 'None',
            TaskIndex__c = 1
        );
        insert task;
    }
    
    @IsTest
    static void testBulkInsertWithWhereClause() {
        // Create 100 accounts that match the WHERE clause
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 100; i++) {
            accounts.add(new Account(Name = 'Smith ' + i));
        }
        
        Test.startTest();
        // This will trigger the account trigger which calls ActionPlanTriggerUtility.invoke
        insert accounts;
        Test.stopTest();
        
        // Verify that only 100 action plans were created (one per account)
        // Before the fix, this would have created 10,000 action plans
        List<ActionPlan__c> plans = [SELECT Id FROM ActionPlan__c];
        Assert.areEqual(100, plans.size(), 'Should have exactly 100 action plans, one for each matching account');
        
        // Check DML row count in the log would also confirm
    }

    @IsTest
    static void testMixedRequestsWithWhereClause() {
        // Create a second template without WHERE clause
        ActionPlanTemplate__c template2 = new ActionPlanTemplate__c(
            Name = 'Standard Plan',
            Target_Object_API_Name__c = 'Account',
            SkipWeekends__c = false,
            Archived__c = false
        );
        insert template2;
        
        APTemplateTask__c task2 = new APTemplateTask__c(
            Action_Plan_Template__c = template2.Id,
            Subject__c = 'Standard Task',
            Priority__c = 'Normal',
            Type__c = 'Email',
            DaysFromStart__c = 1,
            Dependent__c = 'None',
            TaskIndex__c = 1
        );
        insert task2;

        // Create 50 accounts. 
        // 25 match 'Smith%'
        // 25 don't.
        List<Account> accounts = new List<Account>();
        for (Integer i = 0; i < 25; i++) {
            accounts.add(new Account(Name = 'Smith ' + i));
        }
        for (Integer i = 0; i < 25; i++) {
            accounts.add(new Account(Name = 'Jones ' + i));
        }
        
        Test.startTest();
        insert accounts;
        Test.stopTest();
        
        // Smith accounts (25) should get 'Smith Action Plan' via WHERE clause.
        // All accounts (50) should get 'Standard Plan' via direct matching (assuming the trigger logic applies it).
        // Wait, ActionPlanTriggerUtility applies ALL matching templates.
        
        // Template 1 (Smith): Target = Account, WHERE = Name LIKE 'Smith%'
        // Template 2 (Standard): Target = Account, No WHERE clause.
        
        // For each of 50 accounts:
        // - Template 2 matches (Target Object match).
        // For Template 1:
        // - TriggerUtility adds ONE bulk request with all 50 IDs.
        
        // Total expected Action Plans:
        // Template 1: 25 (only Smith accounts match WHERE clause)
        // Template 2: 50 (all accounts match Target Object)
        // Total = 75
        
        List<ActionPlan__c> smithPlans = [SELECT Id FROM ActionPlan__c WHERE Action_Plan_Template__r.Name = 'Smith Action Plan'];
        Assert.areEqual(25, smithPlans.size(), 'Should have 25 Smith Action Plans');
        
        List<ActionPlan__c> standardPlans = [SELECT Id FROM ActionPlan__c WHERE Action_Plan_Template__r.Name = 'Standard Plan'];
        Assert.areEqual(50, standardPlans.size(), 'Should have 50 Standard Plans');
    }
}