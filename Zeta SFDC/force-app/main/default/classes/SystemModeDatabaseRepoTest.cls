/**
 * Tests for {@link SystemModeDatabaseRepo}.
 */
@IsTest(IsParallel=true)
private class SystemModeDatabaseRepoTest {
  private static final SystemModeDatabaseRepo SYSTEM_MODE_DATABASE_REPO;

  static {
    SYSTEM_MODE_DATABASE_REPO = new SystemModeDatabaseRepo();
  }

  @IsTest
  private static void setSavepoint_returnsSavepoint() {
    Savepoint savepoint = SYSTEM_MODE_DATABASE_REPO.setSavepoint();

    Assert.areEqual(1, Limits.getDmlStatements());
    Assert.isNotNull(savepoint);
  }

  @IsTest
  private static void rollback_rollsBackTransaction() {
    Savepoint savepoint = SYSTEM_MODE_DATABASE_REPO.setSavepoint();
    SYSTEM_MODE_DATABASE_REPO.rollback(savepoint);

    Assert.areEqual(2, Limits.getDmlStatements());
  }

  @IsTest
  private static void insertSObjects_performsDml() {
    List<Account> accounts = new List<Account>{ new Account(Name = 'Test Account') };

    try {
      SYSTEM_MODE_DATABASE_REPO.insertSObjects(accounts);
    } catch (Exception e) {
      System.debug('Preventing the test from failing due to a DML exception');
    } finally {
      Assert.isTrue(Limits.getDmlStatements() > 0);
    }
  }

  @IsTest
  private static void updateSObjects_performsDml() {
    List<Account> accounts = new List<Account>{
      new Account(Id = SObjectIds.generateFakeId(Account.SObjectType), Name = 'Updated Account')
    };

    try {
      SYSTEM_MODE_DATABASE_REPO.updateSObjects(accounts);
    } catch (Exception e) {
      System.debug('Preventing the test from failing due to a DML exception');
    } finally {
      Assert.isTrue(Limits.getDmlStatements() > 0);
    }
  }

  @IsTest
  private static void upsertPlaidCounterparties_performsDml() {
    List<Account> accounts = new List<Account>{ new Account(Name = 'Upsert Account') };
    SObjectField field = Schema.Account.Id;

    try {
      SYSTEM_MODE_DATABASE_REPO.upsertSObjects(accounts, field);
    } catch (Exception e) {
      System.debug('Preventing the test from failing due to a DML exception');
    } finally {
      Assert.isTrue(Limits.getDmlStatements() > 0);
    }
  }

  @IsTest
  private static void deletePlaidCounterparties_performsDml() {
    List<Account> accounts = new List<Account>{
      new Account(Id = SObjectIds.generateFakeId(Account.SObjectType))
    };

    try {
      SYSTEM_MODE_DATABASE_REPO.deleteSObjects(accounts);
    } catch (Exception e) {
      System.debug('Preventing the test from failing due to a DML exception');
    } finally {
      Assert.isTrue(Limits.getDmlStatements() > 0);
    }
  }

  @IsTest
  private static void undeletePlaidCounterparties_performsDml() {
    List<Account> accounts = new List<Account>{
      new Account(Id = SObjectIds.generateFakeId(Account.SObjectType))
    };

    try {
      SYSTEM_MODE_DATABASE_REPO.undeleteSObjects(accounts);
    } catch (Exception e) {
      System.debug('Preventing the test from failing due to a DML exception');
    } finally {
      Assert.isTrue(Limits.getDmlStatements() > 0);
    }
  }

  @IsTest
  private static void query_runsQuery() {
    String query = 'SELECT Id FROM Account LIMIT 1';

    SYSTEM_MODE_DATABASE_REPO.query(query);

    Assert.areEqual(1, Limits.getQueries());
  }

  @IsTest
  private static void countQuery_runsQuery() {
    String query = 'SELECT COUNT() FROM Account';

    SYSTEM_MODE_DATABASE_REPO.countQuery(query);

    Assert.areEqual(1, Limits.getQueries());
  }

  @IsTest
  private static void queryWithBinds_runsQuery() {
    String query = 'SELECT Id FROM Account WHERE Name = :accountName LIMIT 1';
    Map<String, Object> bindMap = new Map<String, Object>{ 'accountName' => 'Test' };

    SYSTEM_MODE_DATABASE_REPO.queryWithBinds(query, bindMap);

    Assert.areEqual(1, Limits.getQueries());
  }

  @IsTest
  private static void countQueryWithBinds_runsQuery() {
    String query = 'SELECT COUNT() FROM Account WHERE Name = :accountName';
    Map<String, Object> bindMap = new Map<String, Object>{ 'accountName' => 'Test' };

    SYSTEM_MODE_DATABASE_REPO.countQueryWithBinds(query, bindMap);

    Assert.areEqual(1, Limits.getQueries());
  }

  @IsTest
  private static void getQueryLocator_returnsQueryLocator() {
    String query = 'SELECT Id FROM Account LIMIT 1';

    Database.QueryLocator locator = SYSTEM_MODE_DATABASE_REPO.getQueryLocator(query);

    Assert.isNotNull(locator);
    Assert.areEqual(1, Limits.getQueries());
  }

  @IsTest
  private static void getQueryLocatorWithBinds_returnsQueryLocator() {
    String query = 'SELECT Id FROM Account WHERE Name = :accountName LIMIT 1';
    Map<String, Object> bindMap = new Map<String, Object>{ 'accountName' => 'Test' };

    Database.QueryLocator locator = SYSTEM_MODE_DATABASE_REPO.getQueryLocatorWithBinds(
      query,
      bindMap
    );

    Assert.isNotNull(locator);
    Assert.areEqual(1, Limits.getQueries());
  }

  @IsTest
  private static void insertImmediate_returnsSaveResults() {
    List<SObject> emptyList = new List<SObject>();

    List<Database.SaveResult> results = SYSTEM_MODE_DATABASE_REPO.insertImmediate(emptyList);

    Assert.isNotNull(results);
    Assert.areEqual(0, results.size());
  }

  @IsTest
  private static void executeBatch_callsDatabase() {
    SystemModeDatabaseRepo.hasExecutedBatch = false;

    SYSTEM_MODE_DATABASE_REPO.executeBatch(null);

    Assert.isTrue(SystemModeDatabaseRepo.hasExecutedBatch);
  }

  @IsTest
  private static void executeBatchWithScope_callsDatabase() {
    SystemModeDatabaseRepo.hasExecutedBatch = false;

    SYSTEM_MODE_DATABASE_REPO.executeBatch(null, 100);

    Assert.isTrue(SystemModeDatabaseRepo.hasExecutedBatch);
  }
}