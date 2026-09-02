/**
 * Represents the result of comparing two {@link Object}s.
 */
public with sharing class ObjectDiffResponse {
  private final ObjectDiffResponseType responseType;

  private ObjectDiffResponse(Builder builder) {
    this.responseType = builder.responseType;
  }

  public ObjectDiffResponseType getResponseType() {
    return responseType;
  }

  public Boolean isDifferent() {
    Set<ObjectDiffResponseType> differentTypes = new Set<ObjectDiffResponseType>{
      ObjectDiffResponseType.OBJECTS_ARE_DIFFERENT,
      ObjectDiffResponseType.ONE_OBJECT_IS_NULL
    };

    return differentTypes.contains(responseType);
  }

  public static Builder newBuilder() {
    return new Builder();
  }

  public Builder toBuilder() {
    return new Builder().setResponseType(this.responseType);
  }

  public class Builder {
    private ObjectDiffResponseType responseType;

    public Builder setResponseType(ObjectDiffResponseType responseType) {
      this.responseType = responseType;
      return this;
    }

    public ObjectDiffResponse build() {
      return new ObjectDiffResponse(this);
    }
  }
}