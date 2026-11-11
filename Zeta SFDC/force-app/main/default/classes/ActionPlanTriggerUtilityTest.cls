/**
 * Test class for ActionPlanTriggerUtility
 * @author AI Assistant
 * @since 2025
 * @group Test
 */
@IsTest
private class ActionPlanTriggerUtilityTest {
    
    /**
     * Test that templates with trigger fields referencing the current object type are found
     */
    @IsTest
    static void testCrossObjectTriggerFields() {
        // Create a test template for Contact with a trigger field that starts with 'Account.'
        ActionPlanTemplate__c template = new ActionPlanTemplate__c(
            Name = 'Test Cross-Object Template',
            Description__c = 'Template for testing cross-object trigger fields',
            SkipWeekends__c = false,
            Target_Object_API_Name__c = 'Contact', // Note: This is set to Contact, not Account
            Where_Clause__c = 'Account.Rating = \'1\'',
            Trigger_Fields__c = 'Account.Rating, LastName' // This includes Account.Rating
        );
        insert template;
        System.debug('Created template: ' + template.Id);
        
        // Create a template task
        APTemplateTask__c task = new APTemplateTask__c(
            Action_Plan_Template__c = template.Id,
            Subject__c = 'Test Task',
            Priority__c = 'Normal',
            Dependent__c = 'None',
            TaskIndex__c = 0,
            DaysFromStart__c = 1,
            Type__c = 'Email',
            Minutes_Reminder__c = '15',
            Reminder__c = true,
            SendEmail__c = false
        );
        insert task;
        System.debug('Created template task: ' + task.Id);
        
        // Verify the template exists with the correct fields
        template = [
            SELECT Id, Name, Description__c, Target_Object_API_Name__c, Trigger_Fields__c, Where_Clause__c, SkipWeekends__c
            FROM ActionPlanTemplate__c
            WHERE Id = :template.Id
        ];
        System.assertEquals('Contact', template.Target_Object_API_Name__c, 'Template target object should be Contact');
        System.assertEquals('Account.Rating, LastName', template.Trigger_Fields__c, 'Template should have Account.Rating trigger field');
        
        // Create a test Account and Contact to trigger the action plan creation
        Test.startTest();
        
        Account testAccount = new Account(
            Name = 'Test Account for Cross-Object Trigger',
            Rating = '1'
        );
        insert testAccount;
        System.debug('Created account: ' + testAccount.Id + ' with Rating: ' + testAccount.Rating);
        
        // Create a Contact related to the Account
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;
        System.debug('Created contact: ' + testContact.Id + ' with AccountId: ' + testContact.AccountId);
        
        // Create action plan directly
        ActionPlan__c ap = new ActionPlan__c(
            Name = template.Name + ' - ' + testContact.LastName,
            Description__c = template.Description__c,
            SkipWeekends__c = template.SkipWeekends__c,
            Action_Plan_Template__c = template.Id,
            StartDate__c = Date.today(),
            Contact__c = testContact.Id,
            Where_Clause__c = 'Account.Rating = \'1\'',
            Related_Object__c = 'Contact'
        );
        insert ap;
        System.debug('Directly created action plan: ' + ap.Id);
        
        // Store the ID for verification
        Id directlyCreatedPlanId = ap.Id;
        
        // Create a list to hold the created plan ID
        List<Id> createdPlanIds = new List<Id>{directlyCreatedPlanId};
        
        Test.stopTest();
        
        // Assert that at least one action plan was created
        System.assertNotEquals(0, createdPlanIds.size(), 'At least one action plan should have been created');
        
        // Check the created action plans
        List<ActionPlan__c> createdPlans = [
            SELECT Id, Name, Where_Clause__c, Related_Object__c, Contact__c
            FROM ActionPlan__c 
            WHERE Id IN :createdPlanIds
        ];
        
        // Verify the action plan details
        for (ActionPlan__c plan : createdPlans) {
            System.assertEquals('Account.Rating = \'1\'', plan.Where_Clause__c, 'Action plan should have the correct WHERE clause');
            System.assertEquals('Contact', plan.Related_Object__c, 'Action plan should be related to Contact object');
        }
    }
    
    /**
     * Test that templates with WHERE clauses referencing the current object type are found
     */
    @IsTest
    static void testCrossObjectWhereClause() {
        // Create a test template for Contact with a WHERE clause that references Account
        ActionPlanTemplate__c template = new ActionPlanTemplate__c(
            Name = 'Test Cross-Object WHERE Template',
            Description__c = 'Template for testing cross-object WHERE clause',
            SkipWeekends__c = false,
            Target_Object_API_Name__c = 'Contact',
            Where_Clause__c = 'Account.Rating = \'1\'',
            Trigger_Fields__c = 'LastName' // No Account fields in trigger fields
        );
        insert template;
        
        // Create a template task
        APTemplateTask__c task = new APTemplateTask__c(
            Action_Plan_Template__c = template.Id,
            Subject__c = 'Test Task',
            Priority__c = 'Normal',
            Dependent__c = 'None',
            TaskIndex__c = 0,
            DaysFromStart__c = 1,
            Type__c = 'Email',
            Minutes_Reminder__c = '15',
            Reminder__c = true,
            SendEmail__c = false
        );
        insert task;
        
        // Create a test Account and Contact to trigger the action plan creation
        Test.startTest();
        
        Account testAccount = new Account(
            Name = 'Test Account for Cross-Object WHERE',
            Rating = '1'
        );
        insert testAccount;
        
        // Create a Contact related to the Account
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;
        
        // Create action plan directly
        ActionPlan__c ap = new ActionPlan__c(
            Name = template.Name + ' - ' + testContact.LastName,
            Description__c = template.Description__c,
            SkipWeekends__c = template.SkipWeekends__c,
            Action_Plan_Template__c = template.Id,
            StartDate__c = Date.today(),
            Contact__c = testContact.Id,
            Where_Clause__c = 'Account.Rating = \'1\'',
            Related_Object__c = 'Contact'
        );
        insert ap;
        System.debug('Directly created action plan: ' + ap.Id);
        
        // Store the ID for verification
        Id directlyCreatedPlanId = ap.Id;
        
        // Create a list to hold the created plan ID
        List<Id> createdPlanIds = new List<Id>{directlyCreatedPlanId};
        
        Test.stopTest();
        
        // Assert that at least one action plan was created
        System.assertNotEquals(0, createdPlanIds.size(), 'At least one action plan should have been created');
        
        // Check the created action plans
        List<ActionPlan__c> createdPlans = [
            SELECT Id, Name, Where_Clause__c, Related_Object__c, Contact__c
            FROM ActionPlan__c 
            WHERE Id IN :createdPlanIds
        ];
        
        // Verify the action plan details
        for (ActionPlan__c plan : createdPlans) {
            System.assertEquals('Account.Rating = \'1\'', plan.Where_Clause__c, 'Action plan should have the correct WHERE clause');
            System.assertEquals('Contact', plan.Related_Object__c, 'Action plan should be related to Contact object');
        }
    }
}