public with sharing class ContractPDFController {
    public Property__c property { get; set; }
    public Client__c client { get; set; }
    public Property_Owner__c owner { get; set; }
    public Payment__c payment { get; set; }

    public ContractPDFController() {
        String propertyId = ApexPages.currentPage().getParameters().get('propertyId');
        String clientId = ApexPages.currentPage().getParameters().get('clientId');
        String paymentId = ApexPages.currentPage().getParameters().get('paymentId');

        try {
            if (String.isNotBlank(propertyId)) {
                List<Property__c> properties = [SELECT Id, Name, Address__c, Price__c, Property_Type__c, Bedrooms__c, Square_Footage__c, Owner__c
                                               FROM Property__c 
                                               WHERE Id = :propertyId 
                                               WITH SECURITY_ENFORCED 
                                               LIMIT 1];
                if (properties.isEmpty()) {
                    throw new AuraHandledException('Property not found.');
                }
                property = properties[0];
                if (property.Owner__c != null) {
                    List<Property_Owner__c> owners = [SELECT Id, Name__c, Email__c, Phone__c, Type__c
                                                     FROM Property_Owner__c 
                                                     WHERE Id = :property.Owner__c 
                                                     WITH SECURITY_ENFORCED 
                                                     LIMIT 1];
                    if (!owners.isEmpty()) {
                        owner = owners[0];
                    } else {
                        System.debug('Owner not found for Property ID: ' + propertyId);
                    }
                } else {
                    System.debug('No Owner__c specified for Property ID: ' + propertyId);
                }
            }
            if (String.isNotBlank(clientId)) {
                List<Client__c> clients = [SELECT Id, Name__c, Email__c, Phone__c 
                                          FROM Client__c 
                                          WHERE Id = :clientId 
                                          WITH SECURITY_ENFORCED 
                                          LIMIT 1];
                if (!clients.isEmpty()) {
                    client = clients[0];
                } else {
                    System.debug('Client not found for Client ID: ' + clientId);
                }
            }
            if (String.isNotBlank(paymentId)) {
                List<Payment__c> payments = [SELECT Id, Name, Client__r.Name__c, Property__r.Name, Amount__c, Due_Date__c, Status__c
                                            FROM Payment__c
                                            WHERE Id = :paymentId
                                            WITH SECURITY_ENFORCED
                                            LIMIT 1];
                if (!payments.isEmpty()) {
                    payment = payments[0];
                } else {
                    System.debug('Payment not found for Payment ID: ' + paymentId);
                }
            }
        } catch (Exception e) {
            System.debug('Error in ContractPDFController constructor: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error initializing contract data: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String generateContract(String propertyId, String clientEmail, String clientName, String clientPhone) {
        try {
            System.debug('Generating contract for Property ID: ' + propertyId + ', Client Email: ' + clientEmail);
            if (String.isBlank(propertyId) || String.isBlank(clientEmail) || String.isBlank(clientName)) {
                throw new AuraHandledException('Property ID, client email, and client name are required.');
            }

            // Check for existing Client__c record
            String clientId = PropertySearchController.getClientIdByEmail(clientEmail);
            if (clientId == null) {
                if (!Schema.sObjectType.Client__c.isCreateable()) {
                    throw new AuraHandledException('Insufficient permissions to create Client record.');
                }
                Client__c newClient = new Client__c(
                    Name__c = clientName,
                    Email__c = clientEmail,
                    Phone__c = String.isNotBlank(clientPhone) ? clientPhone : 'N/A',
                    Budget__c = 0
                );
                insert newClient;
                clientId = newClient.Id;
                System.debug('Created new Client ID: ' + clientId);
            } else {
                List<Client__c> existingClients = [SELECT Id, Name__c, Phone__c 
                                                  FROM Client__c 
                                                  WHERE Id = :clientId 
                                                  WITH SECURITY_ENFORCED 
                                                  LIMIT 1];
                if (existingClients.isEmpty()) {
                    throw new AuraHandledException('Client record not accessible.');
                }
                Client__c existingClient = existingClients[0];
                existingClient.Name__c = clientName;
                existingClient.Phone__c = String.isNotBlank(clientPhone) ? clientPhone : existingClient.Phone__c;
                if (Schema.sObjectType.Client__c.isUpdateable()) {
                    update existingClient;
                    System.debug('Updated Client ID: ' + clientId);
                } else {
                    throw new AuraHandledException('Insufficient permissions to update Client record.');
                }
            }

            // Generate PDF
            PageReference pdfPage = Page.ContractPDF;
            pdfPage.getParameters().put('propertyId', propertyId);
            pdfPage.getParameters().put('clientId', clientId);
            Blob pdfBlob;
            if (Test.isRunningTest()) {
                pdfBlob = Blob.valueOf('Test PDF Content');
            } else {
                try {
                    pdfBlob = pdfPage.getContentAsPDF();
                } catch (Exception e) {
                    System.debug('Error generating PDF: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
                    throw new AuraHandledException('Failed to generate PDF: ' + e.getMessage());
                }
            }

            // Save as ContentVersion
            if (!Schema.sObjectType.ContentVersion.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create ContentVersion.');
            }
            ContentVersion contentVersion = new ContentVersion(
                Title = 'Property_Contract_' + propertyId + '_' + System.now().format('yyyyMMdd_HHmmss'),
                PathOnClient = 'contract.pdf',
                VersionData = pdfBlob,
                FirstPublishLocationId = propertyId
            );
            insert contentVersion;
            System.debug('Created ContentVersion ID: ' + contentVersion.Id);

            // Get ContentDocumentId
            contentVersion = [SELECT Id, ContentDocumentId 
                             FROM ContentVersion 
                             WHERE Id = :contentVersion.Id 
                             WITH SECURITY_ENFORCED 
                             LIMIT 1];
            if (contentVersion == null) {
                throw new AuraHandledException('Failed to retrieve ContentVersion.');
            }

            // Create Property_Document__c record
            if (!Schema.sObjectType.Property_Document__c.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Property_Document__c.');
            }
            Property_Document__c propDoc = new Property_Document__c(
                Property__c = propertyId,
                Document_Type__c = 'Deed',
                Status__c = 'Pending',
                Metadata__c = 'Generated contract for property ' + propertyId
            );
            insert propDoc;
            System.debug('Created Property_Document__c ID: ' + propDoc.Id);

            // Link ContentDocument to Property_Document__c
            if (!Schema.sObjectType.ContentDocumentLink.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create ContentDocumentLink.');
            }
            ContentDocumentLink cdl = new ContentDocumentLink(
                ContentDocumentId = contentVersion.ContentDocumentId,
                LinkedEntityId = propDoc.Id,
                ShareType = 'V'
            );
            insert cdl;
            System.debug('Created ContentDocumentLink for ContentDocument ID: ' + contentVersion.ContentDocumentId);

            return contentVersion.ContentDocumentId;
        } catch (Exception e) {
            System.debug('Error in generateContract: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error generating contract: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String initiatePayment(String propertyId, String clientId, Decimal amount, Datetime dueDate) {
        try {
            System.debug('Initiating payment for Property ID: ' + propertyId + ', Client ID: ' + clientId + ', Amount: ' + amount + ', Due Date: ' + dueDate);

            if (String.isBlank(propertyId) || String.isBlank(clientId) || amount == null || amount <= 0 || dueDate == null) {
                throw new AuraHandledException('Invalid payment parameters: Property ID, Client ID, Amount, and Due Date are required, and Amount must be positive.');
            }
            if (dueDate < System.now()) {
                throw new AuraHandledException('Due date cannot be in the past.');
            }

            // Validate client document
            List<Client_Document__c> clientDocs = [
                SELECT Id, Status__c
                FROM Client_Document__c
                WHERE Client__c = :clientId
                AND Document_Type__c = 'Contract'
                AND Status__c = 'Complete'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (clientDocs.isEmpty()) {
                throw new AuraHandledException('A completed contract is required before initiating payment.');
            }
            System.debug('Validated completed Client_Document__c for Client ID: ' + clientId);

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
            Payment__c payment = new Payment__c(
                Client__c = clientId,
                Property__c = propertyId,
                Amount__c = amount,
                Due_Date__c = dueDate,
                Status__c = 'Pending',
                OwnerId = UserInfo.getUserId()
            );
            if (!Schema.sObjectType.Payment__c.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create Payment record.');
            }
            insert payment;
            System.debug('Created Payment__c record with ID: ' + payment.Id + ', Name: ' + payment.Name);

            // Generate PDF receipt
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

            // Save as ContentVersion
            if (!Schema.sObjectType.ContentVersion.isCreateable()) {
                throw new AuraHandledException('Insufficient permissions to create ContentVersion.');
            }
            ContentVersion contentVersion = new ContentVersion(
                Title = 'Payment_Receipt_' + payment.Name,
                PathOnClient = 'payment_receipt_' + payment.Name + '.pdf',
                VersionData = pdfBlob,
                FirstPublishLocationId = payment.Id
            );
            insert contentVersion;
            System.debug('Created ContentVersion ID: ' + contentVersion.Id + ' for receipt');

            // Get ContentDocumentId
            contentVersion = [SELECT Id, ContentDocumentId 
                             FROM ContentVersion 
                             WHERE Id = :contentVersion.Id 
                             WITH SECURITY_ENFORCED 
                             LIMIT 1];
            if (contentVersion == null) {
                throw new AuraHandledException('Failed to retrieve ContentVersion.');
            }
            System.debug('Returning ContentDocumentId: ' + contentVersion.ContentDocumentId + ' for Payment ID: ' + payment.Id);

            return contentVersion.ContentDocumentId;
        } catch (Exception e) {
            System.debug('Error in initiatePayment: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            throw new AuraHandledException('Error initiating payment: ' + e.getMessage());
        }
    }
}