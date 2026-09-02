@IsTest(IsParallel=true)
private class ApplicationContextTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
  }

  @IsTest
  private static void resolveGuardianContactId_sessionContact_shortCircuits() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = contactId) });

    Id resolved = ApplicationContext.resolveGuardianContactId(
      DATABASE_REPO_MOCK,
      SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType)
    );

    Assert.areEqual(contactId, resolved, 'The session Contact identifies the family on its own');
    Assert.areEqual(
      1,
      DATABASE_REPO_MOCK.getCallCount(DATABASE_REPO_MOCK.method.queryWithBinds()),
      'A session Contact should short-circuit the application lookup'
    );
  }

  @IsTest
  private static void resolveGuardianContactId_noSessionContact_resolvesThroughTheApplication() {
    DATABASE_REPO_MOCK.reset();
    Id applicationId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id guardianAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    Id guardianContactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      // queryWithBinds #1: the staff User, which carries no Contact
      .thenReturn(new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = null) })
      // queryWithBinds #2: the application, which names the family
      .thenReturn(
        new List<IndividualApplication>{
          new IndividualApplication(Id = applicationId, Primary_Guardian__c = guardianAccountId)
        }
      )
      // queryWithBinds #3: PersonContactId is read-only, so deserialize it onto the mock
      .thenReturn(
        new List<Account>{
          (Account) JSON.deserialize(
            '{"PersonContactId":"' + guardianContactId + '"}',
            Account.class
          )
        }
      );

    Id resolved = ApplicationContext.resolveGuardianContactId(DATABASE_REPO_MOCK, applicationId);

    Assert.areEqual(
      guardianContactId,
      resolved,
      'Staff with no Contact should resolve the family through the application'
    );
  }

  @IsTest
  private static void resolveGuardianContactId_noSessionAndNoApplication_returnsNull() {
    DATABASE_REPO_MOCK.reset();
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<User>{ new User(Id = UserInfo.getUserId(), ContactId = null) });

    Assert.isNull(
      ApplicationContext.resolveGuardianContactId(DATABASE_REPO_MOCK, null),
      'Nothing identifies the family, so there is no Contact to return'
    );
    Assert.areEqual(
      1,
      DATABASE_REPO_MOCK.getCallCount(DATABASE_REPO_MOCK.method.queryWithBinds()),
      'A null application must not be queried for'
    );
  }

  @IsTest
  private static void accountIdForContact_returnsTheContactsAccount() {
    DATABASE_REPO_MOCK.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<Contact>{ new Contact(Id = contactId, AccountId = accountId) });

    Assert.areEqual(
      accountId,
      ApplicationContext.accountIdForContact(DATABASE_REPO_MOCK, contactId),
      'The household Account comes from the Contact'
    );
  }
}