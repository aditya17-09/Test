public with sharing class SavePropertyController {
    @AuraEnabled
    public static String createProperty(
        String name,
        String address,
        Decimal price,
        String propertyType,
        String bedrooms,
        String status,
        Decimal squareFootage,
        String contentDocumentId,
        List<String> amenities,
        String leaseTerms,
        String ownerName,
        String ownerPhone,
        String ownerEmail,
        String ownerAddress,
        String ownerType
    ) {
        try {
            // Validate required fields
            if (String.isBlank(name)) throw new AuraHandledException('Property Name is required.');
            if (String.isBlank(address)) throw new AuraHandledException('Property Address is required.');
            if (price == null) throw new AuraHandledException('Property Price is required.');
            if (String.isBlank(propertyType)) throw new AuraHandledException('Property Type is required.');
            if (String.isBlank(bedrooms)) throw new AuraHandledException('Bedrooms is required.');
            if (String.isBlank(ownerName)) throw new AuraHandledException('Owner Name is required.');
            if (String.isBlank(ownerEmail)) throw new AuraHandledException('Owner Email is required.');
            if (String.isBlank(ownerType)) throw new AuraHandledException('Owner Type is required.');

            // Validate picklist values
            Set<String> validPropertyTypes = getPicklistValues('Property__c', 'Property_Type__c');
            if (!validPropertyTypes.contains(propertyType)) throw new AuraHandledException('Invalid Property Type: ' + propertyType);
            Set<String> validBedrooms = getPicklistValues('Property__c', 'Bedrooms__c');
            if (!validBedrooms.contains(bedrooms)) throw new AuraHandledException('Invalid Bedrooms: ' + bedrooms);
            Set<String> validStatus = getPicklistValues('Property__c', 'Status__c');
            String finalStatus = String.isBlank(status) ? 'Available' : status;
            if (!validStatus.contains(finalStatus)) throw new AuraHandledException('Invalid Status: ' + finalStatus);
            Set<String> validOwnerTypes = getPicklistValues('Property_Owner__c', 'Type__c');
            if (!validOwnerTypes.contains(ownerType)) throw new AuraHandledException('Invalid Owner Type: ' + ownerType);

            // Check for existing Property_Owner__c for the current user
            Id userId = UserInfo.getUserId();
            List<Property_Owner__c> existingOwners = [
                SELECT Id
                FROM Property_Owner__c
                WHERE User__c = :userId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            Property_Owner__c owner;
            if (existingOwners.isEmpty()) {
                owner = new Property_Owner__c(
                    Name__c = ownerName,
                    Phone__c = ownerPhone,
                    Email__c = ownerEmail,
                    Address__c = ownerAddress,
                    Type__c = ownerType,
                    User__c = userId
                );
                insert owner;
            } else {
                owner = existingOwners[0];
            }

            // Handle property image
            String photosValue = '';
            if (String.isNotBlank(contentDocumentId)) {
                List<ContentVersion> cvList = [
                    SELECT Id, ContentDocumentId
                    FROM ContentVersion
                    WHERE ContentDocumentId = :contentDocumentId AND IsLatest = true
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
                if (!cvList.isEmpty()) {
                    ContentVersion cv = cvList[0];
                    photosValue = '<img src="/sfc/servlet.shepherd/version/download/' + cv.Id + '" alt="Property Image" style="max-width:100%;height:auto;"/>';
                    // Ensure ContentDocumentLink exists
                    List<ContentDocumentLink> existingLinks = [
                        SELECT Id
                        FROM ContentDocumentLink
                        WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId = :owner.Id
                        WITH SECURITY_ENFORCED
                        LIMIT 1
                    ];
                    if (existingLinks.isEmpty()) {
                        ContentDocumentLink cdl = new ContentDocumentLink(
                            ContentDocumentId = contentDocumentId,
                            LinkedEntityId = owner.Id,
                            ShareType = 'V',
                            Visibility = 'AllUsers'
                        );
                        insert cdl;
                    }
                } else {
                    System.debug('No ContentVersion found for ContentDocumentId: ' + contentDocumentId);
                }
            }

            // Format amenities
            String amenitiesValue = amenities != null && !amenities.isEmpty() ? String.join(amenities, ';') : null;

            // Create and insert Property
            Property__c prop = new Property__c(
                Name = name,
                Address__c = address,
                Price__c = price,
                Property_Type__c = propertyType,
                Bedrooms__c = bedrooms,
                Status__c = finalStatus,
                Square_Footage__c = squareFootage,
                Photos__c = photosValue,
                Amenities__c = amenitiesValue,
        Lease_Terms__c = leaseTerms,
                Owner__c = owner.Id
            );
            insert prop;

            // Link ContentDocument to Property
            if (String.isNotBlank(contentDocumentId)) {
                List<ContentDocumentLink> existingPropLinks = [
                    SELECT Id
                    FROM ContentDocumentLink
                    WHERE ContentDocumentId = :contentDocumentId AND LinkedEntityId = :prop.Id
                    WITH SECURITY_ENFORCED
                    LIMIT 1
                ];
                if (existingPropLinks.isEmpty()) {
                    ContentDocumentLink cdl = new ContentDocumentLink(
                        ContentDocumentId = contentDocumentId,
                        LinkedEntityId = prop.Id,
                        ShareType = 'V',
                        Visibility = 'AllUsers'
                    );
                    insert cdl;
                }
            }

            return prop.Id;
        } catch (Exception e) {
            throw new AuraHandledException('Error saving property: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<PropertyWrapper> getOwnerProperties() {
        try {
            Id userId = UserInfo.getUserId();
            List<Property_Owner__c> owners = [
                SELECT Id
                FROM Property_Owner__c
                WHERE User__c = :userId
                WITH SECURITY_ENFORCED
            ];
            if (owners.isEmpty()) {
                return new List<PropertyWrapper>();
            }
            Set<Id> ownerIds = new Set<Id>();
            for (Property_Owner__c owner : owners) {
                ownerIds.add(owner.Id);
            }

            List<Property__c> properties = [
                SELECT Id, Name, Address__c, Photos__c, Price__c, Property_Type__c, Bedrooms__c, Status__c,
                       (SELECT Id FROM Client_Property_Interactions__r WHERE Interaction_Type__c = 'Inquired' AND Status__c = 'Active')
                FROM Property__c
                WHERE Owner__c IN :ownerIds
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            List<PropertyWrapper> wrappedProperties = new List<PropertyWrapper>();
            for (Property__c prop : properties) {
                String imageUrl = extractImageUrl(prop.Photos__c);
                Integer interestCount = prop.Client_Property_Interactions__r.size();
                wrappedProperties.add(new PropertyWrapper(prop, imageUrl, interestCount));
            }
            return wrappedProperties;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching properties: ' + e.getMessage());
        }
    }

    private static String extractImageUrl(String photos) {
        if (String.isBlank(photos) || !photos.contains('<img')) {
            System.debug('No valid image tag in Photos__c: ' + photos);
            return null;
        }
        String src = photos.substringBetween('src="', '"');
        if (String.isBlank(src)) {
            System.debug('No valid src attribute in Photos__c: ' + photos);
            return null;
        }
        return src;
    }

    private static Set<String> getPicklistValues(String objectName, String fieldName) {
        Set<String> values = new Set<String>();
        Schema.DescribeFieldResult fieldResult = Schema.getGlobalDescribe().get(objectName).getDescribe().fields.getMap().get(fieldName).getDescribe();
        for (Schema.PicklistEntry entry : fieldResult.getPicklistValues()) {
            if (entry.isActive()) values.add(entry.getValue());
        }
        return values;
    }

    public class PropertyWrapper {
        @AuraEnabled public Map<String, Object> propertyData;
        @AuraEnabled public String imageUrl;
        @AuraEnabled public Integer interestCount;
        public PropertyWrapper(Property__c prop, String imageUrl, Integer interestCount) {
            this.propertyData = new Map<String, Object>();
            this.propertyData.put('Id', prop.Id);
            this.propertyData.put('Name', prop.Name);
            this.propertyData.put('Address__c', prop.Address__c);
            this.propertyData.put('Photos__c', prop.Photos__c);
            this.propertyData.put('Price__c', prop.Price__c);
            this.propertyData.put('Property_Type__c', prop.Property_Type__c);
            this.propertyData.put('Bedrooms__c', prop.Bedrooms__c);
            this.propertyData.put('Status__c', prop.Status__c);
            this.imageUrl = imageUrl;
            this.interestCount = interestCount;
        }
    }
}