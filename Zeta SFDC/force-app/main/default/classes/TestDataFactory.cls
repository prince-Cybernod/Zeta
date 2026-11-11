/**
 * Generic factory to create minimally valid test data for arbitrary SObjects.
 *
 * - Introspects required fields and populates them with reasonable defaults.
 * - Recursively creates required parent records for required lookups/M-D.
 * - Skips OwnerId to avoid mixed DML; running user will be owner.
 * - Handles picklists, unique/external ids, autonumber, calculated, and defaults.
 * - Allows override values and object-specific providers.
 * - Enhanced for subscriber org compatibility with namespace awareness.
 * - Includes comprehensive debugging for issue diagnosis.
 */
@IsTest
public class TestDataFactory {
  
  /**
   * Custom exception for TestDataFactory specific errors
   */
  public class TestDataFactoryException extends Exception {}
  
  // Enhanced debugging flag for subscriber org troubleshooting
  private static final Boolean DEBUG_ENABLED = true;
  
  // Subscriber org detection and namespace handling
  private static String managedPackageNamespace;
  private static Boolean isSubscriberOrg;
  
  static {
    detectOrgContext();
  }
  
  /**
   * Detects if running in subscriber org and identifies managed package namespace
   */
  private static void detectOrgContext() {
    try {
      // Try to detect managed package namespace by examining our own class
      String className = TestDataFactory.class.getName();
      if (className.contains('__')) {
        managedPackageNamespace = className.substringBefore('__');
        isSubscriberOrg = true;
        debugLog('Detected subscriber org with namespace: ' + managedPackageNamespace);
      } else {
        managedPackageNamespace = null;
        isSubscriberOrg = false;
        debugLog('Detected packaging/dev org (no namespace)');
      }
      
      // Additional detection via organization info
      Organization org = [SELECT IsSandbox, NamespacePrefix FROM Organization LIMIT 1];
      if (org.NamespacePrefix != null && managedPackageNamespace == null) {
        managedPackageNamespace = org.NamespacePrefix;
        isSubscriberOrg = false; // This is the packaging org
        debugLog('Detected packaging org with namespace: ' + managedPackageNamespace);
      }
      
    } catch (Exception e) {
      debugLog('Error detecting org context: ' + e.getMessage());
      isSubscriberOrg = false;
      managedPackageNamespace = null;
    }
  }
  
  /**
   * Enhanced debug logging for subscriber org troubleshooting
   */
  private static void debugLog(String message) {
    if (DEBUG_ENABLED) {
      System.debug(LoggingLevel.DEBUG, '[TestDataFactory] ' + message);
    }
  }
  
  /**
   * Enhanced debug logging with level control
   */
  private static void debugLog(LoggingLevel level, String message) {
    if (DEBUG_ENABLED) {
      System.debug(level, '[TestDataFactory] ' + message);
    }
  }

  public interface ObjectDefaultsProvider {
    SObject apply(SObject record);
  }

  private static final Map<String, ObjectDefaultsProvider> PROVIDERS =
    new Map<String, ObjectDefaultsProvider>();

  static {
    PROVIDERS.put('Opportunity', new OpportunityDefaults());
    PROVIDERS.put('Case', new CaseDefaults());
  }

  private class OpportunityDefaults implements ObjectDefaultsProvider {
    public SObject apply(SObject record) {
      if (record.get('Name') == null) {
        record.put('Name', 'Opp ' + String.valueOf(Crypto.getRandomInteger()));
      }
      if (record.get('StageName') == null) {
        record.put('StageName', 'Prospecting');
      }
      if (record.get('CloseDate') == null) {
        record.put('CloseDate', Date.today());
      }
      return record;
    }
  }

  private class CaseDefaults implements ObjectDefaultsProvider {
    public SObject apply(SObject record) {
      if (record.get('Origin') == null) {
        record.put('Origin', 'Phone');
      }
      if (record.get('Subject') == null) {
        record.put('Subject', 'Case ' + String.valueOf(Crypto.getRandomInteger()));
      }
      return record;
    }
  }

  public static SObject make(String apiName, Map<String, Object> overrides) {
    debugLog('make() called - apiName=' + apiName + 
      ', overridesKeys=' + (overrides == null ? 'null' : String.join(new List<String>(overrides.keySet()), ',')) +
      ', isSubscriberOrg=' + isSubscriberOrg +
      ', managedPackageNamespace=' + managedPackageNamespace);
    
    SObject sObj = build(apiName, overrides, new Set<String>());
    insert sObj;
    debugLog('make() completed - inserted ' + apiName + ' Id=' + sObj.Id);
    return sObj;
  }

  public static List<SObject> makeList(String apiName, Integer count,
    Map<String, Object> overrides) {
    debugLog('makeList() called - apiName=' + apiName + 
      ', count=' + count +
      ', overridesKeys=' + (overrides == null ? 'null' : String.join(new List<String>(overrides.keySet()), ',')) +
      ', isSubscriberOrg=' + isSubscriberOrg);
    
    List<SObject> listToInsert = new List<SObject>();
    for (Integer i = 0; i < count; i++) {
      listToInsert.add(build(apiName, overrides, new Set<String>()));
    }
    insert listToInsert;
    debugLog('makeList() completed - inserted ' + listToInsert.size() + ' records of ' + apiName);
    return listToInsert;
  }

  private static SObject build(String apiName, Map<String, Object> overrides,
    Set<String> lineage) {
    debugLog('build() enter - apiName=' + apiName + ', lineageDepth=' + lineage.size());
    
    if (lineage.contains(apiName)) {
      debugLog('build() - circular reference detected for ' + apiName + ', returning empty instance');
      return (SObject) Type.forName('Schema', apiName).newInstance();
    }
    lineage.add(apiName);

    // Enhanced schema describe with error handling for subscriber orgs
    Schema.SObjectType sobjType;
    Schema.DescribeSObjectResult d;
    
    try {
      Map<String, Schema.SObjectType> globalDescribe = Schema.getGlobalDescribe();
      debugLog('build() - Global describe contains ' + globalDescribe.size() + ' SObject types');
      
      sobjType = globalDescribe.get(apiName);
      if (sobjType == null) {
        debugLog(LoggingLevel.ERROR, 'build() - SObjectType not found for ' + apiName + 
          ' in global describe. Available types: ' + String.join(new List<String>(globalDescribe.keySet()), ', '));
        throw new TestDataFactoryException('SObjectType not found: ' + apiName);
      }
      
      d = sobjType.getDescribe();
      debugLog('build() - Successfully described ' + apiName + 
        ', isAccessible=' + d.isAccessible() + 
        ', isCreateable=' + d.isCreateable() +
        ', isCustom=' + d.isCustom() +
        ', namespace=' + (d.getName().contains('__') ? d.getName().substringBefore('__') : 'none'));
      
    } catch (Exception e) {
      debugLog(LoggingLevel.ERROR, 'build() - Error during schema describe for ' + apiName + ': ' + e.getMessage());
      throw new TestDataFactoryException('Failed to describe SObject ' + apiName + ': ' + e.getMessage());
    }

    SObject sObj = sobjType.newSObject();

    System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build enter apiName=' + apiName +
      ' lineageDepth=' + lineage.size() +
      ' overridesKeys=' + (overrides == null ? 'null' : String.join(new List<String>(overrides.keySet()), ',')));

    Integer skippedNotCreatableOrCalculated = 0;
    Integer skippedDefaultedOrAutonumber = 0;
    Integer skippedOwner = 0;
    Integer createdParents = 0;
    Integer setPicklists = 0;
    Integer setStandardNames = 0;
    Integer setByType = 0;
    List<String> setActions = new List<String>();

    Map<String, Schema.SObjectField> fields;
    try {
      fields = d.fields.getMap();
      debugLog('build() - Retrieved ' + fields.size() + ' fields for ' + apiName);
    } catch (Exception e) {
      debugLog(LoggingLevel.ERROR, 'build() - Error retrieving fields for ' + apiName + ': ' + e.getMessage());
      throw new TestDataFactoryException('Failed to retrieve fields for ' + apiName + ': ' + e.getMessage());
    }
    
    for (Schema.SObjectField fld : fields.values()) {
      Schema.DescribeFieldResult f;
      String fname;
      
      try {
        f = fld.getDescribe();
        fname = f.getName();
      } catch (Exception e) {
        debugLog(LoggingLevel.WARN, 'build() - Error describing field in ' + apiName + ': ' + e.getMessage());
        continue; // Skip this field if we can't describe it
      }

      // Enhanced accessibility checks for subscriber orgs
      Boolean isFieldAccessible = true;
      Boolean isFieldCreateable = true;
      
      try {
        isFieldAccessible = f.isAccessible();
        isFieldCreateable = f.isCreateable();
      } catch (Exception e) {
        debugLog(LoggingLevel.WARN, 'build() - Error checking accessibility for field ' + fname + ' in ' + apiName + ': ' + e.getMessage());
        // In subscriber orgs, assume field is not accessible if we can't check
        isFieldAccessible = false;
        isFieldCreateable = false;
      }

      if (!isFieldCreateable || f.isCalculated()) {
        skippedNotCreatableOrCalculated++;
        debugLog('build() - Skipped field ' + fname + ' (not createable or calculated)');
        continue;
      }
      
      if (!isFieldAccessible) {
        skippedNotCreatableOrCalculated++;
        debugLog('build() - Skipped field ' + fname + ' (not accessible in subscriber org)');
        continue;
      }
      
      if (f.isDefaultedOnCreate() || f.isAutoNumber()) {
        skippedDefaultedOrAutonumber++;
        debugLog('build() - Skipped field ' + fname + ' (defaulted or autonumber)');
        continue;
      }
      
      if (fname == 'OwnerId') {
        skippedOwner++;
        debugLog('build() - Skipped OwnerId field');
        continue;
      }

      // Enhanced nullability check for subscriber orgs
      Boolean isRequired = false;
      try {
        isRequired = !f.isNillable();
      } catch (Exception e) {
        debugLog(LoggingLevel.WARN, 'build() - Error checking nullability for field ' + fname + ': ' + e.getMessage());
        // In subscriber orgs, be conservative and assume field is required if we can't check
        isRequired = true;
      }

      if (isRequired && sObj.get(fname) == null) {
        debugLog('build() - Processing required field: ' + fname + ' (type: ' + f.getType() + ')');
        
        try {
          if (f.getType() == Schema.DisplayType.REFERENCE) {
          List<Schema.SObjectType> rt = f.getReferenceTo();
          if (!rt.isEmpty()) {
            String parentApi = rt[0].getDescribe().getName();
            if (fname == 'WhoId' || fname == 'WhatId') {
              continue;
            }
            SObject parent = build(parentApi, new Map<String, Object>(), lineage);
            insert parent;
            createdParents++;
            System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build created parent for ' + apiName +
              '.' + fname + ' -> ' + parent.getSObjectType().getDescribe().getName() + ' Id=' + parent.Id);
            sObj.put(fname, parent.Id);
            setActions.add(fname + '=parent(' + parent.getSObjectType().getDescribe().getName() + ')');
          }
          continue;
        }

        if (f.getType() == Schema.DisplayType.PICKLIST) {
          List<Schema.PicklistEntry> vals = f.getPicklistValues();
          if (!vals.isEmpty()) {
            sObj.put(fname, vals[0].getValue());
            setPicklists++;
            System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build picklist set ' + apiName + '.' + fname + ' -> ' + vals[0].getValue());
          } else {
            sObj.put(fname, 'Default');
            setPicklists++;
            System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build picklist set ' + apiName + '.' + fname + ' -> Default');
          }
          continue;
        }

        if (fname == 'Name' && !f.isAutoNumber()) {
          sObj.put('Name', apiName + ' ' + String.valueOf(Crypto.getRandomInteger()));
          setStandardNames++;
          System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Name for ' + apiName);
          continue;
        }
        if (fname == 'LastName') {
          sObj.put('LastName', 'Test ' + String.valueOf(Crypto.getRandomInteger()));
          setStandardNames++;
          System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set LastName for ' + apiName);
          continue;
        }
        if (fname == 'FirstName') {
          sObj.put('FirstName', 'Test');
          setStandardNames++;
          System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set FirstName for ' + apiName);
          continue;
        }
        if (apiName == 'Task' && fname == 'Subject') {
          sObj.put('Subject', 'Task ' + String.valueOf(Crypto.getRandomInteger()));
          setStandardNames++;
          System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Task.Subject');
          continue;
        }
        if (apiName == 'Event' && fname == 'Subject') {
          sObj.put('Subject', 'Event ' + String.valueOf(Crypto.getRandomInteger()));
          setStandardNames++;
          System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Event.Subject');
          continue;
        }

        switch on f.getType() {
          when STRING {
            sObj.put(fname, fname + ' ' + String.valueOf(Crypto.getRandomInteger())); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set String for ' + apiName + '.' + fname);
          }
          when INTEGER {
            sObj.put(fname, 1); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Integer for ' + apiName + '.' + fname);
          }
          when LONG {
            sObj.put(fname, 1L); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Long for ' + apiName + '.' + fname);
          }
          when DOUBLE {
            sObj.put(fname, 1.0); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Double for ' + apiName + '.' + fname);
          }
          when CURRENCY {
            sObj.put(fname, 1); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Currency for ' + apiName + '.' + fname);
          }
          when PERCENT {
            sObj.put(fname, 1.0); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Percent for ' + apiName + '.' + fname);
          }
          when DATE {
            sObj.put(fname, Date.today()); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Date for ' + apiName + '.' + fname);
          }
          when DATETIME {
            sObj.put(fname, System.now()); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set DateTime for ' + apiName + '.' + fname);
          }
          when TIME {
            sObj.put(fname, Time.newInstance(0, 0, 0, 0)); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Time for ' + apiName + '.' + fname);
          }
          when BOOLEAN {
            sObj.put(fname, false); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Boolean for ' + apiName + '.' + fname);
          }
          when EMAIL {
            sObj.put(fname, 'test+' + String.valueOf(Crypto.getRandomInteger()) + '@example.com'); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Email for ' + apiName + '.' + fname);
          }
          when PHONE {
            sObj.put(fname, '555000' + Math.mod(Crypto.getRandomInteger(), 10000)); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Phone for ' + apiName + '.' + fname);
          }
          when URL {
            sObj.put(fname, 'https://example.com/' + String.valueOf(Crypto.getRandomInteger())); setByType++; System.debug(LoggingLevel.DEBUG, 'TestDataFactory.build set Url for ' + apiName + '.' + fname);
          }
          when ID {
          }
          when else {
            debugLog(LoggingLevel.WARN, 'build() - Unhandled field type ' + f.getType() + ' for field ' + fname);
          }
        }
        } catch (Exception e) {
          debugLog(LoggingLevel.WARN, 'build() - Error processing required field ' + fname + ' in ' + apiName + ': ' + e.getMessage());
          // Continue processing other fields even if one fails
        }
      }
    }

    // Apply object-specific providers with error handling
    ObjectDefaultsProvider provider = PROVIDERS.get(apiName);
    if (provider != null) {
      try {
        sObj = provider.apply(sObj);
        debugLog('build() - Applied provider for ' + apiName);
      } catch (Exception e) {
        debugLog(LoggingLevel.WARN, 'build() - Error applying provider for ' + apiName + ': ' + e.getMessage());
      }
    }

    // Apply overrides with error handling
    if (overrides != null) {
      try {
        for (String key : overrides.keySet()) {
          sObj.put(key, overrides.get(key));
        }
        debugLog('build() - Applied overrides for ' + apiName + 
          ' keys=' + String.join(new List<String>(overrides.keySet()), ','));
      } catch (Exception e) {
        debugLog(LoggingLevel.WARN, 'build() - Error applying overrides for ' + apiName + ': ' + e.getMessage());
      }
    }

    // Enhanced summary with subscriber org context
    Map<String, Object> populatedFields;
    try {
      populatedFields = sObj.getPopulatedFieldsAsMap();
    } catch (Exception e) {
      debugLog(LoggingLevel.WARN, 'build() - Error getting populated fields: ' + e.getMessage());
      populatedFields = new Map<String, Object>();
    }
    
    debugLog('build() - SUMMARY for ' + apiName + ':' +
      '\n  - isSubscriberOrg: ' + isSubscriberOrg +
      '\n  - managedPackageNamespace: ' + managedPackageNamespace +
      '\n  - lineageDepth: ' + lineage.size() +
      '\n  - totalFields: ' + fields.size() +
      '\n  - skippedNotCreatableOrCalculated: ' + skippedNotCreatableOrCalculated +
      '\n  - skippedDefaultedOrAutonumber: ' + skippedDefaultedOrAutonumber +
      '\n  - skippedOwner: ' + skippedOwner +
      '\n  - createdParents: ' + createdParents +
      '\n  - setPicklists: ' + setPicklists +
      '\n  - setStandardNames: ' + setStandardNames +
      '\n  - setByType: ' + setByType +
      '\n  - populatedFieldsCount: ' + populatedFields.size() +
      '\n  - populatedFields: ' + String.join(new List<String>(populatedFields.keySet()), ', '));
    
    return sObj;
  }
}