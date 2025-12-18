public with sharing class OwnerPortalController {
    @AuraEnabled(cacheable=true)
    public static List<Property__c> getOwnerProperties(String ownerId) {
        try {
            if (String.isBlank(ownerId) || !Pattern.matches('[a-zA-Z0-9]{15,18}', ownerId)) {
                throw new AuraHandledException('Invalid or missing owner ID.');
            }
            return [
                SELECT Id, Name, Address__c, Price__c
                FROM Property__c
                WHERE Owner__c = :ownerId
                WITH SECURITY_ENFORCED
                ORDER BY CreatedDate DESC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving properties: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static List<Property_Visit__c> getScheduledVisits() {
        try {
            return [
                SELECT Id, Name, Client__r.Name__c, Visit_Date__c, Status__c, Property__r.Name
                FROM Property_Visit__c
                WITH SECURITY_ENFORCED
                ORDER BY Visit_Date__c ASC
            ];
        } catch (Exception e) {
            throw new AuraHandledException('Error retrieving visits: ' + e.getMessage());
        }
    }

    @AuraEnabled
    public static String generateCalendarInvite(String visitId) {
        try {
            if (String.isBlank(visitId) || !Pattern.matches('[a-zA-Z0-9]{15,18}', visitId)) {
                throw new AuraHandledException('Invalid or missing visit ID.');
            }
            Property_Visit__c visit = [
                SELECT Id, Name, Client__r.Name, Client__r.Email__c,
                       Property__r.Name, Property__r.Address__c, Property__r.Owner__c, Visit_Date__c
                FROM Property_Visit__c
                WHERE Id = :visitId
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            Property_Owner__c owner = [
                SELECT User__c, Email__c, Name
                FROM Property_Owner__c
                WHERE Id = :visit.Property__r.Owner__c
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (String.isBlank(owner.Email__c)) {
                throw new AuraHandledException('Owner email is missing.');
            }
            if (String.isBlank(visit.Client__r.Email__c)) {
                throw new AuraHandledException('Client email is missing.');
            }
            Datetime startDate = visit.Visit_Date__c;
            Datetime endDate = startDate.addHours(1);
            String icsContent = 'BEGIN:VCALENDAR\n' +
                                'VERSION:2.0\n' +
                                'PRODID:-//xAI//PropertyVisit//EN\n' +
                                'BEGIN:VEVENT\n' +
                                'UID:' + visit.Id + '@xai.com\n' +
                                'DTSTAMP:' + Datetime.now().formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'') + '\n' +
                                'DTSTART:' + startDate.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'') + '\n' +
                                'DTEND:' + endDate.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'') + '\n' +
                                'SUMMARY:Visit for ' + visit.Property__r.Name + '\n' +
                                'DESCRIPTION:Property Visit with ' + visit.Client__r.Name + '\n' +
                                'LOCATION:' + visit.Property__r.Address__c + '\n' +
                                'ATTENDEE;CN=' + visit.Client__r.Name + ';RSVP=TRUE:mailto:' + visit.Client__r.Email__c + '\n' +
                                'ORGANIZER;CN=' + owner.Name + ':mailto:' + owner.Email__c + '\n' +
                                'END:VEVENT\n' +
                                'END:VCALENDAR';
            return icsContent;
        } catch (Exception e) {
            throw new AuraHandledException('Error generating calendar invite: ' + e.getMessage());
        }
    }
}