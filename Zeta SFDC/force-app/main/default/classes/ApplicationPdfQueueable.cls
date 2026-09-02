public without sharing class ApplicationPdfQueueable implements Queueable, Database.AllowsCallouts {
  private final DatabaseRepo databaseRepo;
  private final Id applicationId;

  public ApplicationPdfQueueable(Id applicationId) {
    this(applicationId, new SystemModeDatabaseRepo());
  }

  @TestVisible
  private ApplicationPdfQueueable(Id applicationId, DatabaseRepo databaseRepo) {
    this.applicationId = applicationId;
    this.databaseRepo = databaseRepo;
  }

  public void execute(QueueableContext context) {
    try {
      PageReference pdfPage = buildPdfPageReference();
      Blob pdfBody = pdfPage.getContentAsPDF();

      // If a PDF already exists for this app, append a new version to the same
      // document (audit trail) instead of creating a duplicate file.
      Id existingDocumentId = findExistingPdfDocumentId();
      ContentVersion cv = buildContentVersion(pdfBody, existingDocumentId);
      databaseRepo.insertSObjects(new List<ContentVersion>{ cv });

      // Only the first generation needs a ContentDocumentLink; superseding
      // versions inherit the existing document's links.
      if (existingDocumentId == null) {
        Id contentDocumentId = lookupContentDocumentId(cv.Id);
        ContentDocumentLink cdl = buildContentDocumentLink(contentDocumentId);
        databaseRepo.insertSObjects(new List<ContentDocumentLink>{ cdl });
      }
    } catch (Exception e) {
      System.debug(
        LoggingLevel.ERROR,
        'ApplicationPdfQueueable failed for ' +
          applicationId +
          ': ' +
          e.getMessage() +
          '\n' +
          e.getStackTraceString()
      );
      throw e;
    }
  }

  @TestVisible
  private Id findExistingPdfDocumentId() {
    String title = 'Application-' + applicationId;
    String query =
      'SELECT ContentDocumentId FROM ContentDocumentLink' +
      ' WHERE LinkedEntityId = :applicationId AND ContentDocument.Title = :title LIMIT 1';
    List<ContentDocumentLink> links = (List<ContentDocumentLink>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId, 'title' => title }
    );
    return links.isEmpty() ? null : links[0].ContentDocumentId;
  }

  @TestVisible
  private ContentVersion buildContentVersion(Blob pdfBody, Id existingDocumentId) {
    ContentVersion cv = new ContentVersion();
    cv.Title = 'Application-' + applicationId;
    cv.PathOnClient = 'Application-' + applicationId + '.pdf';
    cv.VersionData = pdfBody;
    // Setting ContentDocumentId on a new ContentVersion adds a version to that
    // existing document rather than creating a new one.
    if (existingDocumentId != null) {
      cv.ContentDocumentId = existingDocumentId;
    }
    return cv;
  }

  @TestVisible
  private ContentDocumentLink buildContentDocumentLink(Id contentDocumentId) {
    ContentDocumentLink cdl = new ContentDocumentLink();
    cdl.ContentDocumentId = contentDocumentId;
    cdl.LinkedEntityId = applicationId;
    cdl.ShareType = 'V';
    cdl.Visibility = 'InternalUsers';
    return cdl;
  }

  private Id lookupContentDocumentId(Id contentVersionId) {
    String cvQuery = 'SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cvId LIMIT 1';
    return ((ContentVersion) Database.queryWithBinds(
        cvQuery,
        new Map<String, Object>{ 'cvId' => contentVersionId },
        AccessLevel.SYSTEM_MODE
      ))
      .ContentDocumentId;
  }

  @TestVisible
  private PageReference buildPdfPageReference() {
    String preferredLanguage = resolvePreferredLanguage();
    String lang = preferredLanguage == 'Spanish' ? 'es' : 'en';

    PageReference pdfPage = Page.ApplicationPdf;
    pdfPage.getParameters().put('id', applicationId);
    pdfPage.getParameters().put('lang', lang);
    return pdfPage;
  }

  @TestVisible
  private String resolvePreferredLanguage() {
    String query =
      'SELECT Primary_Guardian__r.Language_Preference__pc' +
      ' FROM IndividualApplication WHERE Id = :applicationId LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    if (apps.isEmpty() || apps[0].Primary_Guardian__r == null) {
      return null;
    }
    return apps[0].Primary_Guardian__r.Language_Preference__pc;
  }
}