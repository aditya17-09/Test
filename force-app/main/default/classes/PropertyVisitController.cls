public with sharing class PropertyVisitController {
    @AuraEnabled
    public static String scheduleVisit(String propertyId, Datetime visitDate) {
        String errorContext = 'Initial validation';
        try {
            // Validate inputs
            if (String.isBlank(propertyId) || !Pattern.matches('[a-zA-Z0-9]{15,18}', propertyId)) {
                throw new AuraHandledException('Invalid or missing property ID.');
            }
            if (visitDate == null) {
                throw new AuraHandledException('Visit date is required.');
            }
            if (visitDate < System.now()) {
                throw new AuraHandledException('Cannot schedule a visit in the past.');
            }

            // Get and validate current user
            errorContext = 'Fetching current user';
            User currentUser = [SELECT Id, Name, Email FROM User WHERE Id = :UserInfo.getUserId() WITH SECURITY_ENFORCED LIMIT 1];
            if (String.isBlank(currentUser.Email)) {
                throw new AuraHandledException('User email is missing. Please update your user profile.');
            }

            // Find or create Client__c
            errorContext = 'Handling client record';
            Client__c client;
            List<Client__c> clients = [SELECT Id FROM Client__c WHERE Email__c = :currentUser.Email WITH SECURITY_ENFORCED LIMIT 1];
            if (clients.isEmpty()) {
                client = new Client__c(
                    Name = currentUser.Name, // Use Name field for Client Name
                    Email__c = currentUser.Email,
                    OwnerId = currentUser.Id
                );
                insert client;
            } else {
                client = clients[0];
            }

            // Validate Property
            errorContext = 'Fetching property';
            List<Property__c> properties = [SELECT Id, Owner__c FROM Property__c WHERE Id = :propertyId WITH SECURITY_ENFORCED LIMIT 1];
            if (properties.isEmpty()) {
                throw new AuraHandledException('Property not found for the provided ID.');
            }

            // Create Property_Visit__c
            errorContext = 'Creating visit record';
            Property_Visit__c visit = new Property_Visit__c(
                Property__c = propertyId,
                Client__c = client.Id,
                Visit_Date__c = visitDate,
                Status__c = 'Scheduled',
                OwnerId = UserInfo.getUserId() // Assign to current user
            );
            insert visit;

            // Notify Property Owner (commented out as requested)
            /*
            errorContext = 'Notifying owner';
            notifyOwner(properties[0].Owner__c, visit.Id, propertyId, visitDate);
            */

            return visit.Id;
        } catch (Exception e) {
            String errorMessage = 'Error in scheduleVisit at ' + errorContext + ': ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, errorMessage);
            throw new AuraHandledException('Error scheduling visit: ' + e.getMessage());
        }
    }

    /*
    private static void notifyOwner(Id ownerId, Id visitId, Id propertyId, Datetime visitDate) {
        try {
            List<Property_Owner__c> owners = [SELECT User__c, Email__c FROM Property_Owner__c WHERE Id = :ownerId AND User__c != null WITH SECURITY_ENFORCED LIMIT 1];
            if (owners.isEmpty() || String.isBlank(owners[0].Email__c)) {
                System.debug(LoggingLevel.WARN, 'Owner email missing or no linked user for Property_Owner__c ID: ' + ownerId);
                return;
            }
            List<Property__c> properties = [SELECT Name FROM Property__c WHERE Id = :propertyId WITH SECURITY_ENFORCED LIMIT 1];
            if (properties.isEmpty()) {
                System.debug(LoggingLevel.WARN, 'Property not found for notification: ' + propertyId);
                return;
            }

            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[]{owners[0].Email__c});
            email.setSubject('New Property Visit Scheduled');
            email.setPlainTextBody(
                'A visit has been scheduled for Property: ' + properties[0].Name + '\n' +
                'Visit Date: ' + visitDate.format('MM/dd/yyyy HH:mm') + '\n' +
                'Please review and send a calendar invite from the Owner Portal.'
            );
            email.setSaveAsActivity(false);
            Messaging.SendEmailResult[] results = Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
            if (!results[0].isSuccess()) {
                System.debug(LoggingLevel.WARN, 'Email send failed: ' + results[0].getErrors()[0].getMessage());
            }
        } catch (Exception e) {
            System.debug(LoggingLevel.WARN, 'Error notifying owner: ' + e.getMessage());
        }
    }
    */

    @AuraEnabled(cacheable=true)
    public static Boolean hasScheduledVisit(String propertyId) {
        try {
            if (String.isBlank(propertyId)) {
                return false;
            }
            User currentUser = [SELECT Email FROM User WHERE Id = :UserInfo.getUserId() WITH SECURITY_ENFORCED LIMIT 1];
            if (String.isBlank(currentUser.Email)) {
                return false;
            }
            List<Client__c> clients = [SELECT Id FROM Client__c WHERE Email__c = :currentUser.Email WITH SECURITY_ENFORCED LIMIT 1];
            if (clients.isEmpty()) {
                return false;
            }
            List<Property_Visit__c> visits = [
                SELECT Id 
                FROM Property_Visit__c 
                WHERE Property__c = :propertyId 
                AND Client__c = :clients[0].Id
                AND Status__c = 'Scheduled'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            return !visits.isEmpty();
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error in hasScheduledVisit: ' + e.getMessage());
            throw new AuraHandledException('Error checking scheduled visits: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String generatePaymentIcs(String paymentId, String propertyId, String clientId, Decimal amount, Datetime dueDate) {
        try {
            if (String.isBlank(paymentId) || String.isBlank(propertyId) || String.isBlank(clientId) || amount <= 0 || dueDate == null) {
                throw new AuraHandledException('Invalid parameters for .ics generation.');
            }

            Property__c property = [
                SELECT Id, Name, Address__c, Owner__c
                FROM Property__c
                WHERE Id = :propertyId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            Client__c client = [
                SELECT Id, Name, Email__c
                FROM Client__c
                WHERE Id = :clientId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            Property_Owner__c owner = [
                SELECT Id, Name, Email__c
                FROM Property_Owner__c
                WHERE Id = :property.Owner__c
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];

            if (String.isBlank(client.Email__c)) {
                throw new AuraHandledException('Client email is missing.');
            }
            if (String.isBlank(owner.Email__c)) {
                throw new AuraHandledException('Owner email is missing.');
            }

            Datetime startDate = dueDate;
            Datetime endDate = startDate.addHours(1);
            String icsContent = 'BEGIN:VCALENDAR\n' +
                                'VERSION:2.0\n' +
                                'PRODID:-//xAI//Payment//EN\n' +
                                'BEGIN:VEVENT\n' +
                                'UID:' + paymentId + '@xai.com\n' +
                                'DTSTAMP:' + Datetime.now().formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'') + '\n' +
                                'DTSTART:' + startDate.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'') + '\n' +
                                'DTEND:' + endDate.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'') + '\n' +
                                'SUMMARY:Payment Due for ' + property.Name + '\n' +
                                'DESCRIPTION:Payment of ₹' + amount + ' for property ' + property.Name + '\n' +
                                'LOCATION:' + property.Address__c + '\n' +
                                'ATTENDEE;CN=' + client.Name + ';RSVP=TRUE:mailto:' + client.Email__c + '\n' +
                                'ORGANIZER;CN=' + owner.Name + ':mailto:' + owner.Email__c + '\n' +
                                'END:VEVENT\n' +
                                'END:VCALENDAR';

            return icsContent;
        } catch (Exception e) {
            System.debug(LoggingLevel.ERROR, 'Error generating .ics: ' + e.getMessage());
            throw new AuraHandledException('Error generating calendar invite: ' + e.getMessage());
        }
    }
}