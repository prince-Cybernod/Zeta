/**
 * {@link Mock} implementation of {@link DatabaseRepo}.
 */
@IsTest
@SuppressWarnings('PMD.CognitiveComplexity')
public with sharing class DatabaseRepoMock extends Mock implements DatabaseRepo {
  public final Method method = new Method();

  public Savepoint setSavepoint() {
    return (Savepoint) mockedCall(method.setSavepoint(), new Map<String, Object>());
  }

  public void rollback(Savepoint savepoint) {
    mockedCall(method.rollback(), new Map<String, Object>{ 'savepoint' => savepoint });
  }

  public void insertSObjects(List<SObject> sobjects) {
    mockedCall(method.insertSObjects(), new Map<String, Object>{ 'sobjects' => sobjects });
  }

  public void updateSObjects(List<SObject> sobjects) {
    mockedCall(method.updateSObjects(), new Map<String, Object>{ 'sobjects' => sobjects });
  }

  public void upsertSObjects(List<SObject> sobjects, SObjectField field) {
    mockedCall(
      method.upsertSObjects(),
      new Map<String, Object>{ 'sobjects' => sobjects, 'field' => field }
    );
  }

  public void deleteSObjects(List<SObject> sobjects) {
    mockedCall(method.deleteSObjects(), new Map<String, Object>{ 'sobjects' => sobjects });
  }

  public void undeleteSObjects(List<SObject> sobjects) {
    mockedCall(method.undeleteSObjects(), new Map<String, Object>{ 'sobjects' => sobjects });
  }

  public List<SObject> query(String query) {
    return (List<SObject>) mockedCall(method.query(), new Map<String, Object>{ 'query' => query });
  }

  public List<SObject> queryWithBinds(String query, Map<String, Object> bindMap) {
    return (List<SObject>) mockedCall(
      method.queryWithBinds(),
      new Map<String, Object>{ 'query' => query, 'bindMap' => bindMap }
    );
  }

  public Integer countQuery(String query) {
    return (Integer) mockedCall(method.countQuery(), new Map<String, Object>{ 'query' => query });
  }

  public Integer countQueryWithBinds(String query, Map<String, Object> bindMap) {
    return (Integer) mockedCall(
      method.countQueryWithBinds(),
      new Map<String, Object>{ 'query' => query, 'bindMap' => bindMap }
    );
  }

  public Database.QueryLocator getQueryLocator(String query) {
    return (Database.QueryLocator) mockedCall(
      method.getQueryLocator(),
      new Map<String, Object>{ 'query' => query }
    );
  }

  public Database.QueryLocator getQueryLocatorWithBinds(String query, Map<String, Object> bindMap) {
    return (Database.QueryLocator) mockedCall(
      method.getQueryLocatorWithBinds(),
      new Map<String, Object>{ 'query' => query, 'bindMap' => bindMap }
    );
  }

  public List<Database.SaveResult> insertImmediate(List<SObject> sobjects) {
    return (List<Database.SaveResult>) mockedCall(
      method.insertImmediate(),
      new Map<String, Object>{ 'sobjects' => sobjects }
    );
  }

  public Id executeBatch(Database.Batchable<SObject> batchable) {
    return (Id) mockedCall(
      method.executeBatch(),
      new Map<String, Object>{ 'batchable' => batchable }
    );
  }

  public Id executeBatch(Database.Batchable<SObject> batchable, Integer scope) {
    return (Id) mockedCall(
      method.executeBatchWithScope(),
      new Map<String, Object>{ 'batchable' => batchable, 'scope' => scope }
    );
  }

  public class Method {
    public String setSavepoint() {
      return new ExecutionInfo().getFullName();
    }
    public String rollback() {
      return new ExecutionInfo().getFullName();
    }
    public String insertSObjects() {
      return new ExecutionInfo().getFullName();
    }
    public String updateSObjects() {
      return new ExecutionInfo().getFullName();
    }
    public String upsertSObjects() {
      return new ExecutionInfo().getFullName();
    }
    public String deleteSObjects() {
      return new ExecutionInfo().getFullName();
    }
    public String undeleteSObjects() {
      return new ExecutionInfo().getFullName();
    }
    public String query() {
      return new ExecutionInfo().getFullName();
    }
    public String queryWithBinds() {
      return new ExecutionInfo().getFullName();
    }
    public String countQuery() {
      return new ExecutionInfo().getFullName();
    }
    public String countQueryWithBinds() {
      return new ExecutionInfo().getFullName();
    }
    public String getQueryLocator() {
      return new ExecutionInfo().getFullName();
    }
    public String getQueryLocatorWithBinds() {
      return new ExecutionInfo().getFullName();
    }
    public String insertImmediate() {
      return new ExecutionInfo().getFullName();
    }
    public String executeBatch() {
      return new ExecutionInfo().getFullName();
    }
    public String executeBatchWithScope() {
      return new ExecutionInfo().getFullName();
    }
  }
}