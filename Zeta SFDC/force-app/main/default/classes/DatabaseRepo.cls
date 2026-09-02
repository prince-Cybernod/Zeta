/**
 * Repository class that handles common Database operations.
 */
public interface DatabaseRepo {
  /**
   * Sets a savepoint for the current transaction and returns it.
   */
  Savepoint setSavepoint();

  /**
   * Rolls back the current transaction to the given savepoint.
   */
  void rollback(Savepoint savepoint);

  /**
   * Inserts the given list of SObjects.
   */
  void insertSObjects(List<SObject> sobjects);

  /**
   * Updates the given list of SObjects.
   */
  void updateSObjects(List<SObject> sobjects);

  /**
   * Upserts the given list of SObjects.
   */
  void upsertSObjects(List<SObject> sobjects, SObjectField field);

  /**
   * Deletes the given list of SObjects.
   */
  void deleteSObjects(List<SObject> sobjects);

  /**
   * Undeletes the given list of SObjects.
   */
  void undeleteSObjects(List<SObject> sobjects);

  /**
   * Executes a SOQL query and returns the results.
   */
  List<SObject> query(String query);

  /**
   * Executes a SOQL query with bind variables and returns the results.
   */
  List<SObject> queryWithBinds(String query, Map<String, Object> bindMap);

  /**
   * Executes a SOQL COUNT query and returns the count.
   */
  Integer countQuery(String query);

  /**
   * Executes a SOQL COUNT query with bind variables and returns the count.
   */
  Integer countQueryWithBinds(String query, Map<String, Object> bindMap);

  /**
   * Returns a QueryLocator for the given SOQL query string.
   */
  Database.QueryLocator getQueryLocator(String query);

  /**
   * Returns a QueryLocator for the given SOQL query with bind variables.
   */
  Database.QueryLocator getQueryLocatorWithBinds(String query, Map<String, Object> bindMap);

  /**
   * Inserts big object records immediately (no transaction rollback support).
   */
  List<Database.SaveResult> insertImmediate(List<SObject> sobjects);

  /**
   * Executes a batch job with default scope (200 records).
   */
  Id executeBatch(Database.Batchable<SObject> batchable);

  /**
   * Executes a batch job with specified scope.
   */
  Id executeBatch(Database.Batchable<SObject> batchable, Integer scope);
}