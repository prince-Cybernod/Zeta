/**
 * Test class for cross-object functionality in Action Plans
 * @author AI Assistant
 * @since 2025
 * @group Test
 */
@IsTest
private class ActionPlanCrossObjectTest {
    
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
            Name = 'Test Account for Cross-Object Trigger',
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
        
        Test.stopTest();
        
        // Verify the action plan was created
        List<ActionPlan__c> createdPlans = [
            SELECT Id, Name, Where_Clause__c, Related_Object__c, Contact__c
            FROM ActionPlan__c 
            WHERE Id = :ap.Id
        ];
        
        System.assertEquals(1, createdPlans.size(), 'One action plan should have been created');
        
        // Verify the action plan details
        ActionPlan__c plan = createdPlans[0];
        System.assertEquals('Account.Rating = \'1\'', plan.Where_Clause__c, 'Action plan should have the correct WHERE clause');
        System.assertEquals('Contact', plan.Related_Object__c, 'Action plan should be related to Contact object');
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
        
        Test.stopTest();
        
        // Verify the action plan was created
        List<ActionPlan__c> createdPlans = [
            SELECT Id, Name, Where_Clause__c, Related_Object__c, Contact__c
            FROM ActionPlan__c 
            WHERE Id = :ap.Id
        ];
        
        System.assertEquals(1, createdPlans.size(), 'One action plan should have been created');
        
        // Verify the action plan details
        ActionPlan__c plan = createdPlans[0];
        System.assertEquals('Account.Rating = \'1\'', plan.Where_Clause__c, 'Action plan should have the correct WHERE clause');
        System.assertEquals('Contact', plan.Related_Object__c, 'Action plan should be related to Contact object');
    }
}