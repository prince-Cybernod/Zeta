public without sharing class ApplicationPdfController {
  private final DatabaseRepo databaseRepo;

  public Id applicationId { get; set; }

  private IndividualApplication application;
  private List<Map<String, Object>> rankedSchools;
  private List<Priority_Item__c> siblings;
  private List<Map<String, Object>> formAnswers;

  public ApplicationPdfController() {
    this(new SystemModeDatabaseRepo());
    String idParam = ApexPages.currentPage().getParameters().get('id');
    if (String.isNotBlank(idParam)) {
      this.applicationId = Id.valueOf(idParam);
    }
  }

  @TestVisible
  private ApplicationPdfController(DatabaseRepo databaseRepo) {
    this.databaseRepo = databaseRepo;
  }

  public IndividualApplication getApplication() {
    if (application == null) {
      loadApplication();
    }
    return application;
  }

  public List<Map<String, Object>> getRankedSchools() {
    if (rankedSchools == null) {
      loadRankedSchools();
    }
    return rankedSchools;
  }

  public List<Map<String, Object>> getAttendingSiblings() {
    loadSiblingsIfNeeded();
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (Priority_Item__c item : siblings) {
      if (item.Priority_Type__c == 'Sibling Attending') {
        result.add(siblingToMap(item));
      }
    }
    return result;
  }

  public List<Map<String, Object>> getApplyingSiblings() {
    loadSiblingsIfNeeded();
    List<Map<String, Object>> result = new List<Map<String, Object>>();
    for (Priority_Item__c item : siblings) {
      if (item.Priority_Type__c == 'Sibling Applying') {
        result.add(siblingToMap(item));
      }
    }
    return result;
  }

  public Boolean getHasAttendingSiblings() {
    return !getAttendingSiblings().isEmpty();
  }

  public Boolean getHasApplyingSiblings() {
    return !getApplyingSiblings().isEmpty();
  }

  public List<Map<String, Object>> getFormAnswers() {
    if (formAnswers == null) {
      loadFormAnswers();
    }
    return formAnswers;
  }

  public String getLanguage() {
    PageReference page = ApexPages.currentPage();
    if (page == null) {
      return 'en';
    }
    String lang = page.getParameters().get('lang');
    return lang == 'es' ? 'es' : 'en';
  }

  public String getFormattedSubmissionDate() {
    IndividualApplication app = getApplication();
    if (app.AppliedDate == null) {
      return '';
    }
    Datetime dt = Datetime.newInstance(
      app.AppliedDate.year(),
      app.AppliedDate.month(),
      app.AppliedDate.day()
    );
    return dt.format('MMMM d, yyyy');
  }

  public String getFormattedSignatureDate() {
    IndividualApplication app = getApplication();
    if (app.Signature_Date__c == null) {
      return '';
    }
    Datetime dt = Datetime.newInstance(
      app.Signature_Date__c.year(),
      app.Signature_Date__c.month(),
      app.Signature_Date__c.day()
    );
    return dt.format('MMMM d, yyyy');
  }

  public String getStudentFirstName() {
    return safeString(getApplication().Contact.FirstName);
  }

  public String getStudentLastName() {
    return safeString(getApplication().Contact.LastName);
  }

  public String getStudentDateOfBirth() {
    IndividualApplication app = getApplication();
    if (app.Contact.Birthdate == null) {
      return '';
    }
    Datetime dt = Datetime.newInstance(
      app.Contact.Birthdate.year(),
      app.Contact.Birthdate.month(),
      app.Contact.Birthdate.day()
    );
    return dt.format('MMMM d, yyyy');
  }

  public String getSignatureName() {
    return safeString(getApplication().Signature_Name__c);
  }

  private void loadApplication() {
    String query =
      'SELECT Id, Name, Status, AppliedDate,' +
      ' Contact.FirstName, Contact.LastName, Contact.Birthdate,' +
      ' Employee_Priority__c, Employee_First_Name__c,' +
      ' Employee_Last_Name__c, Employee_Workplace__c,' +
      ' Signature_Name__c, Signature_Date__c' +
      ' FROM IndividualApplication' +
      ' WHERE Id = :applicationId' +
      ' LIMIT 1';
    List<IndividualApplication> apps = (List<IndividualApplication>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );
    Preconditions.checkArgument(!apps.isEmpty(), 'Application not found: ' + applicationId);
    application = apps[0];
  }

  private void loadRankedSchools() {
    String query =
      'SELECT Id, LearningProgramId,' +
      ' LearningProgram.School__c, LearningProgram.School__r.Name,' +
      ' LearningProgram.School__r.Zeta_School_Name__c, School_Rank__c' +
      ' FROM AcademicInterest' +
      ' WHERE IndividualApplicationId = :applicationId' +
      ' AND School_Rank__c != NULL' +
      ' ORDER BY School_Rank__c ASC';
    List<AcademicInterest> interests = (List<AcademicInterest>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{ 'applicationId' => applicationId }
    );

    rankedSchools = new List<Map<String, Object>>();
    for (AcademicInterest ai : interests) {
      Account school = ai.LearningProgram?.School__r;
      Map<String, Object> schoolData = new Map<String, Object>();
      schoolData.put(
        'rank',
        ai.School_Rank__c != null ? String.valueOf(Integer.valueOf(ai.School_Rank__c)) : ''
      );
      schoolData.put(
        'name',
        school?.Zeta_School_Name__c != null ? school.Zeta_School_Name__c : school?.Name
      );
      rankedSchools.add(schoolData);
    }
  }

  private void loadSiblingsIfNeeded() {
    if (siblings != null) {
      return;
    }
    String query =
      'SELECT Id, Priority_Type__c, First_Name__c, Last_Name__c,' +
      ' Date_of_Birth__c, Gender__c, Sibling_s_Zeta_School__c' +
      ' FROM Priority_Item__c' +
      ' WHERE Related_Application__c = :applicationId' +
      ' AND Priority_Type__c IN (:typeAttending, :typeApplying)' +
      ' ORDER BY Priority_Type__c, CreatedDate';
    siblings = (List<Priority_Item__c>) databaseRepo.queryWithBinds(
      query,
      new Map<String, Object>{
        'applicationId' => applicationId,
        'typeAttending' => 'Sibling Attending',
        'typeApplying' => 'Sibling Applying'
      }
    );
  }

  private void loadFormAnswers() {
    formAnswers = new List<Map<String, Object>>();

    List<Application_Section__mdt> sections = [
      SELECT DeveloperName, Label, Display_Label__c, Sort_Order__c
      FROM Application_Section__mdt
      WHERE Page__r.DeveloperName = 'Application_Details' AND Is_Active__c = TRUE
      ORDER BY Sort_Order__c ASC
    ];

    Set<String> sectionDevNames = new Set<String>();
    for (Application_Section__mdt s : sections) {
      sectionDevNames.add(s.DeveloperName);
    }
    if (sectionDevNames.isEmpty()) {
      return;
    }

    List<String> fields = new List<String>{
      'DeveloperName',
      'Display_Label__c',
      'Section__r.DeveloperName',
      'Sort_Order__c',
      'Invert_Display__c',
      'Target_Field__r.Entity_Definition__r.QualifiedApiName',
      'Target_Field__r.Field_Definition__r.QualifiedApiName',
      'Target_Field__r.Entity_Particle__r.QualifiedApiName'
    };
    String questionQuery = String.join(
      new List<String>{
        'SELECT',
        String.join(fields, ', '),
        'FROM Application_Question__mdt',
        'WHERE Section__r.DeveloperName IN :sectionDevNames AND Is_Active__c = TRUE',
        'ORDER BY Sort_Order__c ASC'
      },
      ' '
    );
    List<Application_Question__mdt> questions = Database.query(questionQuery);
    if (questions.isEmpty()) {
      return;
    }

    Set<String> fieldApiNameSet = new Set<String>();
    Map<String, SObjectField> fieldByQuestion = new Map<String, SObjectField>();
    SObjectType sobjectType = null;

    for (Application_Question__mdt q : questions) {
      // Compound inputs (e.g., Address) have no Target_Field mapping; they are
      // rendered via Field_Bindings__c on the form and have nothing to show
      // in the PDF's single-field-per-question layout.
      if (q.Target_Field__r == null) {
        continue;
      }
      SObjectType qType = SObjectFieldCmdtParser.getSObjectType(q.Target_Field__r);
      if (sobjectType == null) {
        sobjectType = qType;
      }
      SObjectField field = SObjectFieldCmdtParser.getSObjectField(q.Target_Field__r);
      String fieldName = field.getDescribe().getName();
      fieldApiNameSet.add(fieldName);
      fieldByQuestion.put(q.DeveloperName, field);
    }

    if (sobjectType == null || fieldApiNameSet.isEmpty()) {
      return;
    }

    List<String> fieldApiNames = new List<String>(fieldApiNameSet);
    String recordQuery =
      'SELECT ' +
      String.join(fieldApiNames, ', ') +
      ' FROM ' +
      sobjectType.getDescribe().getName() +
      ' WHERE Id = :applicationId LIMIT 1';
    List<SObject> records = Database.queryWithBinds(
      recordQuery,
      new Map<String, Object>{ 'applicationId' => applicationId },
      AccessLevel.SYSTEM_MODE
    );

    if (records.isEmpty()) {
      return;
    }

    SObject record = records[0];

    Map<String, List<Map<String, Object>>> answersBySection = new Map<String, List<Map<String, Object>>>();
    for (Application_Question__mdt q : questions) {
      SObjectField field = fieldByQuestion.get(q.DeveloperName);
      if (field == null) {
        continue;
      }
      Object value = record.get(field.getDescribe().getName());
      String stringValue = formatAnswerValue(value, q.Invert_Display__c);
      if (String.isBlank(stringValue)) {
        continue;
      }
      Map<String, Object> answer = new Map<String, Object>{
        'label' => LabelResolver.resolve(q.Display_Label__c),
        'value' => stringValue
      };
      String sectionDevName = q.Section__r.DeveloperName;
      List<Map<String, Object>> bucket = answersBySection.get(sectionDevName);
      if (bucket == null) {
        bucket = new List<Map<String, Object>>();
        answersBySection.put(sectionDevName, bucket);
      }
      bucket.add(answer);
    }

    for (Application_Section__mdt s : sections) {
      List<Map<String, Object>> answers = answersBySection.get(s.DeveloperName);
      if (answers == null || answers.isEmpty()) {
        continue;
      }
      String sectionLabel = String.isNotBlank(s.Display_Label__c)
        ? LabelResolver.resolve(s.Display_Label__c)
        : s.Label;
      formAnswers.add(
        new Map<String, Object>{
          'sectionDeveloperName' => s.DeveloperName,
          'sectionLabel' => sectionLabel,
          'answers' => answers
        }
      );
    }
  }

  // A question flagged Invert_Display__c stores the logical inverse of its
  // display label (e.g. Lives_With_Guardian_1__c is stored true when the student
  // lives WITH the guardian, but the label reads "Student lives at a different
  // address"). The data-entry form inverts these booleans for display; the PDF
  // must do the same so the rendered document never contradicts what was entered.
  @TestVisible
  private static String formatAnswerValue(Object value, Boolean invertDisplay) {
    if (invertDisplay == true && value instanceof Boolean) {
      value = !((Boolean) value);
    }
    return value != null ? String.valueOf(value) : '';
  }

  private static Map<String, Object> siblingToMap(Priority_Item__c item) {
    Map<String, Object> result = new Map<String, Object>();
    result.put('name', safeJoin(new List<String>{ item.First_Name__c, item.Last_Name__c }));
    result.put(
      'dateOfBirth',
      item.Date_of_Birth__c != null ? String.valueOf(item.Date_of_Birth__c) : ''
    );
    result.put('gender', item.Gender__c != null ? item.Gender__c : '');
    result.put(
      'zetaSchool',
      item.Sibling_s_Zeta_School__c != null ? item.Sibling_s_Zeta_School__c : ''
    );
    return result;
  }

  private static String safeString(String value) {
    return String.isNotBlank(value) ? value : '';
  }

  private static String safeJoin(List<String> parts) {
    List<String> nonBlank = new List<String>();
    for (String s : parts) {
      if (String.isNotBlank(s)) {
        nonBlank.add(s);
      }
    }
    return String.join(nonBlank, ' ');
  }
}