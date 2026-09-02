/**
 * Implementation of {@link DatabaseRepo} in system mode.
 *
 * Each of the methods supply the specific access level to avoid this PMD finding:
 * https://docs.pmd-code.org/pmd-doc-7.16.0/pmd_rules_apex_security.html#apexcrudviolation
 */
@SuppressWarnings('PMD.CognitiveComplexity')
public without sharing class SystemModeDatabaseRepo implements DatabaseRepo {
  @TestVisible
  private static Boolean hasExecutedBatch = false;

  public Savepoint setSavepoint() {
    return Database.setSavepoint();
  }

  public void rollback(Savepoint savepoint) {
    Database.rollback(savepoint);
  }

  public void insertSObjects(List<SObject> sobjects) {
    Database.insert(sobjects, AccessLevel.SYSTEM_MODE);
  }

  public void updateSObjects(List<SObject> sobjects) {
    Database.update(sobjects, AccessLevel.SYSTEM_MODE);
  }

  public void upsertSObjects(List<SObject> sobjects, SObjectField field) {
    Database.upsert(sobjects, field, AccessLevel.SYSTEM_MODE);
  }

  public void deleteSObjects(List<SObject> sobjects) {
    Database.delete(sobjects, AccessLevel.SYSTEM_MODE);
  }

  public void undeleteSObjects(List<SObject> sobjects) {
    Database.undelete(sobjects, AccessLevel.SYSTEM_MODE);
  }

  public List<SObject> query(String query) {
    return Database.query(query, AccessLevel.SYSTEM_MODE);
  }

  public List<SObject> queryWithBinds(String query, Map<String, Object> bindMap) {
    return Database.queryWithBinds(query, bindMap, AccessLevel.SYSTEM_MODE);
  }

  public Integer countQuery(String query) {
    return Database.countQuery(query, AccessLevel.SYSTEM_MODE);
  }

  public Integer countQueryWithBinds(String query, Map<String, Object> bindMap) {
    return Database.countQueryWithBinds(query, bindMap, AccessLevel.SYSTEM_MODE);
  }

  public Database.QueryLocator getQueryLocator(String query) {
    return Database.getQueryLocator(query, AccessLevel.SYSTEM_MODE);
  }

  public Database.QueryLocator getQueryLocatorWithBinds(String query, Map<String, Object> bindMap) {
    return Database.getQueryLocatorWithBinds(query, bindMap, AccessLevel.SYSTEM_MODE);
  }

  public List<Database.SaveResult> insertImmediate(List<SObject> sobjects) {
    return Database.insertImmediate(sobjects, AccessLevel.SYSTEM_MODE);
  }

  public Id executeBatch(Database.Batchable<SObject> batchable) {
    if (Test.isRunningTest()) {
      hasExecutedBatch = true;
      return null;
    }
    return Database.executeBatch(batchable);
  }

  public Id executeBatch(Database.Batchable<SObject> batchable, Integer scope) {
    if (Test.isRunningTest()) {
      hasExecutedBatch = true;
      return null;
    }
    return Database.executeBatch(batchable, scope);
  }
}