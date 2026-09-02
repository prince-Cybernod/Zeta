/**
 * Tests for {@link ApplicationPdfQueueable}.
 *
 * Coverage is limited by a platform constraint: PageReference.getContentAsPDF()
 * is not functional in unit tests, so the execute() method cannot be fully
 * exercised. Lines after the getContentAsPDF() call (ContentVersion insert,
 * ContentDocumentLink creation) are unreachable in tests.
 */
@IsTest(IsParallel=true)
private class ApplicationPdfQueueableTest {
  private static final DatabaseRepoMock DATABASE_REPO_MOCK;

  static {
    DATABASE_REPO_MOCK = new DatabaseRepoMock();
  }

  @IsTest
  private static void defaultConstructor_createsInstance() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId);

    Assert.isNotNull(queueable, 'Should create instance with default constructor');
  }

  @IsTest
  private static void testVisibleConstructor_createsInstance() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);

    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    Assert.isNotNull(queueable, 'Should create instance with test-visible constructor');
  }

  @IsTest
  private static void execute_coversEntryPointBeforePlatformLimit() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.insertSObjects()).thenReturn(null);

    Test.startTest();
    try {
      queueable.execute(null);
    } catch (Exception e) {
      // getContentAsPDF() is not functional in test context — expected.
    }
    Test.stopTest();
  }

  @IsTest
  private static void buildPdfPageReference_setsIdAndLangParams() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    IndividualApplication app = (IndividualApplication) ReadOnlySObject.create(
      new IndividualApplication(Id = appId),
      new Map<String, Object>{
        'Primary_Guardian__r' => new Account(Language_Preference__pc = 'Spanish')
      }
    );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    PageReference page = queueable.buildPdfPageReference();

    Assert.areEqual(String.valueOf(appId), page.getParameters().get('id'), 'id param set');
    Assert.areEqual('es', page.getParameters().get('lang'), 'lang=es for Spanish guardian');
  }

  @IsTest
  private static void buildPdfPageReference_defaultsToEnglish() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());

    PageReference page = queueable.buildPdfPageReference();

    Assert.areEqual('en', page.getParameters().get('lang'), 'lang=en when no guardian found');
  }

  @IsTest
  private static void buildContentVersion_firstGeneration_setsTitleAndPathNoDocument() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    Blob body = Blob.valueOf('test-pdf-bytes');
    ContentVersion cv = queueable.buildContentVersion(body, null);

    Assert.areEqual('Application-' + appId, cv.Title, 'Title includes app id');
    Assert.areEqual('Application-' + appId + '.pdf', cv.PathOnClient, 'PathOnClient ends in .pdf');
    Assert.areEqual(body, cv.VersionData, 'VersionData carries the PDF blob');
    Assert.isNull(
      cv.ContentDocumentId,
      'First generation must not set ContentDocumentId (creates a new document)'
    );
  }

  @IsTest
  private static void buildContentVersion_existingDoc_appendsVersionToSameDocument() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id existingDocId = SObjectIds.generateFakeId(Schema.ContentDocument.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    ContentVersion cv = queueable.buildContentVersion(Blob.valueOf('v2'), existingDocId);

    Assert.areEqual(
      existingDocId,
      cv.ContentDocumentId,
      'Existing document id must be set so a new version supersedes, not duplicates'
    );
  }

  @IsTest
  private static void findExistingPdfDocumentId_withLinkedDoc_returnsDocumentId() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id docId = SObjectIds.generateFakeId(Schema.ContentDocument.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(
        new List<ContentDocumentLink>{ new ContentDocumentLink(ContentDocumentId = docId) }
      );

    Assert.areEqual(
      docId,
      queueable.findExistingPdfDocumentId(),
      'Returns the linked document id when a matching-title PDF exists'
    );
  }

  @IsTest
  private static void findExistingPdfDocumentId_noLinkedDoc_returnsNull() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<ContentDocumentLink>());

    Assert.isNull(
      queueable.findExistingPdfDocumentId(),
      'Returns null when no matching-title PDF is linked (first generation)'
    );
  }

  @IsTest
  private static void buildContentDocumentLink_setsSharingFields() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    Id docId = SObjectIds.generateFakeId(Schema.ContentDocument.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    ContentDocumentLink cdl = queueable.buildContentDocumentLink(docId);

    Assert.areEqual(docId, cdl.ContentDocumentId, 'Links the content document');
    Assert.areEqual(appId, cdl.LinkedEntityId, 'Links to the application');
    Assert.areEqual('V', cdl.ShareType, 'View-only share type');
    Assert.areEqual('InternalUsers', cdl.Visibility, 'Internal users visibility');
  }

  @IsTest
  private static void resolvePreferredLanguage_withSpanishGuardian_returnsSpanish() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    IndividualApplication app = (IndividualApplication) ReadOnlySObject.create(
      new IndividualApplication(Id = appId),
      new Map<String, Object>{
        'Primary_Guardian__r' => new Account(Language_Preference__pc = 'Spanish')
      }
    );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Assert.areEqual('Spanish', queueable.resolvePreferredLanguage(), 'Returns Spanish');
  }

  @IsTest
  private static void resolvePreferredLanguage_withEnglishGuardian_returnsEnglish() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    IndividualApplication app = (IndividualApplication) ReadOnlySObject.create(
      new IndividualApplication(Id = appId),
      new Map<String, Object>{
        'Primary_Guardian__r' => new Account(Language_Preference__pc = 'English')
      }
    );
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Assert.areEqual('English', queueable.resolvePreferredLanguage(), 'Returns English');
  }

  @IsTest
  private static void resolvePreferredLanguage_withNoPrimaryGuardian_returnsNull() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    IndividualApplication app = new IndividualApplication(Id = appId);
    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>{ app });

    Assert.isNull(queueable.resolvePreferredLanguage(), 'Returns null when no guardian');
  }

  @IsTest
  private static void resolvePreferredLanguage_withEmptyResults_returnsNull() {
    Id appId = SObjectIds.generateFakeId(Schema.IndividualApplication.SObjectType);
    ApplicationPdfQueueable queueable = new ApplicationPdfQueueable(appId, DATABASE_REPO_MOCK);

    DATABASE_REPO_MOCK.when(DATABASE_REPO_MOCK.method.queryWithBinds())
      .thenReturn(new List<IndividualApplication>());

    Assert.isNull(queueable.resolvePreferredLanguage(), 'Returns null when no application found');
  }
}