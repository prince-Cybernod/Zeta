/**
 * Tests for {@link SObjectFieldCriteriaEvaluatorImpl}.
 */
@IsTest(IsParallel=true)
private class SObjectFieldCriteriaEvaluatorImplTest {
  private static final SObjectFieldCriteriaEvaluator EVALUATOR;

  static {
    EVALUATOR = new SObjectFieldCriteriaEvaluatorImpl();
  }

  @IsTest
  private static void evaluate_criteriaMet_returnsTrue() {
    SObject_Field_Criteria__mdt criteria = buildFieldCriteria(
      'Test Criteria',
      'Name = "Test Account"',
      'Account'
    );
    Account testAccount = new Account(Name = 'Test Account');

    Boolean result = EVALUATOR.evaluate(criteria, testAccount);

    Assert.isTrue(result, 'Criteria should evaluate to true');
  }

  @IsTest
  private static void evaluate_criteriaNotMet_returnsFalse() {
    SObject_Field_Criteria__mdt criteria = buildFieldCriteria(
      'Test Criteria',
      'Name = "Test Account"',
      'Account'
    );
    Account testAccount = new Account(Name = 'Different Name');

    Boolean result = EVALUATOR.evaluate(criteria, testAccount);

    Assert.isFalse(result, 'Criteria should evaluate to false');
  }

  @IsTest
  private static void getReferencedFields_validFormula_returnsFieldNames() {
    SObject_Field_Criteria__mdt criteria = buildFieldCriteria(
      'Test Criteria',
      'Name = "Test"',
      'Account'
    );

    Set<String> fields = EVALUATOR.getReferencedFields(criteria);

    Assert.isTrue(fields.contains('Name'), 'Should reference Name field');
  }

  @IsTest
  private static void evaluate_nullSObject_throws() {
    SObject_Field_Criteria__mdt criteria = buildFieldCriteria(
      'Test Criteria',
      'Name = "Test"',
      'Account'
    );
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'SObject cannot be null'
    );

    try {
      EVALUATOR.evaluate(criteria, null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void evaluate_nullCriteria_throws() {
    Account testAccount = new Account(Name = 'Test');
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Criteria cannot be null'
    );

    try {
      EVALUATOR.evaluate(null, testAccount);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void evaluate_blankFormula_throws() {
    SObject_Field_Criteria__mdt criteria = (SObject_Field_Criteria__mdt) ReadOnlySObject.create(
      new SObject_Field_Criteria__mdt(MasterLabel = 'Test', Formula_Expression__c = ''),
      new Map<String, Object>{ 'Entity_Definition__r' => buildEntityDefinition('Account') }
    );
    Account testAccount = new Account(Name = 'Test');
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Formula Expression cannot be blank'
    );

    try {
      EVALUATOR.evaluate(criteria, testAccount);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void evaluate_blankEntityDefinition_throws() {
    SObject_Field_Criteria__mdt criteria = (SObject_Field_Criteria__mdt) ReadOnlySObject.create(
      new SObject_Field_Criteria__mdt(
        MasterLabel = 'Test',
        Formula_Expression__c = 'Name = "Test"'
      ),
      new Map<String, Object>{}
    );
    Account testAccount = new Account(Name = 'Test');
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Entity Definition cannot be blank'
    );

    try {
      EVALUATOR.evaluate(criteria, testAccount);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void evaluate_invalidEntityType_throws() {
    SObject_Field_Criteria__mdt criteria = buildFieldCriteria(
      'Test Criteria',
      'Name = "Test"',
      'InvalidObject__c'
    );
    Account testAccount = new Account(Name = 'Test');
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Failed to evaluate criteria "Test Criteria": Formula type cannot be null'
    );

    try {
      EVALUATOR.evaluate(criteria, testAccount);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getReferencedFields_nullCriteria_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Criteria cannot be null'
    );

    try {
      EVALUATOR.getReferencedFields(null);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getReferencedFields_blankFormula_throws() {
    SObject_Field_Criteria__mdt criteria = (SObject_Field_Criteria__mdt) ReadOnlySObject.create(
      new SObject_Field_Criteria__mdt(MasterLabel = 'Test', Formula_Expression__c = ''),
      new Map<String, Object>{ 'Entity_Definition__r' => buildEntityDefinition('Account') }
    );
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Formula Expression cannot be blank'
    );

    try {
      EVALUATOR.getReferencedFields(criteria);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getReferencedFields_blankEntityDefinition_throws() {
    SObject_Field_Criteria__mdt criteria = (SObject_Field_Criteria__mdt) ReadOnlySObject.create(
      new SObject_Field_Criteria__mdt(
        MasterLabel = 'Test',
        Formula_Expression__c = 'Name = "Test"'
      ),
      new Map<String, Object>{}
    );
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Entity Definition cannot be blank'
    );

    try {
      EVALUATOR.getReferencedFields(criteria);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getReferencedFields_multiFieldFormula_returnsAllFields() {
    SObject_Field_Criteria__mdt criteria = buildFieldCriteria(
      'Test Criteria',
      'Name = "Test" && Description = "Foo"',
      'Account'
    );

    Set<String> fields = EVALUATOR.getReferencedFields(criteria);

    Assert.isTrue(fields.contains('Name'), 'Should reference Name field');
    Assert.isTrue(fields.contains('Description'), 'Should reference Description field');
  }

  @IsTest
  private static void evaluate_multiFieldFormula_evaluatesCorrectly() {
    SObject_Field_Criteria__mdt criteria = buildFieldCriteria(
      'Test Criteria',
      'Name = "Test" && Description = "Foo"',
      'Account'
    );
    Account matchingAccount = new Account(Name = 'Test', Description = 'Foo');
    Account partialAccount = new Account(Name = 'Test', Description = 'Bar');

    Assert.isTrue(
      EVALUATOR.evaluate(criteria, matchingAccount),
      'Both fields match, should be true'
    );
    Assert.isFalse(
      EVALUATOR.evaluate(criteria, partialAccount),
      'Only one field matches, should be false'
    );
  }

  @IsTest
  private static void getReferencedFields_invalidEntityType_throws() {
    SObject_Field_Criteria__mdt criteria = buildFieldCriteria(
      'Test Criteria',
      'Name = "Test"',
      'InvalidObject__c'
    );
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Failed to get referenced fields for criteria "Test Criteria": Formula type cannot be null'
    );

    try {
      EVALUATOR.getReferencedFields(criteria);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  private static EntityDefinition buildEntityDefinition(String qualifiedApiName) {
    return (EntityDefinition) ReadOnlySObject.create(
      new EntityDefinition(),
      new Map<String, Object>{ 'QualifiedApiName' => qualifiedApiName }
    );
  }

  private static SObject_Field_Criteria__mdt buildFieldCriteria(
    String masterLabel,
    String formulaExpression,
    String entityName
  ) {
    return (SObject_Field_Criteria__mdt) ReadOnlySObject.create(
      new SObject_Field_Criteria__mdt(
        MasterLabel = masterLabel,
        Formula_Expression__c = formulaExpression
      ),
      new Map<String, Object>{ 'Entity_Definition__r' => buildEntityDefinition(entityName) }
    );
  }
}