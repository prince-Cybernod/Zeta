/**
 * Represents the response to a {@link SObjectFieldDiffRequest}.
 */
public inherited sharing class SObjectFieldDiffResponse {
  private final SObjectFieldDiffResponseType responseType;
  private final List<SObjectFieldReference> differences;

  private SObjectFieldDiffResponse(Builder builder) {
    this.responseType = builder.responseType;
    this.differences = builder.differences;
  }

  /**
   * Returns the type of response.
   */
  public SObjectFieldDiffResponseType getResponseType() {
    return responseType;
  }

  /**
   * Returns the {@link SObjectFieldReference}s that differ between the two {@link SObject}s.
   */
  public List<SObjectFieldReference> getDifferences() {
    return differences;
  }

  /**
   * Returns {@code true} if the response indicates that the two {@link SObject}s differ.
   */
  public Boolean isDifferent() {
    Set<SObjectFieldDiffResponseType> differentTypes = new Set<SObjectFieldDiffResponseType>{
      SObjectFieldDiffResponseType.FIELDS_ARE_DIFFERENT,
      SObjectFieldDiffResponseType.ONE_SOBJECT_IS_NULL
    };

    return differentTypes.contains(responseType);
  }

  public static Builder newBuilder() {
    return new Builder();
  }

  public Builder toBuilder() {
    return new Builder().setResponseType(responseType).setDifferences(differences);
  }

  public class Builder {
    private SObjectFieldDiffResponseType responseType;
    private List<SObjectFieldReference> differences = new List<SObjectFieldReference>();

    public Builder setResponseType(SObjectFieldDiffResponseType responseType) {
      this.responseType = responseType;
      return this;
    }

    public Builder setDifferences(List<SObjectFieldReference> differences) {
      this.differences = differences;
      return this;
    }

    public Builder addDifference(SObjectFieldReference difference) {
      this.differences.add(difference);
      return this;
    }

    public Builder addAllDifferences(List<SObjectFieldReference> differences) {
      this.differences.addAll(differences);
      return this;
    }

    public SObjectFieldDiffResponse build() {
      return new SObjectFieldDiffResponse(this);
    }
  }
}