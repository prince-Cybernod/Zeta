/**
 * Tests for {@link LabelResolver}.
 */
@IsTest(IsParallel=true)
private class LabelResolverTest {
  @IsTest
  private static void resolve_withKnownLabel_returnsValue() {
    String result = LabelResolver.resolve('AppUI_FieldName');

    Assert.areEqual('Name', result, 'Should resolve known Custom Label to its value');
  }

  @IsTest
  private static void resolve_withBlankInput_returnsBlank() {
    Assert.areEqual(null, LabelResolver.resolve(null), 'Should return null for null input');
    Assert.areEqual('', LabelResolver.resolve(''), 'Should return empty for empty input');
    Assert.areEqual('  ', LabelResolver.resolve('  '), 'Should return whitespace for whitespace input');
  }

  @IsTest
  private static void resolve_withUnknownLabel_returnsInput() {
    String result = LabelResolver.resolve('Not_A_Real_Label_Name');

    Assert.areEqual('Not_A_Real_Label_Name', result, 'Should return input when label not found');
  }
}