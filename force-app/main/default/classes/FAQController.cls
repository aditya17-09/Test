public with sharing class FAQController {
    @AuraEnabled
    public static String createCase(String subject, String description, String email, String priority, String userId, String contactId) {
        try {
            System.debug('Creating case with data: Subject=' + subject + ', Description=' + description + ', Email=' + email + ', Priority=' + priority + ', UserId=' + userId + ', ContactId=' + contactId);

            Case newCase = new Case();
            newCase.Subject = subject;
            newCase.Description = description;
            newCase.Origin = 'Email';
            newCase.Status = 'Open';
            newCase.Priority = priority;
            newCase.SuppliedEmail = email;
            newCase.Type = 'Other';
            newCase.ContactId = contactId; // Directly set the ContactId from the form input

            System.debug('Case object before insert: ' + JSON.serialize(newCase));
            insert newCase;
            System.debug('Case inserted successfully with Id: ' + newCase.Id);
            return newCase.Id;
        } catch (Exception e) {
            System.debug('Error creating case: ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString());
            throw new AuraHandledException('Error creating case: ' + e.getMessage());
        }
    }
}