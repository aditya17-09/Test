public with sharing class InterestedPropertiesController {
    @AuraEnabled(cacheable=true)
    public static List<PropertyWrapper> getInterestedProperties() {
        try {
            Id userId = UserInfo.getUserId();
            System.debug('UserId: ' + userId);

            // Query interactions for Inquired by the user
            List<Client_Property_Interaction__c> interactions = [
                SELECT Property__c
                FROM Client_Property_Interaction__c
                WHERE Interaction_Type__c = 'Inquired' AND CreatedById = :userId
                WITH SECURITY_ENFORCED
            ];
            System.debug('Interactions found: ' + interactions);

            Set<Id> propertyIds = new Set<Id>();
            for (Client_Property_Interaction__c interaction : interactions) {
                if (interaction.Property__c != null) {
                    propertyIds.add(interaction.Property__c);
                }
            }
            System.debug('Property IDs: ' + propertyIds);

            if (propertyIds.isEmpty()) {
                System.debug('No properties found. Returning empty list.');
                return new List<PropertyWrapper>();
            }

            // Fetch properties
            List<Property__c> properties = [
                SELECT Id, Name, Address__c, Price__c, Property_Type__c, Bedrooms__c, 
                       Square_Footage__c, Photos__c, Owner__c
                FROM Property__c
                WHERE Id IN :propertyIds
                WITH SECURITY_ENFORCED
            ];
            System.debug('Properties found: ' + properties);

            // Fetch owners
            Set<Id> ownerIds = new Set<Id>();
            for (Property__c prop : properties) {
                if (prop.Owner__c != null) {
                    ownerIds.add(prop.Owner__c);
                }
            }
            Map<Id, Property_Owner__c> propertyOwners = new Map<Id, Property_Owner__c>(
                [SELECT Id, Name__c, Phone__c, Email__c, Address__c
                 FROM Property_Owner__c
                 WHERE Id IN :ownerIds
                 WITH SECURITY_ENFORCED]
            );
            System.debug('Owners found: ' + propertyOwners.keySet());

            // Build wrappers
            List<PropertyWrapper> wrappers = new List<PropertyWrapper>();
            for (Property__c prop : properties) {
                PropertyWrapper wrapper = new PropertyWrapper();
                wrapper.propertyData = prop;
                wrapper.ImageUrl = String.isBlank(prop.Photos__c) ? '' : prop.Photos__c;
                wrapper.ownerData = propertyOwners.get(prop.Owner__c);
                wrappers.add(wrapper);
            }
            System.debug('Wrappers created: ' + wrappers.size());

            return wrappers;
        } catch (Exception e) {
            System.debug('Exception: ' + e.getMessage() + ' at line ' + e.getLineNumber());
            return new List<PropertyWrapper>();
        }
    }

    public class PropertyWrapper {
        @AuraEnabled public Property__c propertyData;
        @AuraEnabled public String ImageUrl;
        @AuraEnabled public Property_Owner__c ownerData;
    }
}