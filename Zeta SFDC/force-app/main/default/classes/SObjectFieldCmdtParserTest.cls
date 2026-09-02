/**
 * Tests for {@link SObjectFieldCmdtParser}.
 */
@IsTest(IsParallel=true)
private class SObjectFieldCmdtParserTest {
  @IsTest
  private static void getSObjectField_withFieldDefinition_returnsSObjectField() {
    SObject_Field__mdt fieldMetadata = buildFieldMetadata('Account', 'Name');

    SObjectField result = SObjectFieldCmdtParser.getSObjectField(fieldMetadata);

    Assert.areEqual(Schema.Account.Name, result);
  }

  @IsTest
  private static void getSObjectField_withEntityParticle_returnsSObjectField() {
    SObject_Field__mdt fieldMetadata = buildFieldMetadataWithEntityParticle('Account', 'Name');

    SObjectField result = SObjectFieldCmdtParser.getSObjectField(fieldMetadata);

    Assert.areEqual(Schema.Account.Name, result);
  }

  @IsTest
  private static void getSObjectField_withQualifiedFieldName_returnsSObjectField() {
    SObject_Field__mdt fieldMetadata = buildFieldMetadata('Account', 'Account.Name');

    SObjectField result = SObjectFieldCmdtParser.getSObjectField(fieldMetadata);

    Assert.areEqual(Schema.Account.Name, result);
  }

  @IsTest
  private static void getSObjectType_withValidMetadata_returnsSObjectType() {
    SObject_Field__mdt fieldMetadata = buildFieldMetadata('Account', 'Name');

    SObjectType result = SObjectFieldCmdtParser.getSObjectType(fieldMetadata);

    Assert.areEqual(Schema.Account.SObjectType, result);
  }

  @IsTest
  private static void getSObjectField_withNullMetadata_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'SObject Field CMDT cannot be null'
    );

    try {
      SObjectFieldCmdtParser.getSObjectField(null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getSObjectType_withNullMetadata_throws() {
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'SObject Field CMDT cannot be null'
    );

    try {
      SObjectFieldCmdtParser.getSObjectType(null);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getSObjectType_withMissingEntityDefinition_throws() {
    SObject_Field__mdt fieldMetadata = new SObject_Field__mdt();
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Must have an Entity Definition'
    );

    try {
      SObjectFieldCmdtParser.getSObjectType(fieldMetadata);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getSObjectField_withMissingFieldDefinitionAndEntityParticle_throws() {
    SObject_Field__mdt fieldMetadata = buildFieldMetadataWithoutField('Account');
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Must have a Field Definition or Entity Particle'
    );

    try {
      SObjectFieldCmdtParser.getSObjectField(fieldMetadata);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getSObjectField_withInvalidFieldName_throws() {
    SObject_Field__mdt fieldMetadata = buildFieldMetadata('Account', 'InvalidFieldName__x');
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'Field InvalidFieldName__x not found on Account'
    );

    try {
      SObjectFieldCmdtParser.getSObjectField(fieldMetadata);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  @IsTest
  private static void getSObjectType_withInvalidSObjectName_throws() {
    SObject_Field__mdt fieldMetadata = buildFieldMetadata('InvalidSObject__x', 'Name');
    AssertThrows.Throwing throwing = AssertThrows.with(
      IllegalArgumentException.class,
      'SObjectType must have a value. Found null'
    );

    try {
      SObjectFieldCmdtParser.getSObjectType(fieldMetadata);
      throwing.shouldHaveThrown();
    } catch (Exception e) {
      throwing.threw(e);
    }

    throwing.assertHasThrown();
  }

  private static SObject_Field__mdt buildFieldMetadata(String sobjectName, String fieldName) {
    return (SObject_Field__mdt) ReadOnlySObject.create(
      new SObject_Field__mdt(),
      new Map<String, Object>{
        'Entity_Definition__r' => buildEntityDefinition(sobjectName),
        'Field_Definition__r' => buildFieldDefinition(fieldName)
      }
    );
  }

  private static SObject_Field__mdt buildFieldMetadataWithEntityParticle(
    String sobjectName,
    String fieldName
  ) {
    return (SObject_Field__mdt) ReadOnlySObject.create(
      new SObject_Field__mdt(),
      new Map<String, Object>{
        'Entity_Definition__r' => buildEntityDefinition(sobjectName),
        'Entity_Particle__r' => buildEntityParticle(fieldName)
      }
    );
  }

  private static SObject_Field__mdt buildFieldMetadataWithoutField(String sobjectName) {
    return (SObject_Field__mdt) ReadOnlySObject.create(
      new SObject_Field__mdt(),
      new Map<String, Object>{ 'Entity_Definition__r' => buildEntityDefinition(sobjectName) }
    );
  }

  private static EntityDefinition buildEntityDefinition(String qualifiedApiName) {
    return (EntityDefinition) ReadOnlySObject.create(
      new EntityDefinition(),
      new Map<String, Object>{ 'QualifiedApiName' => qualifiedApiName }
    );
  }

  private static FieldDefinition buildFieldDefinition(String qualifiedApiName) {
    return (FieldDefinition) ReadOnlySObject.create(
      new FieldDefinition(),
      new Map<String, Object>{ 'QualifiedApiName' => qualifiedApiName }
    );
  }

  private static EntityParticle buildEntityParticle(String qualifiedApiName) {
    return (EntityParticle) ReadOnlySObject.create(
      new EntityParticle(),
      new Map<String, Object>{ 'QualifiedApiName' => qualifiedApiName }
    );
  }
}