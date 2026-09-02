/**
 * Resolves which family a request is acting for.
 *
 * The parent portal infers the guardian from the session, because a parent can
 * only ever be themselves. Staff submitting on a family's behalf have no
 * Contact on their User, so they name the guardian instead — either directly or
 * through an application whose Primary Guardian already identifies the family.
 *
 * Callers pass their own repo so the query stays on the seam their tests
 * already stub.
 */
public without sharing class ApplicationContext {
  /**
   * The Contact standing in for the family, or null when neither the session
   * nor the application identifies one.
   */
  public static Id resolveGuardianContactId(DatabaseRepo repo, Id applicationId) {
    Id sessionContactId = loggedInContactId(repo);
    if (sessionContactId != null) {
      return sessionContactId;
    }
    Id guardianAccountId = guardianAccountIdForApplication(repo, applicationId);
    return guardianAccountId == null ? null : personContactIdFor(repo, guardianAccountId);
  }

  public static Id personContactIdFor(DatabaseRepo repo, Id accountId) {
    if (accountId == null) {
      return null;
    }
    List<Account> accounts = (List<Account>) repo.queryWithBinds(
      'SELECT PersonContactId FROM Account WHERE Id = :accountId LIMIT 1',
      new Map<String, Object>{ 'accountId' => accountId }
    );
    return accounts.isEmpty() ? null : accounts[0].PersonContactId;
  }

  public static Id accountIdForContact(DatabaseRepo repo, Id contactId) {
    List<Contact> contacts = (List<Contact>) repo.queryWithBinds(
      'SELECT AccountId FROM Contact WHERE Id = :contactId LIMIT 1',
      new Map<String, Object>{ 'contactId' => contactId }
    );
    return contacts.isEmpty() ? null : contacts[0].AccountId;
  }

  private static Id loggedInContactId(DatabaseRepo repo) {
    Id userId = UserInfo.getUserId();
    List<User> users = (List<User>) repo.queryWithBinds(
      'SELECT ContactId FROM User WHERE Id = :userId LIMIT 1',
      new Map<String, Object>{ 'userId' => userId }
    );
    return users.isEmpty() ? null : users[0].ContactId;
  }

  private static Id guardianAccountIdForApplication(DatabaseRepo repo, Id applicationId) {
    if (applicationId == null) {
      return null;
    }
    List<IndividualApplication> apps = (List<IndividualApplication>) repo.queryWithBinds(
      'SELECT Primary_Guardian__c FROM IndividualApplication WHERE Id = :applicationId LIMIT 1',
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    return apps.isEmpty() ? null : apps[0].Primary_Guardian__c;
  }
}