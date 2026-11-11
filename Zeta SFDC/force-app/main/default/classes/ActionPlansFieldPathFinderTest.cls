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
 * Test class for APFieldPathFinder
 * @author {@link [David Schach](https://github.com/dschach)}
 * @date 2025-07-29
 * @group Test
 */
@IsTest
private class ActionPlansFieldPathFinderTest {
    
    /**
     * Test converting a single field path to SObjectField
     */
    @IsTest
    static void testConvertToSObjectField() {
        // Test with Contact.Account.Owner.Username
        String[] result = ActionPlansFieldPathFinder.convertToSObjectFields('Contact', new String[]{'Account.Owner.Username'});
        System.assertEquals('User.Username', result[0], 'Should convert to User.Username');
        
        // Test with Account.Owner.Profile.Name
        result = ActionPlansFieldPathFinder.convertToSObjectFields('Account', new String[]{'Owner.Profile.Name'});
        System.assertEquals('Profile.Name', result[0], 'Should convert to Profile.Name');
        
        // Test with a direct field (no relationships)
        result = ActionPlansFieldPathFinder.convertToSObjectFields('Contact', new String[]{'LastName'});
        System.assertEquals('Contact.LastName', result[0], 'Should convert to Contact.LastName');
        
        // Test with invalid base object
        result = ActionPlansFieldPathFinder.convertToSObjectFields('InvalidObject', new String[]{'Name'});
        System.assertEquals('Name', result[0], 'Should return original for invalid base object');
        
        // Test with invalid field path
        result = ActionPlansFieldPathFinder.convertToSObjectFields('Contact', new String[]{'InvalidField'});
        System.assertEquals('InvalidField', result[0], 'Should return original for invalid field path');
        
        // Test with null inputs
        result = ActionPlansFieldPathFinder.convertToSObjectFields(null, new String[]{'Name'});
        System.assertEquals('Name', result[0], 'Should return original for null base object');
        
        result = ActionPlansFieldPathFinder.convertToSObjectFields('Contact', null);
        System.assertEquals(null, result, 'Should return null for null field path');
        
        result = ActionPlansFieldPathFinder.convertToSObjectFields(null, null);
        System.assertEquals(null, result, 'Should return null for null inputs');
        
        // Test with empty inputs
        result = ActionPlansFieldPathFinder.convertToSObjectFields('', new String[]{'Name'});
        System.assertEquals('Name', result[0], 'Should return original for empty base object');
        
        result = ActionPlansFieldPathFinder.convertToSObjectFields('Contact', new String[]{''});
        System.assertEquals('', result[0], 'Should return empty string for empty field path');
    }
    
    /**
     * Test converting multiple field paths to SObjectFields
     */
//    @isTest
//    static void testConvertToSObjectFields() {
//        // Test with multiple valid paths
//        String result = APFieldPathFinder.convertToSObjectFields(
//            'Contact',
//            'Account.Owner.Username, LastName, Account.Name'
//        );
//
//        // The result should contain the converted paths
//        System.assert(result.contains('User.Username'), 'Should contain User.Username');
//        System.assert(result.contains('Contact.LastName'), 'Should contain Contact.LastName');
//        System.assert(result.contains('Account.Name'), 'Should contain Account.Name');
//
//        // Test with some invalid paths
//        result = APFieldPathFinder.convertToSObjectFields(
//            'Contact',
//            'Account.Owner.Username, InvalidField, Account.Name'
//        );
//
//        // The result should contain the converted valid paths and the original invalid path
//        System.assert(result.contains('User.Username'), 'Should contain User.Username');
//        System.assert(result.contains('InvalidField'), 'Should contain the original invalid field');
//        System.assert(result.contains('Account.Name'), 'Should contain Account.Name');
//
//        // Test with null inputs
//        result = APFieldPathFinder.convertToSObjectFields(null, 'Name');
//        System.assertEquals('Name', result[0], 'Should return original for null base object');
//
//        String[] nullish;
//        String[] results = APFieldPathFinder.convertToSObjectFields('Contact', nullish);
//        System.assertEquals(null, results, 'Should return null for null field paths');
//
//        // Test with empty inputs
//        result = APFieldPathFinder.convertToSObjectFields('', 'Name');
//        System.assertEquals('Name', result[0], 'Should return original for empty base object');
//
//        result = APFieldPathFinder.convertToSObjectFields('Contact', '');
//        System.assertEquals('', result[0], 'Should return empty string for empty field paths');
//    }

    /**
     * Test case sensitivity handling
     */
//    @isTest
//    static void testCaseSensitivity() {
//        // Test with mixed case in field names
//        String result = APFieldPathFinder.convertToSObjectFields('Contact', 'account.owner.username');
//        System.assertEquals('User.Username', result[0], 'Should handle lowercase field names');
//
//        result = APFieldPathFinder.convertToSObjectFields('contact', 'ACCOUNT.OWNER.USERNAME');
//        System.assertEquals('User.Username', result[0], 'Should handle uppercase field names');
//
//        result = APFieldPathFinder.convertToSObjectFields('Contact', 'aCcOuNt.oWnEr.UsErNaMe');
//        System.assertEquals('User.Username', result[0], 'Should handle mixed case field names');
//    }
}