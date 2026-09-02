/**
 * Tests for {@link Preconditions}.
 */
@IsTest(IsParallel=true)
@SuppressWarnings('PMD.CyclomaticComplexity')
private class PreconditionsTest {
  @IsTest
  private static void checkArgument_false_throws() {
    Boolean expression = false;
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      Preconditions.checkArgument(expression);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkArgument_true_doesNotThrow() {
    Boolean expression = true;
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkArgument(expression);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkArgument_falseWithErrorMessage_throwsErrorMessage() {
    Boolean expression = false;
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      errorMessage
    );

    try {
      Preconditions.checkArgument(expression, errorMessage);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkArgument_trueWithErrorMessage_doesNotThrow() {
    Boolean expression = true;
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkArgument(expression, errorMessage);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkState_false_throws() {
    Boolean expression = false;
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalStateException.class);

    try {
      Preconditions.checkState(expression);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkState_true_doesNotThrow() {
    Boolean expression = true;
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkState(expression);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkState_falseWithErrorMessage_throwsErrorMessage() {
    Boolean expression = false;
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalStateException.class, errorMessage);

    try {
      Preconditions.checkState(expression, errorMessage);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkState_trueWithErrorMessage_doesNotThrow() {
    Boolean expression = true;
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkState(expression, errorMessage);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkNotNull_null_throws() {
    Object argument = null;
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      Preconditions.checkNotNull(argument);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotNull_notNull_doesNotThrow() {
    Object argument = true;
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkNotNull(argument);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkNotNull_nullWithErrorMessage_throwsErrorMessage() {
    Object argument = null;
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      errorMessage
    );

    try {
      Preconditions.checkNotNull(argument, errorMessage);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotNull_notNullWithErrorMessage_doesNotThrow() {
    Object argument = true;
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkNotNull(argument, errorMessage);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkNotBlank_null_throws() {
    String argument = null;
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      Preconditions.checkNotBlank(argument);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotBlank_blank_throws() {
    String argument = ' ';
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      Preconditions.checkNotBlank(argument);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotBlank_notBlank_doesNotThrow() {
    String argument = 'not blank';
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkNotBlank(argument);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkNotBlank_blankWithErrorMessage_throws() {
    String argument = ' ';
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      errorMessage
    );

    try {
      Preconditions.checkNotBlank(argument, errorMessage);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotEmpty_listIsNull_throws() {
    List<Object> collection = null;
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      Preconditions.checkNotEmpty(collection);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotEmpty_listIsEmpty_throws() {
    List<Object> collection = new List<Object>();
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      Preconditions.checkNotEmpty(collection);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotEmpty_listIsNotEmpty_doesNotThrow() {
    List<Object> collection = new List<Object>{ 1, 2, 3 };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkNotEmpty(collection);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkNotEmpty_listIsEmptyWithErrorMessage_throws() {
    List<Object> collection = new List<Object>();
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      errorMessage
    );

    try {
      Preconditions.checkNotEmpty(collection, errorMessage);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotEmpty_setIsNull_throws() {
    Set<Object> collection = null;
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      Preconditions.checkNotEmpty(collection);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotEmpty_setIsNotEmpty_doesNotThrow() {
    Set<Object> collection = new Set<Object>{ 1, 2, 3 };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkNotEmpty(collection);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkNotEmpty_setIsEmptyWithErrorMessage_throws() {
    Set<Object> collection = new Set<Object>();
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      errorMessage
    );

    try {
      Preconditions.checkNotEmpty(collection, errorMessage);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotEmpty_mapIsNull_throws() {
    Map<String, Object> collection = null;
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      Preconditions.checkNotEmpty(collection);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotEmpty_mapIsEmpty_throws() {
    Map<String, Object> collection = new Map<String, Object>();
    AssertThrows.Throwing throwing = AssertThrows.with(IllegalArgumentException.class);

    try {
      Preconditions.checkNotEmpty(collection);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkNotEmpty_mapIsNotEmpty_doesNotThrow() {
    Map<String, Object> collection = new Map<String, Object>{ 'foo' => 'bar' };
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkNotEmpty(collection);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkNotEmpty_mapIsEmptyWithErrorMessage_throws() {
    Map<String, Object> collection = new Map<String, Object>();
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      errorMessage
    );

    try {
      Preconditions.checkNotEmpty(collection, errorMessage);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkCollectionSize_listIsNull_throws() {
    List<Object> collection = null;
    Integer expectedSize = 1;
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Expected collection size to be 1, but the collection was null.'
    );

    try {
      Preconditions.checkCollectionSize(collection, expectedSize);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkCollectionSize_listDoesNotHaveExpectedSize_throws() {
    List<Object> collection = new List<Object>();
    Integer expectedSize = 1;
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      String.format(
        'Expected collection size to be {0}. Found {1}.',
        new List<Object>{ expectedSize, collection.size() }
      )
    );

    try {
      Preconditions.checkCollectionSize(collection, expectedSize);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkCollectionSize_listHasExpectedSize_doesNotThrow() {
    List<Object> collection = new List<Object>{ 1, 2, 3 };
    Integer expectedSize = 3;
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkCollectionSize(collection, expectedSize);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkCollectionSize_listDoesNotHaveExpectedSizeWithErrorMessage_throws() {
    List<Object> collection = new List<Object>();
    Integer expectedSize = 1;
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      errorMessage
    );

    try {
      Preconditions.checkCollectionSize(collection, expectedSize, errorMessage);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkCollectionSize_setDoesNotHaveExpectedSize_throws() {
    Set<Object> collection = new Set<Object>();
    Integer expectedSize = 1;
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      String.format(
        'Expected collection size to be {0}. Found {1}.',
        new List<Object>{ expectedSize, collection.size() }
      )
    );

    try {
      Preconditions.checkCollectionSize(collection, expectedSize);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkCollectionSize_setHasExpectedSize_doesNotThrow() {
    Set<Object> collection = new Set<Object>{ 1, 2, 3 };
    Integer expectedSize = 3;
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkCollectionSize(collection, expectedSize);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkCollectionSize_setDoesNotHaveExpectedSizeWithErrorMessage_throws() {
    Set<Object> collection = new Set<Object>();
    Integer expectedSize = 1;
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      errorMessage
    );

    try {
      Preconditions.checkCollectionSize(collection, expectedSize, errorMessage);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkCollectionSize_mapDoesNotHaveExpectedSize_throws() {
    Map<Object, Object> collection = new Map<Object, Object>();
    Integer expectedSize = 1;
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      String.format(
        'Expected collection size to be {0}. Found {1}.',
        new List<Object>{ expectedSize, collection.size() }
      )
    );

    try {
      Preconditions.checkCollectionSize(collection, expectedSize);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkCollectionSize_mapHasExpectedSize_doesNotThrow() {
    Map<Object, Object> collection = new Map<Object, Object>{ 'foo' => 'bar', 'baz' => 'bax' };
    Integer expectedSize = 2;
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkCollectionSize(collection, expectedSize);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkCollectionSize_mapDoesNotHaveExpectedSizeWithErrorMessage_throws() {
    Map<Object, Object> collection = new Map<Object, Object>();
    Integer expectedSize = 1;
    String errorMessage = 'missing value';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      errorMessage
    );

    try {
      Preconditions.checkCollectionSize(collection, expectedSize, errorMessage);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkSObjectFoundById_idIsBlank_throws() {
    SObject sobj = new Account();
    Id id = null;
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Expected an Id to be provided. Found null.'
    );

    try {
      Preconditions.checkSObjectFoundById(sobj, id);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkSObjectFoundById_sobjectIsNull_throws() {
    SObject sobj = null;
    Id id = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      String.format(
        'Expected to find Account with Id "{0}". Found {1}.',
        new List<Object>{ id, sobj }
      )
    );

    try {
      Preconditions.checkSObjectFoundById(sobj, id);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkSObjectFoundById_hasIdAndSobject_doesNotThrow() {
    SObject sobj = new Account();
    Id id = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkSObjectFoundById(sobj, id);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }

  @IsTest
  private static void checkSObjectFoundByField_withSObjectField_throwsExpectedErrorMessage() {
    SObject sobj = null;
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      String.format(
        'Expected to find Opportunity with AccountId "{0}". Found null.',
        new List<Object>{ accountId }
      )
    );

    try {
      Preconditions.checkSObjectFoundByField(
        sobj,
        accountId,
        Schema.Opportunity.SObjectType,
        Schema.Opportunity.AccountId
      );
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkSObjectFoundByField_withSObjectFieldReference_throwsExpectedErrorMessage() {
    SObject sobj = null;
    Id accountId = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      String.format(
        'Expected to find Opportunity with Account.ParentId "{0}". Found null.',
        new List<Object>{ accountId }
      )
    );

    try {
      Preconditions.checkSObjectFoundByField(
        sobj,
        accountId,
        Schema.Opportunity.SObjectType,
        SObjectFieldReference.create('Account.ParentId')
      );
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkSObjectFoundByName_sobjectIsNull_throws() {
    SObject sobj = null;
    SObjectType sobjectType = Schema.Account.SObjectType;
    String name = 'Test Account';
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      String.format(
        'Expected to find {0} with name "{1}". Found {2}.',
        new List<Object>{ sobjectType, name, sobj }
      )
    );

    try {
      Preconditions.checkSObjectFoundByName(sobj, sobjectType, name);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkIdIsSObjectType_withNullId_throws() {
    Id id = null;
    SObjectType sobjectType = Schema.Account.SObjectType;
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Expected the Id to have an SObjectType of Account. Received null, which has an SObjectType of null.'
    );

    try {
      Preconditions.checkIdIsSObjectType(id, sobjectType);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkIdIsSObjectType_withNonMatchingId_throws() {
    Id id = SObjectIds.generateFakeId(Schema.Opportunity.SObjectType);
    SObjectType sobjectType = Schema.Account.SObjectType;
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      String.format(
        'Expected the Id to have an SObjectType of Account. Received {0}, which has an SObjectType of Opportunity.',
        new List<Object>{ id }
      )
    );

    try {
      Preconditions.checkIdIsSObjectType(id, sobjectType);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void checkIdIsSObjectType_withMatchingId_doesNotThrow() {
    Id id = SObjectIds.generateFakeId(Schema.Account.SObjectType);
    SObjectType sobjectType = Schema.Account.SObjectType;
    AssertThrows.Throwing throwing = AssertThrows.doesNotThrow();

    try {
      Preconditions.checkIdIsSObjectType(id, sobjectType);
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasNotThrown();
  }
}