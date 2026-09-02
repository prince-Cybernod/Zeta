@IsTest
public without sharing class ActionPlanController_TSB {
  public class Builder {
    private String guardianFirstName = 'Guardian';
    private String guardianLastName = 'Account';
    private String studentFirstName = 'Student';
    private String studentLastName = 'Account';
    private String termName = 'Test Term';
    private String programName = 'Test Program';
    private String enrollmentStatus = '2. Registration Phase';
    private String intentToReturn = null;
    private Integer taskCount = 2;
    private Boolean createStudent = true;
    private Boolean createContact = true;
    private Boolean createAccount = true;

    public Builder setGuardianName(String first, String last) {
      this.guardianFirstName = first;
      this.guardianLastName = last;
      return this;
    }

    public Builder setStudentName(String first, String last) {
      this.studentFirstName = first;
      this.studentLastName = last;
      return this;
    }

    public Builder setTermName(String name) {
      this.termName = name;
      return this;
    }

    public Builder setProgramName(String name) {
      this.programName = name;
      return this;
    }

    public Builder setEnrollmentStatus(String status) {
      this.enrollmentStatus = status;
      return this;
    }

    public Builder setIntentToReturn(String intent) {
      this.intentToReturn = intent;
      return this;
    }

    public Builder setTaskCount(Integer count) {
      this.taskCount = count;
      return this;
    }

    public Builder withNoStudents() {
      this.createStudent = false;
      return this;
    }

    public Builder withNoContact() {
      this.createContact = false;
      return this;
    }

    public Builder withNoAccount() {
      this.createAccount = false;
      this.createContact = true; // Still need a contact to be "without account"
      return this;
    }

    public ActionPlanController_TSB build() {
      Id guardianRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Guardian' LIMIT 1].Id;
      Id studentRT = [SELECT Id FROM RecordType WHERE SObjectType = 'Account' AND DeveloperName = 'Student' LIMIT 1].Id;

      Account guardianAccount;
      Contact guardianContact;
      User u;

      if (createAccount) {
        // Check if Guardian Account already exists
        List<Account> existingGuardians = [SELECT Id FROM Account WHERE FirstName = :guardianFirstName AND LastName = :guardianLastName AND RecordTypeId = :guardianRT LIMIT 1];
        if (!existingGuardians.isEmpty()) {
          guardianAccount = existingGuardians[0];
        } else {
          // Create Guardian Account
          guardianAccount = new Account(
            FirstName = guardianFirstName,
            LastName = guardianLastName,
            RecordTypeId = guardianRT,
            PersonMailingStreet = '123 Main St',
            PersonMailingCity = 'Bronx',
            PersonMailingState = 'NY',
            PersonMailingPostalCode = '10451',
            PersonMailingCountry = 'USA',
            PersonEmail = (guardianFirstName + '.' + guardianLastName + '@test.com').toLowerCase(),
            PersonHomePhone = '1234567890',
            PersonMobilePhone = '1234567890',
            Phone = '1234567890',
            PersonBirthdate = Date.today().addYears(-30),
            Is_Primary_Guardian__c = true
          );
          insert guardianAccount;
        }

        guardianContact = [SELECT Id FROM Contact WHERE AccountId = :guardianAccount.Id];
      } else {
        // Create Contact without Account
        guardianContact = new Contact(
          FirstName = guardianFirstName,
          LastName = guardianLastName
        );
        insert guardianContact;
      }

      // Check if User already exists
      String uNamePattern = (guardianFirstName + '.' + guardianLastName + '.' + (createContact ? 'portal' : 'std') + '.%@test.com').toLowerCase();
      List<User> existingUsers = [SELECT Id, ContactId FROM User WHERE UserName LIKE :uNamePattern ORDER BY CreatedDate DESC LIMIT 1];
      if (!existingUsers.isEmpty()) {
        u = existingUsers[0];
      } else {
        // Create User
        Profile p;
        if (createContact) {
          p = [SELECT Id FROM Profile WHERE Name = 'Zeta Parent Portal User' LIMIT 1];
        } else {
          p = [SELECT Id FROM Profile WHERE Name = 'Standard User' LIMIT 1];
        }

        u = new User(
          Alias = (guardianFirstName.substring(0, 1) + guardianLastName).substring(0, Math.min(8, (guardianFirstName.substring(0, 1) + guardianLastName).length())).toLowerCase(),
          Email = (guardianFirstName + '.' + guardianLastName + '@test.com').toLowerCase(),
          EmailEncodingKey = 'UTF-8',
          LastName = guardianLastName,
          LanguageLocaleKey = 'en_US',
          LocaleSidKey = 'en_US',
          ProfileId = p.Id,
          TimeZoneSidKey = 'America/Los_Angeles',
          UserName = (guardianFirstName + '.' + guardianLastName + '.' + (createContact ? 'portal' : 'std') + '.' + Datetime.now().getTime() + '@test.com').toLowerCase(),
          ContactId = (createContact ? guardianContact.Id : null)
        );
        insert u;
      }

      Account studentAccount;
      AcademicTerm term;
      AcademicTermEnrollment enrollment;
      List<Task> tasks = new List<Task>();

      if (createStudent && createAccount) {
        // Create Student Account
        studentAccount = new Account(
          FirstName = studentFirstName,
          LastName = studentLastName,
          RecordTypeId = studentRT,
          Primary_Guardian__c = guardianAccount.Id,
          PersonMailingStreet = '123 Main St',
          PersonMailingCity = 'Bronx',
          PersonMailingState = 'NY',
          PersonMailingPostalCode = '10451',
          PersonMailingCountry = 'USA',
          PersonBirthdate = Date.today().addYears(-10)
        );
        insert studentAccount;

        Contact studentContact = [SELECT Id FROM Contact WHERE AccountId = :studentAccount.Id];

        // Create AcademicTerm
        term = new AcademicTerm(
          Name = termName,
          StartDate = Date.today(),
          EndDate = Date.today().addMonths(6)
        );
        insert term;

        // Create Learning
        Learning l = new Learning(
          Name = programName
        );
        insert l;

        // Create LearningProgram
        LearningProgram lp = new LearningProgram(
          Name = programName,
          LearningId = l.Id
        );
        insert lp;

        // Create AcademicTermEnrollment
        enrollment = new AcademicTermEnrollment(
          LearnerContactId = studentContact.Id,
          AcademicTermId = term.Id,
          Learning_Program__c = lp.Id,
          EnrollmentStatus = enrollmentStatus,
          Intent_To_Return__c = intentToReturn
        );
        insert enrollment;

        // Create Tasks
        for (Integer i = 0; i < taskCount; i++) {
          tasks.add(new Task(
            Type = 'Registration Task',
            Subject = 'Task ' + (i + 1),
            Status = (i == 1 ? 'Completed' : 'Not Started'),
            WhatId = enrollment.Id,
            Form_URL__c = 'https://test.com/form' + (i + 1)
          ));
        }
        insert tasks;
      }

      instance = new ActionPlanController_TSB(guardianAccount, studentAccount, u, term, enrollment, tasks);
      return instance;
    }

    public ActionPlanController_TSB getInstance() {
      ActionPlanController_TSB inst = ActionPlanController_TSB.getInstance(
        guardianFirstName, guardianLastName, studentFirstName, studentLastName, termName,
        enrollmentStatus, intentToReturn, createStudent, createContact, createAccount
      );
      if (inst == null) {
        inst = build();
      }
      return inst;
    }
  }

  private static ActionPlanController_TSB instance;

  public Account guardian;
  public Account student;
  public User guardianUser;
  public AcademicTerm term;
  public AcademicTermEnrollment enrollment;
  public List<Task> tasks;

  private ActionPlanController_TSB(Account g, Account s, User u, AcademicTerm t, AcademicTermEnrollment e, List<Task> tks) {
    this.guardian = g;
    this.student = s;
    this.guardianUser = u;
    this.term = t;
    this.enrollment = e;
    this.tasks = tks;
  }

  public static Builder newBuilder() {
    instance = null;
    return new Builder();
  }

  public static ActionPlanController_TSB getInstance(
    String gFirst, String gLast, String sFirst, String sLast, String tName,
    String eStat, String itr,
    Boolean createStudent, Boolean createContact, Boolean createAccount
  ) {
    if (instance == null || 
        (instance.guardian != null && (instance.guardian.FirstName != gFirst || instance.guardian.LastName != gLast)) ||
        (instance.guardian == null && createAccount) ||
        (instance.student != null && (instance.student.FirstName != sFirst || instance.student.LastName != sLast)) ||
        (instance.student == null && createStudent && createAccount) ||
        (instance.term != null && instance.term.Name != tName) ||
        (instance.enrollment != null && (instance.enrollment.EnrollmentStatus != eStat || instance.enrollment.Intent_To_Return__c != itr))) {
      
      String uNamePattern = (gFirst + '.' + gLast + '.' + (createContact ? 'portal' : 'std') + '.%@test.com').toLowerCase();
      List<User> us = [SELECT Id, ContactId FROM User WHERE UserName LIKE :uNamePattern ORDER BY CreatedDate DESC LIMIT 1];
      if (us.isEmpty()) {
        return null;
      }
      User u = us[0];

      Account g;
      if (createAccount) {
        List<Account> gs = [SELECT Id, FirstName, LastName, PersonEmail FROM Account WHERE FirstName = :gFirst AND LastName = :gLast LIMIT 1];
        if (gs.isEmpty()) {
          return null;
        }
        g = gs[0];
      }

      Account s;
      AcademicTerm t;
      AcademicTermEnrollment e;
      List<Task> tks = new List<Task>();

      if (createStudent && createAccount) {
        List<Account> ss = [SELECT Id, FirstName, LastName FROM Account WHERE FirstName = :sFirst AND LastName = :sLast AND Primary_Guardian__c = :g.Id LIMIT 1];
        if (ss.isEmpty()) {
          return null;
        }
        s = ss[0];

        List<AcademicTerm> ts = [SELECT Id, Name FROM AcademicTerm WHERE Name = :tName LIMIT 1];
        if (ts.isEmpty()) {
          return null;
        }
        t = ts[0];

        List<AcademicTermEnrollment> es = [SELECT Id FROM AcademicTermEnrollment WHERE LearnerAccountId = :s.Id AND AcademicTermId = :t.Id LIMIT 1];
        if (es.isEmpty()) {
          return null;
        }
        e = es[0];

        tks = [SELECT Id, Subject, Status, Form_URL__c FROM Task WHERE WhatId = :e.Id ORDER BY Subject ASC];
      }

      instance = new ActionPlanController_TSB(g, s, u, t, e, tks);
    }
    return instance;
  }
}