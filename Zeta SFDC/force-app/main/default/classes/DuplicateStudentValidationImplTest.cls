/**
 * Tests for {@link DuplicateStudentValidationServiceImpl}.
 */
@IsTest(IsParallel=true)
private class DuplicateStudentValidationImplTest {
  private static final DatabaseRepoMock MOCK_REPO;
  private static final DuplicateStudentValidationServiceImpl SERVICE;

  static {
    MOCK_REPO = new DatabaseRepoMock();
    SERVICE = new DuplicateStudentValidationServiceImpl(MOCK_REPO);
  }

  @IsTest
  private static void assertNoDuplicate_whenDuplicateExists_throws() {
    MOCK_REPO.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);
    Id studentAccountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(
        new List<AccountContactRelation>{
          new AccountContactRelation(AccountId = studentAccountId, ContactId = contactId)
        }
      );

    AssertThrows.Throwing throwing = AssertThrows.with(AuraHandledException.class);

    try {
      SERVICE.assertNoDuplicate('Jane', 'Doe', '2020-01-01', contactId);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void assertNoDuplicate_whenNoDuplicate_doesNotThrow() {
    MOCK_REPO.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<AccountContactRelation>());

    SERVICE.assertNoDuplicate('Jane', 'Doe', '2020-01-01', contactId);

    List<Map<String, Object>> calls = MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds());
    Assert.areEqual(1, calls.size(), 'Should run exactly one dup query');
    String query = (String) calls[0].get('query');
    Assert.isTrue(
      query.contains('Account.PersonBirthdate'),
      'DOB predicate expected when a birthdate is provided'
    );
    Map<String, Object> binds = (Map<String, Object>) calls[0].get('bindMap');
    Assert.isTrue(binds.containsKey('birthdateValue'), 'DOB bind expected when provided');
  }

  @IsTest
  private static void assertNoDuplicate_whenBirthdateBlank_matchesNameOnly() {
    MOCK_REPO.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    MOCK_REPO.when(MOCK_REPO.method.queryWithBinds())
      .thenReturn(new List<AccountContactRelation>());

    SERVICE.assertNoDuplicate('Jane', 'Doe', '', contactId);

    List<Map<String, Object>> calls = MOCK_REPO.getCalls(MOCK_REPO.method.queryWithBinds());
    String query = (String) calls[0].get('query');
    Assert.isFalse(
      query.contains('Account.PersonBirthdate'),
      'No DOB predicate when birthdate is blank'
    );
    Map<String, Object> binds = (Map<String, Object>) calls[0].get('bindMap');
    Assert.isFalse(binds.containsKey('birthdateValue'), 'No DOB bind when birthdate is blank');
  }

  @IsTest
  private static void assertNoDuplicate_whenGuardianNull_doesNotQuery() {
    MOCK_REPO.reset();

    SERVICE.assertNoDuplicate('Jane', 'Doe', '2020-01-01', null);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }

  @IsTest
  private static void assertNoDuplicate_whenNameBlank_doesNotQuery() {
    MOCK_REPO.reset();
    Id contactId = SObjectIds.generateFakeId(Schema.Contact.SObjectType);

    SERVICE.assertNoDuplicate('', 'Doe', '2020-01-01', contactId);

    MOCK_REPO.never(MOCK_REPO.method.queryWithBinds());
  }
}