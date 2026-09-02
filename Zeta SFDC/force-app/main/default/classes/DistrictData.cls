/**
 * Synthetic-record builders for district-assignment tests.
 */
@IsTest
public class DistrictData {
  public static IndividualApplication appWithAccount(
    Id appId,
    Id accountId,
    String status,
    Decimal lat,
    Decimal lng
  ) {
    return (IndividualApplication) ReadOnlySObject.create(
      IndividualApplication.SObjectType,
      new Map<String, Object>{
        'Id' => appId,
        'AccountId' => accountId,
        'Account' => new Map<String, Object>{
          'Id' => accountId,
          'Geocoding_Status__c' => status,
          'Geocoding_Latitude__c' => lat,
          'Geocoding_Longitude__c' => lng
        }
      }
    );
  }

  public static District__c district(
    Id districtId,
    String key,
    Decimal minLng,
    Decimal maxLng,
    Decimal minLat,
    Decimal maxLat
  ) {
    return (District__c) ReadOnlySObject.create(
      District__c.SObjectType,
      new Map<String, Object>{
        'Id' => districtId,
        'District_Id__c' => key,
        'Min_Lng__c' => minLng,
        'Max_Lng__c' => maxLng,
        'Min_Lat__c' => minLat,
        'Max_Lat__c' => maxLat
      }
    );
  }

  public static District_Ring__c ring(
    Id districtId,
    String role,
    Decimal minLng,
    Decimal maxLng,
    Decimal minLat,
    Decimal maxLat,
    String polygonJson
  ) {
    return (District_Ring__c) ReadOnlySObject.create(
      District_Ring__c.SObjectType,
      new Map<String, Object>{
        'District__c' => districtId,
        'Ring_Role__c' => role,
        'Ring_Order__c' => 1,
        'Min_Lng__c' => minLng,
        'Max_Lng__c' => maxLng,
        'Min_Lat__c' => minLat,
        'Max_Lat__c' => maxLat,
        'Polygon_Coordinates__c' => polygonJson
      }
    );
  }
}