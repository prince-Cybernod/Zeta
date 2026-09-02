public without sharing class ActionPlanController {
  @AuraEnabled(Cacheable=true)
  public static List<ActionPlanData> getAllActionPlanData() {
    Id contactId = [SELECT ContactId FROM User WHERE Id = :UserInfo.getUserId()].ContactId;
    if (contactId == null) {
      return new List<ActionPlanData>();
    }

    Contact currentContact = [SELECT Id, AccountId, Name FROM Contact WHERE Id = :contactId];
    Id accountId = currentContact.AccountId;
    if (accountId == null) {
      return new List<ActionPlanData>();
    }

    List<AcademicTermEnrollment> enrollments = [
      SELECT Id, LearnerContact.Account.Name, Learning_Program__r.Name, EnrollmentStatus,
        Intent_To_Return__c
      FROM AcademicTermEnrollment
      WHERE LearnerAccountId IN (
        SELECT Id
        FROM Account
        WHERE Primary_Guardian__c = :accountId
      )
    ];

    Set<Id> registrationEnrollmentIds = new Set<Id>();
    Set<Id> intentEnrollmentIds = new Set<Id>();
    for (AcademicTermEnrollment e : enrollments) {
      if (e.EnrollmentStatus == '1. Welcome Phase' || e.EnrollmentStatus == '2. Registration Phase') {
        registrationEnrollmentIds.add(e.Id);
      }
      if (e.Intent_To_Return__c == null) {
        intentEnrollmentIds.add(e.Id);
      }
    }

    Map<Id, List<Task>> tasksByEnrollmentId = new Map<Id, List<Task>>();
    List<Task> guardianTasks = new List<Task>();

    for (Task t : [
      SELECT Id, Subject, Status, Form_URL__c, WhatId, WhoId, ActivityDate, Type
      FROM Task
      WHERE (
        WhatId IN :enrollments
        OR WhoId = :contactId
      )
      AND Status != 'Rescinded'
      ORDER BY Subject ASC
    ]) {
      // Logic for Guardian Tasks
      if (t.WhoId == contactId && t.Type == 'Parent Portal Task') {
        guardianTasks.add(t);
        continue;
      }

      // Logic for Student Tasks (Enrollment associated)
      if (
        (t.Type == 'Registration Task' && registrationEnrollmentIds.contains(t.WhatId))
        || (t.Type == 'Intent to Return' && intentEnrollmentIds.contains(t.WhatId))
        || (t.Type == 'Parent Portal Task' && t.Status != 'Completed')
      ) {
        if (!tasksByEnrollmentId.containsKey(t.WhatId)) {
          tasksByEnrollmentId.put(t.WhatId, new List<Task>());
        }
        tasksByEnrollmentId.get(t.WhatId).add(t);
      }
    }

    List<ActionPlanData> results = new List<ActionPlanData>();

    // Add Guardian section at the top if there are tasks
    if (!guardianTasks.isEmpty()) {
      results.add(new ActionPlanData(
        currentContact.Name,
        Label.Action_Plan_Guardian_Tasks_Subtitle,
        guardianTasks
      ));
    }

    for (AcademicTermEnrollment enrollment : enrollments) {
      List<Task> tasks = tasksByEnrollmentId.containsKey(enrollment.Id)
        ? tasksByEnrollmentId.get(enrollment.Id)
        : new List<Task>();
      
      if (!tasks.isEmpty()) {
        results.add(new ActionPlanData(enrollment, tasks));
      }
    }

    return results;
  }

  public class ActionPlanData {
    @AuraEnabled public String studentName;
    @AuraEnabled public String programName;
    @AuraEnabled public List<TaskData> tasks;

    public ActionPlanData(String studentName, String programName, List<Task> taskList) {
      this.studentName = studentName;
      this.programName = programName;
      this.tasks = new List<TaskData>();
      for (Task t : taskList) {
        this.tasks.add(new TaskData(t));
      }
    }

    public ActionPlanData(AcademicTermEnrollment enrollment, List<Task> taskList) {
      this(
        enrollment.LearnerContact.Account.Name,
        enrollment.Learning_Program__r?.Name,
        taskList
      );
    }
  }

  public class TaskData {
    @AuraEnabled public Id id;
    @AuraEnabled public String subject;
    @AuraEnabled public Boolean isComplete;
    @AuraEnabled public String formUrl;
    @AuraEnabled public Date dueDate;

    public TaskData(Task t) {
      this.id = t.Id;
      this.subject = t.Subject;
      this.isComplete = t.Status == 'Completed';
      this.formUrl = t.Form_URL__c != null ? t.Form_URL__c + '&taskId=' + t.Id : null;
      this.dueDate = t.ActivityDate;
    }
  }
}