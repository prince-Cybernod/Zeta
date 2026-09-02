/**
 * Builds and returns an object that cannot be constructed.
 */
public with sharing class ReadOnlyObject {
  /**
   * Creates the object with the given field values.
   */
  public static Object create(Type clazz, Map<String, Object> fieldValues) {
    return JSON.deserialize(JSON.serialize(fieldValues), clazz);
  }

  /**
   * Returns a new builder to build an object with the given class.
   */
  public static Builder newBuilder(Type clazz) {
    return new Builder(clazz);
  }

  public class Builder {
    private final Type clazz;
    private final Map<String, Object> fieldValues = new Map<String, Object>();

    public Builder put(String fieldName, Object value) {
      fieldValues.put(fieldName, value);
      return this;
    }

    public Builder putAll(Map<String, Object> fieldValues) {
      this.fieldValues.putAll(fieldValues);
      return this;
    }

    public Object build() {
      return create(clazz, fieldValues);
    }

    private Builder(Type clazz) {
      this.clazz = clazz;
    }
  }

  private ReadOnlyObject() {
  }
}