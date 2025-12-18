public with sharing class OwnerVisitController {
    @AuraEnabled(cacheable=true)
    public static List<Property_Visit__c> getScheduledVisits() {
        return [
            SELECT Id, Name, Property__r.Name, Client__r.Name, Agent__r.Name, Visit_Date__c, Status__c
            FROM Property_Visit__c
            WHERE Property__r.Owner__c = :UserInfo.getUserId()
            AND Status__c = 'Scheduled'
            ORDER BY Visit_Date__c ASC
        ];
    }

    @AuraEnabled
    public static void sendCalendarInvite(String visitId) {
        try {
            Property_Visit__c visit = [
                SELECT Id, Property__r.Name, Client__r.Email__c, Agent__r.Email, Visit_Date__c
                FROM Property_Visit__c
                WHERE Id = :visitId LIMIT 1
            ];

            // Generate ICS file
            String icsContent = generateICS(visit);

            // Send email with ICS attachment
            Messaging.SingleEmailMessage email = new Messaging.SingleEmailMessage();
            email.setToAddresses(new String[]{visit.Client__r.Email__c, visit.Agent__r.Email});
            email.setSubject('Property Visit Calendar Invite');
            email.setPlainTextBody(
                'You are invited to a property visit for ' + visit.Property__r.Name + '.\n' +
                'Date: ' + visit.Visit_Date__c.format('MM/dd/yyyy HH:mm') + '\n' +
                'Please find the calendar invite attached.'
            );

            Messaging.EmailFileAttachment attachment = new Messaging.EmailFileAttachment();
            attachment.setFileName('Property_Visit.ics');
            attachment.setBody(Blob.valueOf(icsContent));
            attachment.setContentType('text/calendar');
            email.setFileAttachments(new Messaging.EmailFileAttachment[]{attachment});

            Messaging.sendEmail(new Messaging.SingleEmailMessage[]{email});
        } catch (Exception e) {
            throw new AuraHandledException('Error sending calendar invite: ' + e.getMessage());
        }
    }

    private static String generateICS(Property_Visit__c visit) {
        Datetime startDate = visit.Visit_Date__c;
        Datetime endDate = startDate.addHours(1); // Assume 1-hour visit

        String icsContent = 'BEGIN:VCALENDAR\n' +
                            'VERSION:2.0\n' +
                            'PRODID:-//xAI//Property Visit//EN\n' +
                            'BEGIN:VEVENT\n' +
                            'UID:' + visit.Id + '@xai.com\n' +
                            'DTSTAMP:' + Datetime.now().formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'') + '\n' +
                            'DTSTART:' + startDate.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'') + '\n' +
                            'DTEND:' + endDate.formatGmt('yyyyMMdd\'T\'HHmmss\'Z\'') + '\n' +
                            'SUMMARY:Visit for ' + visit.Property__r.Name + '\n' +
                            'DESCRIPTION:Property visit scheduled with client and agent.\n' +
                            'LOCATION:' + visit.Property__r.Name + '\n' +
                            'END:VEVENT\n' +
                            'END:VCALENDAR';
        return icsContent;
    }
}