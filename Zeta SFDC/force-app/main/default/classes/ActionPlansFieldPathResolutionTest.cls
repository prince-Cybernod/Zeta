/**
 * Test class for verifying field path resolution in ActionPlansBuilderUtilities
 * @author AI Assistant
 * @since 2025
 * @group Test
 */
@IsTest
private class ActionPlansFieldPathResolutionTest {
    
    /**
     * Test that the resolveFieldPathForDueDate method can correctly resolve relationship fields
     * Specifically tests the Account.CreatedDate field path on a Contact record
     */
    @IsTest
    static void testResolveRelationshipFieldPath() {
        // Create test data
    
        // Create an Account
        Account testAccount = new Account(
            Name = 'Test Account for Field Path Resolution'
        );
        insert testAccount;
    
        // Get the account's CreatedDate
        testAccount = [SELECT CreatedDate FROM Account WHERE Id = :testAccount.Id LIMIT 1];
        Date accountCreatedDate = testAccount.CreatedDate.date();
    
        // Create a Contact related to the Account
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            AccountId = testAccount.Id
        );
        insert testContact;
    
        // Test the field path resolution
        Test.startTest();
    
        // Call the method we fixed
        Date resolvedDate = ActionPlansBuilderUtilities.resolveFieldPathForDueDate(
            'Contact', 
            testContact.Id, 
            'Account.CreatedDate'
        );
    
        Test.stopTest();
    
        // Verify the result
        System.assertNotEquals(null, resolvedDate, 'The resolved date should not be null');
        System.assertEquals(accountCreatedDate, resolvedDate, 'The resolved date should match the Account\'s CreatedDate');
    
        // Test with a non-existent field to ensure error handling works
        Date nullDate = ActionPlansBuilderUtilities.resolveFieldPathForDueDate(
            'Contact', 
            testContact.Id, 
            'Account.NonExistentField__c'
        );
        System.assertEquals(null, nullDate, 'The result should be null for a non-existent field');
    }
    
    /**
     * Test that the resolveFieldPathForDueDate method can correctly resolve direct fields
     */
    @IsTest
    static void testResolveDirectFieldPath() {
        // Create a Contact with a date field
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Contact',
            Birthdate = Date.today().addYears(-30)
        );
        insert testContact;
        
        // Test the field path resolution
        Test.startTest();
        
        // Call the method with a direct field
        Date resolvedDate = ActionPlansBuilderUtilities.resolveFieldPathForDueDate(
            'Contact', 
            testContact.Id, 
            'Birthdate'
        );
        
        Test.stopTest();
        
        // Verify the result
        System.assertNotEquals(null, resolvedDate, 'The resolved date should not be null');
        System.assertEquals(testContact.Birthdate, resolvedDate, 'The resolved date should match the Contact\'s Birthdate');
    }
    
    /**
     * Test the integration with ActionPlanCreateInvocable to ensure the fix works in the actual usage context
     */
    @IsTest
    static void testIntegrationWithActionPlanCreation() {
        // Create test data
    
        // Create an Account
        Account testAccount = new Account(
            Name = 'Test Account for Integration'
        );
        insert testAccount;
    
        // Get the account's CreatedDate
        testAccount = [SELECT CreatedDate FROM Account WHERE Id = :testAccount.Id LIMIT 1];
        Date accountCreatedDate = testAccount.CreatedDate.date();
    
        // Create a Contact related to the Account
        Contact testContact = new Contact(
            FirstName = 'Test',
            LastName = 'Integration',
            AccountId = testAccount.Id
        );
        insert testContact;
    
        // Create a template with a task that uses the relationship field for due date
        ActionPlanTemplate__c template = new ActionPlanTemplate__c(
            Name = 'Test Field Path Template',
            Description__c = 'Template for testing field path resolution',
            SkipWeekends__c = false
        );
        insert template;
    
        // Create a template task with DueDateType__c = 'DateField' and DueDateRelatedField__c = 'Account.CreatedDate'
        APTemplateTask__c task = new APTemplateTask__c(
            Action_Plan_Template__c = template.Id,
            Subject__c = 'Test Field Path Task',
            Priority__c = 'Normal',
            Dependent__c = 'None',
            TaskIndex__c = 0,
            DaysFromStart__c = 0, // No additional days
            Type__c = 'Email',
            Minutes_Reminder__c = '15',
            Reminder__c = true,
            SendEmail__c = false,
            DueDateType__c = 'DateField',
            DueDateRelatedField__c = 'Account.CreatedDate'
        );
        insert task;
    
        // Create an action plan request
        Test.startTest();
    
        List<ActionPlanCreateInvocable.CreateActionPlanRequest> requests = new List<ActionPlanCreateInvocable.CreateActionPlanRequest>();
        ActionPlanCreateInvocable.CreateActionPlanRequest req = new ActionPlanCreateInvocable.CreateActionPlanRequest();
        req.templateNameOrID = template.Id;
        req.relatedRecordID = testContact.Id;
        req.daysToActionPlanStart = 0;
        requests.add(req);
    
        // Call the method that uses our fixed code
        List<Id> createdPlanIds = ActionPlanCreateInvocable.makeActionPlanFromTemplate(requests);
    
        Test.stopTest();
    
        // Verify the result
        System.assertNotEquals(0, createdPlanIds.size(), 'At least one action plan should have been created');
    
        // Query the created action plan tasks to verify the due date was set correctly
        List<APTask__c> createdTasks = [
            SELECT Id, Subject__c, ActivityDate__c
            FROM APTask__c
            WHERE Action_Plan__c IN :createdPlanIds
        ];
    
        System.assertNotEquals(0, createdTasks.size(), 'At least one task should have been created');
    
        // The due date should match the Account's CreatedDate
        for (APTask__c createdTask : createdTasks) {
            System.assertEquals(accountCreatedDate, createdTask.ActivityDate__c, 
                               'The task due date should match the Account\'s CreatedDate');
        }
    }
}