@IsTest
private class ActionPlanController_T {
  static final ActionPlanController_TSB.Builder builder = ActionPlanController_TSB.newBuilder()
    .setGuardianName('Guardian', 'Account')
    .setStudentName('Student', 'Account')
    .setTermName('Test Term')
    .setTaskCount(2);

  @IsTest
  static void getAllActionPlanData_success() {
    ActionPlanController_TSB setup = builder.getInstance();
    User u = setup.guardianUser;

    System.runAs(u) {
      Test.startTest();
      List<ActionPlanController.ActionPlanData> results = ActionPlanController.getAllActionPlanData();
      Test.stopTest();

      System.assertEquals(1, results.size(), 'Should return 1 enrollment');
      // Person Account name is FirstName + ' ' + LastName
      System.assertEquals('Student Account', results[0].studentName);
      System.assertEquals('Test Program', results[0].programName);
      System.assertEquals(2, results[0].tasks.size(), 'Should return 2 tasks');

      ActionPlanController.TaskData t1 = results[0].tasks[0];
      System.assertEquals('Task 1', t1.subject);
      System.assert(!t1.isComplete);
      System.assert(t1.formUrl.contains('taskId=' + t1.id));

      ActionPlanController.TaskData t2 = results[0].tasks[1];
      System.assertEquals('Task 2', t2.subject);
      System.assert(t2.isComplete);
    }
  }

  @IsTest
  static void getAllActionPlanData_noContact() {
    ActionPlanController_TSB setup = ActionPlanController_TSB.newBuilder()
      .setGuardianName('No', 'Contact')
      .withNoContact()
      .getInstance();
    
    User u = setup.guardianUser;

    System.runAs(u) {
      Test.startTest();
      List<ActionPlanController.ActionPlanData> results = ActionPlanController.getAllActionPlanData();
      Test.stopTest();

      System.assertEquals(0, results.size(), 'Should return empty list for user without contact');
    }
  }

  @IsTest
  static void getAllActionPlanData_noAccount() {
    ActionPlanController_TSB setup = ActionPlanController_TSB.newBuilder()
      .setGuardianName('No', 'Account')
      .withNoAccount()
      .getInstance();

    User u = setup.guardianUser;

    System.runAs(u) {
      Test.startTest();
      List<ActionPlanController.ActionPlanData> results = ActionPlanController.getAllActionPlanData();
      Test.stopTest();

      System.assertEquals(0, results.size(), 'Should return empty list for contact without account');
    }
  }

  @IsTest
  static void getAllActionPlanData_noEnrollments() {
    ActionPlanController_TSB setup = ActionPlanController_TSB.newBuilder()
      .setGuardianName('No', 'Enrollment')
      .withNoStudents()
      .getInstance();

    User u = setup.guardianUser;

    System.runAs(u) {
      Test.startTest();
      List<ActionPlanController.ActionPlanData> results = ActionPlanController.getAllActionPlanData();
      Test.stopTest();

      System.assertEquals(0, results.size(), 'Should return empty list when no enrollments found');
    }
  }
  @IsTest
  static void getAllActionPlanData_registrationTaskFilter_1() {
    // 1. Welcome Phase -> should see Registration Task
    ActionPlanController_TSB setup1 = ActionPlanController_TSB.newBuilder()
      .setGuardianName('G1', 'Welcome')
      .setEnrollmentStatus('1. Welcome Phase')
      .getInstance();
    
    System.runAs(setup1.guardianUser) {
      System.assertEquals(2, ActionPlanController.getAllActionPlanData()[0].tasks.size(), 'Welcome Phase should see 2 tasks');
    }
  }

  @IsTest
  static void getAllActionPlanData_registrationTaskFilter_2() {
    // 2. Registration Phase -> should see Registration Task
    ActionPlanController_TSB setup2 = ActionPlanController_TSB.newBuilder()
      .setGuardianName('G2', 'Registration')
      .setEnrollmentStatus('2. Registration Phase')
      .getInstance();

    System.runAs(setup2.guardianUser) {
      System.assertEquals(2, ActionPlanController.getAllActionPlanData()[0].tasks.size(), 'Registration Phase should see 2 tasks');
    }
  }

  @IsTest
  static void getAllActionPlanData_registrationTaskFilter_3() {
    // 3. Other Phase -> should NOT see Registration Task
    ActionPlanController_TSB setup3 = ActionPlanController_TSB.newBuilder()
      .setGuardianName('G3', 'Other')
      .setEnrollmentStatus('3. ATS Phase')
      .getInstance();

    System.runAs(setup3.guardianUser) {
      Test.startTest();
      List<ActionPlanController.ActionPlanData> results = ActionPlanController.getAllActionPlanData();
      Test.stopTest();
      
      // Since '3. ATS Phase' has no tasks, it is filtered out by the controller.
      System.assertEquals(0, results.size(), 'Should return no data for student in ATS Phase without tasks');
    }
  }

  @IsTest
  static void getAllActionPlanData_registrationTaskFilter_empty() {
    // 3. Other Phase -> should NOT see Registration Task
    ActionPlanController_TSB setup3 = ActionPlanController_TSB.newBuilder()
      .setGuardianName('G4', 'Other')
      .setEnrollmentStatus('3. ATS Phase')
      .getInstance();

    System.runAs(setup3.guardianUser) {
      List<ActionPlanController.ActionPlanData> results = ActionPlanController.getAllActionPlanData();
      System.assertEquals(0, results.size(), 'Assessment Phase should return no action plan data when no tasks are applicable');
    }
  }

  @IsTest
  static void getAllActionPlanData_intentToReturnFilter() {
    // 1. Intent to Return Task with NULL Intent_To_Return__c -> should see
    ActionPlanController_TSB setup1 = ActionPlanController_TSB.newBuilder()
      .setGuardianName('G4', 'Intent')
      .setIntentToReturn(null)
      .getInstance();
    
    // Create Intent to Return Task
    insert new Task(
      WhatId = setup1.enrollment.Id,
      Type = 'Intent to Return',
      Subject = 'Intent Task',
      Status = 'Not Started'
    );

    // 2. Intent to Return Task with non-NULL Intent_To_Return__c -> should NOT see
    ActionPlanController_TSB setup2 = ActionPlanController_TSB.newBuilder()
      .setGuardianName('G5', 'NoIntent')
      .setIntentToReturn('Yes')
      .getInstance();

    insert new Task(
      WhatId = setup2.enrollment.Id,
      Type = 'Intent to Return',
      Subject = 'Intent Task',
      Status = 'Not Started'
    );

    System.runAs(setup1.guardianUser) {
      // By default TSB creates 2 Registration tasks, which will NOT be seen because default EnrollmentStatus in TSB is '2. Registration Phase'?
      // Wait, let me check default TSB EnrollmentStatus. I set it to '2. Registration Phase'.
      // So setup1 will see 2 Registration tasks + 1 Intent to Return task = 3 tasks.
      System.assertEquals(3, ActionPlanController.getAllActionPlanData()[0].tasks.size(), 'NULL Intent to Return should see Intent task');
    }
    System.runAs(setup2.guardianUser) {
      // setup2 has '2. Registration Phase' so it sees 2 Registration tasks, but NOT the Intent to Return task.
      System.assertEquals(2, ActionPlanController.getAllActionPlanData()[0].tasks.size(), 'Non-NULL Intent to Return should NOT see Intent task');
    }
  }

  @IsTest
  static void getAllActionPlanData_guardianTasks() {
    ActionPlanController_TSB setup = builder.getInstance();
    
    // Create a task for the guardian contact
    insert new Task(
      WhoId = setup.guardianUser.ContactId,
      Type = 'Parent Portal Task',
      Subject = 'Guardian Task',
      Status = 'Not Started'
    );

    System.runAs(setup.guardianUser) {
      Test.startTest();
      List<ActionPlanController.ActionPlanData> results = ActionPlanController.getAllActionPlanData();
      Test.stopTest();

      // results[0] should be guardian tasks, results[1] should be student tasks
      System.assertEquals(2, results.size(), 'Should return 2 sections: Guardian and Student');
      
      System.assertEquals('Guardian Account', results[0].studentName);
      System.assertEquals(Label.Action_Plan_Guardian_Tasks_Subtitle, results[0].programName);
      System.assertEquals(1, results[0].tasks.size(), 'Guardian section should have 1 task');
      System.assertEquals('Guardian Task', results[0].tasks[0].subject);

      System.assertEquals('Student Account', results[1].studentName);
      System.assertEquals(2, results[1].tasks.size(), 'Student section should have 2 tasks');
    }
  }
}