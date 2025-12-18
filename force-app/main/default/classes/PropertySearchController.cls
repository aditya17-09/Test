/**
 * PropertySearchController
 * Handles property-related operations for the PropertyDetail LWC, including search, payment initiation,
 * document status checks, and other functionalities. Updated to fix payment screen (create Payment__c and PDF receipt)
 * and Generate Document button (enabled for new properties unless completed Property_Document__c exists).
 * Adjusted to handle missing Property__c field on Client_Document__c by using Property_Document__c and Client_Property_Interaction__c.
 */
public with sharing class PropertySearchController {

    /**
     * Searches for properties based on provided criteria.
     */
    @AuraEnabled
    public static List<PropertyWrapper> searchProperties(String searchType, String propertyType, String location, List<String> selectedPropertyTypes, Decimal budgetMin, Decimal budgetMax, List<String> bedrooms) {
        try {
            if (String.isBlank(location)) throw new AuraHandledException('Search locality is required.');
            String locationLike = '%' + String.escapeSingleQuotes(location) + '%';
            String query = 'SELECT Id, Name, Address__c, Photos__c, Price__c, Property_Type__c, Square_Footage__c, Bedrooms__c, Amenities__c, Property_Stage__c, Lease_Terms__c, Status__c, ' +
                          '(SELECT Id FROM Client_Property_Interactions__r WHERE Interaction_Type__c = \'Inquired\' AND Status__c = \'Active\') ' +
                          'FROM Property__c WHERE Address__c LIKE :locationLike AND Status__c = \'Available\' ';
            if (String.isNotBlank(propertyType)) query += 'AND Property_Type__c = :propertyType ';
            query += 'WITH SECURITY_ENFORCED ORDER BY CreatedDate DESC LIMIT 50';
            System.debug('SearchProperties Query: ' + query);
            System.debug('Search Parameters: location=' + location + ', propertyType=' + propertyType);
            List<Property__c> properties = Database.query(query);
            System.debug('Found Properties: ' + properties.size() + ', Details: ' + properties);
            List<PropertyWrapper> wrappedProperties = new List<PropertyWrapper>();
            for (Property__c prop : properties) {
                String imageUrl = extractImageUrl(prop.Photos__c);
                Integer interestCount = prop.Client_Property_Interactions__r.size();
                wrappedProperties.add(new PropertyWrapper(prop, imageUrl, interestCount));
            }
            System.debug('Wrapped Properties: ' + wrappedProperties.size());
            return wrappedProperties;
        } catch (Exception e) {
            System.debug('Error in searchProperties: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error searching properties: ' + e.getMessage());
        }
    }

    /**
     * Retrieves details for a specific property.
     */
    @AuraEnabled(cacheable=true)
    public static PropertyWrapper getPropertyDetails(String propertyId) {
        try {
            if (String.isBlank(propertyId)) throw new AuraHandledException('Property ID is required.');
            String query = 'SELECT Id, Name, Address__c, Photos__c, Price__c, Property_Type__c, Square_Footage__c, Bedrooms__c, Amenities__c, Property_Stage__c, Lease_Terms__c, Status__c, ' +
                          '(SELECT Id FROM Client_Property_Interactions__r WHERE Interaction_Type__c = \'Inquired\' AND Status__c = \'Active\') ' +
                          'FROM Property__c WHERE Id = :propertyId AND Status__c = \'Available\' WITH SECURITY_ENFORCED LIMIT 1';
            List<Property__c> properties = Database.query(query);
            if (properties.isEmpty()) throw new AuraHandledException('Property not found or not available.');
            Property__c prop = properties[0];
            String imageUrl = extractImageUrl(prop.Photos__c);
            Integer interestCount = prop.Client_Property_Interactions__r.size();
            return new PropertyWrapper(prop, imageUrl, interestCount);
        } catch (Exception e) {
            System.debug('Error in getPropertyDetails: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching property details: ' + e.getMessage());
        }
    }

    /**
     * Wrapper class for property data.
     */
    public class PropertyWrapper {
        @AuraEnabled public Map<String, Object> propertyData;
        @AuraEnabled public String ImageUrl;
        @AuraEnabled public Integer interestCount;
        public PropertyWrapper(Property__c prop, String imageUrl, Integer interestCount) {
            this.propertyData = new Map<String, Object>();
            this.propertyData.put('Id', prop.Id);
            this.propertyData.put('Name', prop.Name);
            this.propertyData.put('Address__c', prop.Address__c);
            this.propertyData.put('Photos__c', prop.Photos__c);
            this.propertyData.put('Price__c', prop.Price__c);
            this.propertyData.put('Property_Type__c', prop.Property_Type__c);
            this.propertyData.put('Square_Footage__c', prop.Square_Footage__c);
            this.propertyData.put('Bedrooms__c', prop.Bedrooms__c);
            this.propertyData.put('Amenities__c', prop.Amenities__c);
            this.propertyData.put('Property_Stage__c', prop.Property_Stage__c);
            this.propertyData.put('Lease_Terms__c', prop.Lease_Terms__c);
            this.propertyData.put('Status__c', prop.Status__c);
            this.ImageUrl = imageUrl;
            this.interestCount = interestCount;
        }
    }

    /**
     * Extracts image URL from Photos__c field.
     */
    private static String extractImageUrl(String photos) {
        if (String.isBlank(photos) || !photos.contains('<img')) return null;
        String src = photos.substringBetween('src="', '"');
        return String.isBlank(src) ? null : src;
    }

    /**
     * Submits interest for a property.
     */
    @AuraEnabled
    public static void submitInterest(String propertyId, String name, String email, String phone, Decimal budget, String reason) {
        try {
            if (String.isBlank(propertyId) || String.isBlank(name) || String.isBlank(email) || String.isBlank(phone) || budget == null) throw new AuraHandledException('All fields are required.');
            List<Client__c> clients = [SELECT Id FROM Client__c WHERE Email__c = :email LIMIT 1];
            Client__c client;
            if (clients.isEmpty()) {
                client = new Client__c(Name__c = name, Email__c = email, Phone__c = phone, Budget__c = budget);
                insert client;
            } else client = clients[0];
            Client_Property_Interaction__c interaction = new Client_Property_Interaction__c(
                Client__c = client.Id, 
                Property__c = propertyId, 
                Interaction_Type__c = 'Inquired', 
                Interaction_Date__c = Date.today(), 
                Status__c = 'Active', 
                Reason__c = String.isNotBlank(reason) ? reason : 'Interested in property', 
                OwnerId = UserInfo.getUserId()
            );
            insert interaction;
        } catch (Exception e) {
            throw new AuraHandledException('Error submitting interest: ' + e.getMessage());
        }
    }

    /**
     * Retrieves owner details for a property.
     */
    @AuraEnabled(cacheable=true)
    public static Map<String, String> getOwnerDetails(String propertyId) {
        try {
            Property__c property = [SELECT Owner__r.Name__c, Owner__r.Phone__c, Owner__r.Address__c, Owner__r.Email__c 
                                  FROM Property__c 
                                  WHERE Id = :propertyId 
                                  WITH SECURITY_ENFORCED 
                                  LIMIT 1];
            Map<String, String> ownerDetails = new Map<String, String>{
                'Name__c' => property.Owner__r.Name__c != null ? property.Owner__r.Name__c : 'N/A',
                'Phone' => property.Owner__r.Phone__c != null ? property.Owner__r.Phone__c : 'N/A',
                'Email' => property.Owner__r.Email__c != null ? property.Owner__r.Email__c : 'N/A',
                'Address' => property.Owner__r.Address__c != null ? property.Owner__r.Address__c : 'N/A'
            };
            return ownerDetails;
        } catch (Exception e) {
            throw new AuraHandledException('Error fetching owner details: ' + e.getMessage());
        }
    }

    /**
     * Saves a client document and links it to a property.
     */
    @AuraEnabled
    public static void saveClientDocument(String propertyId, String contentDocumentId, String clientEmail, String clientName, String clientPhone) {
        try {
            if (String.isBlank(propertyId) || String.isBlank(contentDocumentId) || String.isBlank(clientEmail) || String.isBlank(clientName)) {
                throw new AuraHandledException('Property ID, content document ID, client email, and client name are required.');
            }

            // Validate file name includes "SIGNED"
            List<ContentVersion> contentVersions = [
                SELECT Id, Title 
                FROM ContentVersion 
                WHERE ContentDocumentId = :contentDocumentId 
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];
            System.debug('ContentVersions found: ' + contentVersions.size());
            if (contentVersions.isEmpty()) {
                throw new AuraHandledException('No file found for the provided content document ID.');
            }
            ContentVersion cv = contentVersions[0];
            System.debug('ContentVersion Title: ' + cv.Title);
            if (!cv.Title.toUpperCase().contains('SIGNED')) {
                throw new AuraHandledException('File name must include "SIGNED".');
            }

            // Get or create Client__c
            String clientId = getClientIdByEmail(clientEmail);
            System.debug('Client ID for email ' + clientEmail + ': ' + clientId);
            if (clientId == null) {
                Client__c newClient = new Client__c(
                    Name__c = clientName,
                    Email__c = clientEmail,
                    Phone__c = String.isNotBlank(clientPhone) ? clientPhone : 'N/A',
                    Budget__c = 0
                );
                insert newClient;
                clientId = newClient.Id;
                System.debug('Created new Client__c with ID: ' + clientId);
            } else {
                Client__c existingClient = [SELECT Id, Name__c, Phone__c FROM Client__c WHERE Id = :clientId LIMIT 1];
                existingClient.Name__c = clientName;
                existingClient.Phone__c = String.isNotBlank(clientPhone) ? clientPhone : existingClient.Phone__c;
                update existingClient;
                System.debug('Updated existing Client__c: ' + existingClient.Id);
            }

            // Find the existing Property_Document__c
            List<Property_Document__c> propDocs = [
                SELECT Id, Status__c 
                FROM Property_Document__c 
                WHERE Property__c = :propertyId 
                AND Document_Type__c = 'Deed' 
                AND Status__c != 'Complete' 
                WITH SECURITY_ENFORCED 
                LIMIT 1
            ];
            System.debug('Property_Document__c found: ' + propDocs.size());
            if (propDocs.isEmpty()) {
                System.debug('No pending Property_Document__c found for propertyId: ' + propertyId);
                throw new AuraHandledException('No pending property document found for this property.');
            }
            Property_Document__c propDoc = propDocs[0];
            System.debug('Property_Document__c ID: ' + propDoc.Id + ', Current Status: ' + propDoc.Status__c);

            // Create Client_Document__c
            Client_Document__c clientDoc = new Client_Document__c(
                Client__c = clientId,
                Document_Type__c = 'Contract',
                Status__c = 'Pending',
                Metadata__c = 'Signed contract for property ' + propertyId,
                OwnerId = UserInfo.getUserId()
            );
            insert clientDoc;
            System.debug('Created Client_Document__c with ID: ' + clientDoc.Id);

            // Link ContentDocument to Client_Document__c
            ContentDocumentLink cdlClient = new ContentDocumentLink(
                ContentDocumentId = contentDocumentId,
                LinkedEntityId = clientDoc.Id,
                ShareType = 'V'
            );
            insert cdlClient;
            System.debug('Created ContentDocumentLink for Client_Document__c');

            // Update Property_Document__c status to Complete
            propDoc.Status__c = 'Complete';
            update propDoc;
            System.debug('Updated Property_Document__c ID: ' + propDoc.Id + ' to Status: Complete');

        } catch (Exception e) {
            System.debug('Error in saveClientDocument: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error saving client document: ' + e.getMessage());
        }
    }

    /**
     * Retrieves client ID by email.
     */
    public static String getClientIdByEmail(String email) {
        List<Client__c> clients = [SELECT Id FROM Client__c WHERE Email__c = :email LIMIT 1];
        return clients.isEmpty() ? null : clients[0].Id;
    }

    /**
     * Retrieves pending actions for a user.
     */
    @AuraEnabled
    public static List<PendingActionWrapper> getPendingActions(String userEmail) {
        try {
            if (String.isBlank(userEmail)) {
                throw new AuraHandledException('User email is required.');
            }

            // Find Client__c record for the user
            List<Client__c> clients = [SELECT Id FROM Client__c WHERE Email__c = :userEmail WITH SECURITY_ENFORCED LIMIT 1];
            if (clients.isEmpty()) {
                System.debug('No Client__c found for email: ' + userEmail);
                return new List<PendingActionWrapper>();
            }
            String clientId = clients[0].Id;

            // Query Property_Document__c records with Status__c != 'Complete'
            List<Property_Document__c> pendingPropDocs = [
                SELECT Id, Name, Property__c, Property__r.Name, Property__r.Address__c, Document_Type__c, Status__c, CreatedDate, Pending_Reason__c
                FROM Property_Document__c
                WHERE OwnerId = :UserInfo.getUserId()
                AND Status__c != 'Complete'
                AND Document_Type__c = 'Deed'
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            // Query Client_Document__c records with Status__c != 'Complete'
            List<Client_Document__c> pendingClientDocs = [
                SELECT Id, Name, Client__c, Client__r.Name__c, Document_Type__c, Status__c, CreatedDate, Pending_Reason__c
                FROM Client_Document__c
                WHERE Client__c = :clientId
                AND Status__c != 'Complete'
                AND Document_Type__c = 'Contract'
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
                LIMIT 50
            ];

            List<PendingActionWrapper> pendingActions = new List<PendingActionWrapper>();
            for (Property_Document__c doc : pendingPropDocs) {
                pendingActions.add(new PendingActionWrapper(doc));
            }
            for (Client_Document__c doc : pendingClientDocs) {
                pendingActions.add(new PendingActionWrapper(doc));
            }

            System.debug('Pending Actions Found: ' + pendingActions.size());
            return pendingActions;
        } catch (Exception e) {
            System.debug('Error in getPendingActions: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error fetching pending actions: ' + e.getMessage());
        }
    }

    /**
     * Wrapper class for pending actions.
     */
    public class PendingActionWrapper {
        @AuraEnabled public String documentId;
        @AuraEnabled public String documentName;
        @AuraEnabled public String propertyId;
        @AuraEnabled public String propertyName;
        @AuraEnabled public String propertyAddress;
        @AuraEnabled public String documentType;
        @AuraEnabled public String status;
        @AuraEnabled public String pendingReason;
        @AuraEnabled public Date createdDate;
        @AuraEnabled public String actionType;

        public PendingActionWrapper(Property_Document__c doc) {
            this.documentId = doc.Id;
            this.documentName = doc.Name;
            this.propertyId = doc.Property__c;
            this.propertyName = doc.Property__r.Name;
            this.propertyAddress = doc.Property__r.Address__c;
            this.documentType = doc.Document_Type__c;
            this.status = doc.Status__c;
            this.pendingReason = doc.Pending_Reason__c;
            this.createdDate = doc.CreatedDate.date();
            this.actionType = 'PropertyDocument';
        }

        public PendingActionWrapper(Client_Document__c doc) {
            this.documentId = doc.Id;
            this.documentName = doc.Name;
            this.propertyId = null;
            this.propertyName = doc.Client__r.Name__c + ' Document';
            this.propertyAddress = null;
            this.documentType = doc.Document_Type__c;
            this.status = doc.Status__c;
            this.pendingReason = doc.Pending_Reason__c;
            this.createdDate = doc.CreatedDate.date();
            this.actionType = 'ClientDocument';
        }
    }

    /**
     * Checks the document status for a property to determine if the Generate Document button should be enabled.
     * Updated to handle missing Property__c field on Client_Document__c by checking Property_Document__c status
     * and verifying client-property interaction via Client_Property_Interaction__c.
     * Creates a Client__c for new users and includes permission checks and detailed logging.
     */
    @AuraEnabled
    public static Map<String, Object> checkPropertyDocumentStatus(String propertyId) {
        try {
            // Log the start of document status check
            System.debug('Checking document status for Property ID: ' + propertyId);
            if (String.isBlank(propertyId)) {
                throw new AuraHandledException('Property ID is required.');
            }

            // Retrieve current user details
            User currentUser = [SELECT Id, Email, Name, Phone FROM User WHERE Id = :UserInfo.getUserId() WITH SECURITY_ENFORCED LIMIT 1];
            if (String.isBlank(currentUser.Email)) {
                throw new AuraHandledException('User email is missing.');
            }

            // Get or create Client__c
            List<Client__c> clients = [SELECT Id, Name__c, Phone__c FROM Client__c WHERE Email__c = :currentUser.Email WITH SECURITY_ENFORCED LIMIT 1];
            String clientId;
            if (clients.isEmpty()) {
                if (!Schema.sObjectType.Client__c.isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create Client record.');
                }
                Client__c newClient = new Client__c(
                    Name__c = currentUser.Name,
                    Email__c = currentUser.Email,
                    Phone__c = String.isNotBlank(currentUser.Phone) ? currentUser.Phone : 'N/A',
                    Budget__c = 0
                );
                insert newClient;
                clientId = newClient.Id;
                System.debug('Created new Client__c with ID: ' + clientId);
            } else {
                clientId = clients[0].Id;
                System.debug('Found existing Client__c with ID: ' + clientId);
            }

            // Verify client has an interaction with the property
            List<Client_Property_Interaction__c> interactions = [
                SELECT Id
                FROM Client_Property_Interaction__c
                WHERE Client__c = :clientId
                AND Property__c = :propertyId
                AND Status__c = 'Active'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            System.debug('Client_Property_Interaction__c found: ' + interactions.size() + ', Details: ' + interactions);
            if (interactions.isEmpty()) {
                System.debug('No active interaction found for Client ID: ' + clientId + ' and Property ID: ' + propertyId);
                // Allow document generation if no interaction exists (new property)
                interactions = new List<Client_Property_Interaction__c>{};
            }

            // Check for completed Property_Document__c for the property
            List<Property_Document__c> propDocs = [
                SELECT Id, Status__c
                FROM Property_Document__c
                WHERE Property__c = :propertyId
                AND Document_Type__c = 'Deed'
                AND Status__c = 'Complete'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            System.debug('Property_Document__c found: ' + propDocs.size() + ', Details: ' + propDocs);

            // Set isComplete to true only if a completed Property_Document__c exists
            Boolean isComplete = !propDocs.isEmpty();
            System.debug('Document status isComplete: ' + isComplete + ', Client ID: ' + clientId);

            // Return result for LWC to enable/disable Generate Document button
            return new Map<String, Object>{
                'isComplete' => isComplete,
                'clientId' => clientId
            };
        } catch (Exception e) {
            System.debug('Error in checkPropertyDocumentStatus: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error checking document status: ' + e.getMessage());
        }
    }

    /**
     * Initiates a payment by creating a Payment__c record and generating a PDF receipt.
     * Updated to handle missing Property__c field on Client_Document__c by validating Property_Document__c status
     * and ensuring client-property interaction. Includes robust validation, permission checks, and detailed logging.
     * Ensures no calendar invite (.ics file) is generated.
     */
    @AuraEnabled
    public static String initiatePayment(String propertyId, String clientId, Decimal amount, Datetime dueDate) {
        try {
            // Log input parameters for debugging
            System.debug('Initiating payment for Property ID: ' + propertyId + ', Client ID: ' + clientId + ', Amount: ' + amount + ', Due Date: ' + dueDate);

            // Validate input parameters
            if (String.isBlank(propertyId) || String.isBlank(clientId) || amount == null || amount <= 0 || dueDate == null) {
                throw new AuraHandledException('Invalid payment parameters: Property ID, Client ID, Amount, and Due Date are required, and Amount must be positive.');
            }
            if (dueDate < System.now()) {
                throw new AuraHandledException('Due date cannot be in the past.');
            }

            // Verify client has an interaction with the property
            List<Client_Property_Interaction__c> interactions = [
                SELECT Id
                FROM Client_Property_Interaction__c
                WHERE Client__c = :clientId
                AND Property__c = :propertyId
                AND Status__c = 'Active'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            System.debug('Client_Property_Interaction__c found: ' + interactions.size() + ', Details: ' + interactions);
            if (interactions.isEmpty()) {
                throw new AuraHandledException('No active interaction found for this client and property.');
            }

            // Validate that a completed Client_Document__c exists for the client
            List<Client_Document__c> clientDocs = [
                SELECT Id, Status__c
                FROM Client_Document__c
                WHERE Client__c = :clientId
                AND Document_Type__c = 'Contract'
                AND Status__c = 'Complete'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            System.debug('Client_Document__c found: ' + clientDocs.size() + ', Details: ' + clientDocs);
            if (clientDocs.isEmpty()) {
                throw new AuraHandledException('A completed contract is required before initiating payment.');
            }

            // Validate that a completed Property_Document__c exists for the property
            List<Property_Document__c> propDocs = [
                SELECT Id, Status__c
                FROM Property_Document__c
                WHERE Property__c = :propertyId
                AND Document_Type__c = 'Deed'
                AND Status__c = 'Complete'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            System.debug('Property_Document__c found: ' + propDocs.size() + ', Details: ' + propDocs);
            if (propDocs.isEmpty()) {
                throw new AuraHandledException('A completed property document is required before initiating payment.');
            }

            // Query property and client details
            Property__c property = [
                SELECT Id, Name, Address__c
                FROM Property__c
                WHERE Id = :propertyId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            Client__c client = [
                SELECT Id, Name__c, Email__c
                FROM Client__c
                WHERE Id = :clientId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            System.debug('Queried Property: ' + property.Name + ', Client: ' + client.Name__c);

            // Create Payment__c record
            if (!Schema.sObjectType.Payment__c.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Payment record.');
            }
            Payment__c payment = new Payment__c(
                Client__c = clientId,
                Property__c = propertyId,
                Amount__c = amount,
                Due_Date__c = dueDate,
                Status__c = 'Pending',
                OwnerId = UserInfo.getUserId()
            );
            insert payment;
            System.debug('Created Payment__c record with ID: ' + payment.Id + ', Name: ' + payment.Name);

            // Generate PDF receipt using PaymentReceipt Visualforce page
            PageReference receiptPage = new PageReference('/apex/PaymentReceipt');
            receiptPage.getParameters().put('paymentId', payment.Id);
            Blob pdfBlob;
            if (!Test.isRunningTest()) {
                try {
                    pdfBlob = receiptPage.getContentAsPDF();
                    System.debug('Generated PDF receipt for Payment ID: ' + payment.Id);
                } catch (Exception e) {
                    System.debug('Error generating PDF receipt: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
                    throw new AuraHandledException('Failed to generate PDF receipt: ' + e.getMessage());
                }
            } else {
                pdfBlob = Blob.valueOf('Test PDF Content');
            }

            // Save PDF as ContentVersion
            if (!Schema.sObjectType.ContentVersion.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create ContentVersion.');
            }
            ContentVersion cv = new ContentVersion(
                Title = 'Payment_Receipt_' + payment.Name,
                PathOnClient = 'payment_receipt_' + payment.Name + '.pdf',
                VersionData = pdfBlob,
                FirstPublishLocationId = payment.Id
            );
            insert cv;
            System.debug('Created ContentVersion ID: ' + cv.Id + ' for receipt');

            // Retrieve ContentDocumentId
            ContentVersion savedCv = [SELECT ContentDocumentId 
                                     FROM ContentVersion 
                                     WHERE Id = :cv.Id 
                                     WITH SECURITY_ENFORCED 
                                     LIMIT 1];
            if (savedCv == null) {
                throw new AuraHandledException('Failed to retrieve ContentVersion.');
            }
            System.debug('Returning ContentDocumentId: ' + savedCv.ContentDocumentId + ' for Payment ID: ' + payment.Id);

            // Return ContentDocumentId for LWC to download the PDF
            return savedCv.ContentDocumentId;
        } catch (Exception e) {
            System.debug('Error in initiatePayment: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error initiating payment: ' + e.getMessage());
        }
    }
}