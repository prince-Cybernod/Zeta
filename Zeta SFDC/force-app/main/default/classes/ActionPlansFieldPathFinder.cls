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
 * Utility class for converting relationship field paths to SObjectField
 * @author {@link [David Schach](https://github.com/dschach)}
 * @date 2025-07-29
 * @group Utilities
 */
public with sharing class ActionPlansFieldPathFinder {
  public class IllegalStateException extends Exception {
  }

  /**
   * @param baseObject  Starting object API name (e.g. 'Contact')
   * @param path        Relationship path (e.g. 'Account.Owner.Username')
   * @return            Schema.SObjectField for the leaf (e.g. User.Username)
   */
  public static Schema.SObjectField resolveField(String baseObject, String path) {
    if (String.isBlank(baseObject) || String.isBlank(path)) {
      throw new IllegalArgumentException('Base object and path are required.');
    }

    Map<String, Schema.SObjectType> globals = Schema.getGlobalDescribe();
    if (!globals.containsKey(baseObject)) {
      throw new IllegalArgumentException('Unknown sObject: ' + baseObject);
    }

    Schema.DescribeSObjectResult describe = globals.get(baseObject).getDescribe();
    List<String> tokens = path.split('\\.');

    for (Integer i = 0; i < tokens.size(); i++) {
      String token = tokens[i].trim();
      Boolean isLast = (i == tokens.size() - 1);

      // --- 1. Try direct field name match (case-insensitive) ---------------
      Schema.SObjectField matchedField = null;
      for (String apiName : describe.fields.getMap().keySet()) {
        if (apiName.equalsIgnoreCase(token)) {
          matchedField = describe.fields.getMap().get(apiName);
          break;
        }
      }

      // --- 2. If not found, try relationship name on every lookup field ----
      if (matchedField == null) {
        for (Schema.SObjectField f : describe.fields.getMap().values()) {
          Schema.DescribeFieldResult fdr = f.getDescribe();
          if (fdr.getType() == Schema.DisplayType.REFERENCE) {
            String relName = fdr.getRelationshipName();
            if (relName != null && relName.equalsIgnoreCase(token)) {
              matchedField = f;
              break;
            }
          }
        }
      }

      // --- 3. Still not found? Allow 'Account' → 'AccountId' style fallback
      if (matchedField == null && !isLast) {
        String alt = token + 'Id';
        if (describe.fields.getMap().containsKey(alt)) {
          matchedField = describe.fields.getMap().get(alt);
        }
      }

      if (matchedField == null) {
        throw new IllegalArgumentException(
          'Cannot resolve "' + token + '" on ' + describe.getName());
      }

      // Leaf token → return the field
      if (isLast) {
        return matchedField;
      }

      // Otherwise follow the relationship to the next object
      Schema.DescribeFieldResult link = matchedField.getDescribe();
      if (link.getType() != Schema.DisplayType.REFERENCE) {
        throw new IllegalArgumentException(
          '"' + token + '" on ' + describe.getName() + ' is not a relationship field.');
      }
      describe = link.getReferenceTo()[0].getDescribe(); // choose first target
    }

    // Unreachable
    throw new IllegalStateException('Path processing fell through.');
  }

  public static String[] convertToSObjectFields(String baseObjectName, String[] fieldPaths) {
    // Handle null inputs
    if (baseObjectName == null || fieldPaths == null) {
      return fieldPaths;
    }

    // Handle empty inputs
    if (baseObjectName.trim() == '' || fieldPaths.isEmpty()) {
      return fieldPaths;
    }

    // For all other cases, convert each field path individually
    String[] result = new String[]{
    };

    for (String i : fieldPaths) {
      try {
        SObjectField s = ActionPlansFieldPathFinder.resolveField(baseObjectName, i);
        DescribeFieldResult d = s.getDescribe();
        result.add( d.getSObjectType() + '.' + d.getName() );
      } catch (IllegalArgumentException e) {
        // If there's an error resolving the field, return the original field path
        result.add(i);
      }
    }

    return result;
  }
}