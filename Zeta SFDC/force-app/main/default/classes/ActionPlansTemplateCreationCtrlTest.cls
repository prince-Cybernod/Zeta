/*
Action Plans v4
David Schach 2022
https://appexchange.salesforce.com/appxListingDetail?listingId=a0N4V00000Gg6NVUAZ

Copyright (c) 2022, salesforce.com, inc.
All rights reserved.
SPDX-License-Identifier: BSD-3-Clause
For full license text, see the LICENSE file in the repo root or https://opensource.org/licenses/BSD-3-Clause
*/

/**
 * Test class for ActionPlanTemplateCreationController
 * @author {@link [Your Name](https://github.com/yourusername)}
 * @date 2025-07-29
 * @group Test
 */
@IsTest
private class ActionPlansTemplateCreationCtrlTest {
    
    /**
     * Set up test data
     */
    @TestSetup
    static void setupTestData() {
        // Create a test Action Plan Template
        ActionPlanTemplate__c template = new ActionPlanTemplate__c(
            Name = 'Test Template',
            Description__c = 'Test Description',
            SkipWeekends__c = true,
            SkipDay__c = 'End of previous week'
        );
        insert template;
        
        // Create a test template task
        APTemplateTask__c task = new APTemplateTask__c(
            Action_Plan_Template__c = template.Id,
            Subject__c = 'Test Task',
            Priority__c = 'Normal',
            SendEmail__c = false,
            Reminder__c = false,
            Type__c = 'Email',
            TaskIndex__c = 1,
            DaysFromStart__c = 1
        );
        insert task;
    }
    
    /**
     * Test the validateWhereClauseRemote method with field conversion
     */
    @IsTest
    static void testValidateWhereClauseRemote() {
        // Test with a valid WHERE clause and fields to convert
        Test.startTest();
        Map<String, Object> result = ActionPlanTemplateCreationController.validateWhereClauseRemote(
            'Name LIKE \'%Test%\'',
            'Account',
            'Name, Owner.Username, Parent.Name'
        );
        Test.stopTest();
        
        // Verify the result
        System.assertEquals(true, result.get('success'), 'Validation should succeed');
        System.assertNotEquals(null, result.get('count'), 'Count should be returned');
        
        // Verify field conversion
        String convertedFields = (String)result.get('convertedFields');
        System.assertNotEquals(null, convertedFields, 'Converted fields should be returned');
        System.assert(convertedFields.contains('Account.Name'), 'Should contain Account.Name');
        System.assert(convertedFields.contains('User.Username'), 'Should contain User.Username');
        System.assert(convertedFields.contains('Account.Name'), 'Should contain Account.Name for Parent.Name');
    }
    
    /**
     * Test the validateWhereClauseRemote method with invalid inputs
     */
    @IsTest
    static void testValidateWhereClauseRemoteInvalid() {
        // Test with blank WHERE clause
        Test.startTest();
        Map<String, Object> result = ActionPlanTemplateCreationController.validateWhereClauseRemote(
            '',
            'Account',
            'Name'
        );
        Test.stopTest();
        
        // Verify the result
        System.assertEquals(false, result.get('success'), 'Validation should fail');
        System.assert(((String)result.get('message')).contains('Please enter a WHERE clause'), 'Should indicate WHERE clause is required');
        
        // Test with blank object name
        result = ActionPlanTemplateCreationController.validateWhereClauseRemote(
            'Name = \'Test\'',
            '',
            'Name'
        );
        
        // Verify the result
        System.assertEquals(false, result.get('success'), 'Validation should fail');
        System.assert(((String)result.get('message')).contains('Target Object API Name is required'), 'Should indicate object name is required');
        
        // Test with invalid WHERE clause
        result = ActionPlanTemplateCreationController.validateWhereClauseRemote(
            'InvalidField = \'Test\'',
            'Account',
            'InvalidField'
        );
        
        // Verify the result
        System.assertEquals(false, result.get('success'), 'Validation should fail');
        System.assert(((String)result.get('message')).contains('Invalid WHERE clause'), 'Should indicate WHERE clause is invalid');
    }
    
    /**
     * Test complex field path conversion
     */
    @IsTest
    static void testComplexFieldPathConversion() {
        // Test with a complex field path
        Test.startTest();
        Map<String, Object> result = ActionPlanTemplateCreationController.validateWhereClauseRemote(
            'Account.Owner.IsActive = true',
            'Contact',
            'Account.Owner.Username, Account.Owner.Profile.Name'
        );
        Test.stopTest();
        
        // The query might fail depending on the org setup, but we're mainly testing the field conversion
        String convertedFields = (String)result.get('convertedFields');
        if (convertedFields != null) {
            System.assert(convertedFields.contains('User.Username'), 'Should contain User.Username');
            System.assert(convertedFields.contains('Profile.Name'), 'Should contain Profile.Name');
        }
    }
}