/**
 * PendingActionsReminder
 * Schedulable class that sends email reminders for pending actions (Property_Document__c, Client_Document__c, and Payment__c)
 * and deletes records older than 5 days. Updated to include pending Payment__c reminders and deletions, and added reminders
 * for Property Owners for pending Property_Document__c records via Property__c.Owner__c email. Fixed syntax error in delete
 * statement for oldPayments. 
 */
public with sharing class PendingActionsReminder implements Schedulable {
    public void execute(SchedulableContext ctx) {
        try {
            // Define cutoff date (5 days ago from today)
            DateTime cutoffDate = System.now().addDays(-5);
            System.debug('Cutoff date for old records: ' + cutoffDate);

            // Query Property_Document__c records (pending, Deed)
            List<Property_Document__c> pendingPropDocs = [
                SELECT Id, Name, Property__c, Property__r.Name, Property__r.Owner__r.Name__c, Property__r.Owner__r.Email__c, 
                       Document_Type__c, Status__c, Pending_Reason__c, OwnerId
                FROM Property_Document__c
                WHERE Status__c != 'Complete'
                AND Document_Type__c = 'Deed'
                AND Property__r.Owner__r.Email__c != NULL
                WITH SECURITY_ENFORCED
            ];
            System.debug('Pending Property_Document__c records found: ' + pendingPropDocs.size());

            // Query Client_Document__c records (pending, Contract)
            List<Client_Document__c> pendingClientDocs = [
                SELECT Id, Name, Client__c, Client__r.Name__c, Client__r.Email__c, Document_Type__c, Status__c, Pending_Reason__c
                FROM Client_Document__c
                WHERE Status__c != 'Complete'
                AND Document_Type__c = 'Contract'
                AND Client__r.Email__c != NULL
                WITH SECURITY_ENFORCED
            ];
            System.debug('Pending Client_Document__c records found: ' + pendingClientDocs.size());

            // Query Payment__c records (pending)
            List<Payment__c> pendingPayments = [
                SELECT Id, Name, Client__c, Client__r.Name__c, Client__r.Email__c, Property__c, Property__r.Name, Amount__c, Due_Date__c, Status__c
                FROM Payment__c
                WHERE Status__c = 'Pending'
                AND Client__r.Email__c != NULL
                WITH SECURITY_ENFORCED
            ];
            System.debug('Pending Payment__c records found: ' + pendingPayments.size());

            // Group documents and payments by email
            Map<String, List<Property_Document__c>> propDocsByUserEmail = new Map<String, List<Property_Document__c>>();
            Map<String, List<Property_Document__c>> propDocsByOwnerEmail = new Map<String, List<Property_Document__c>>();
            Map<String, List<Client_Document__c>> clientDocsByEmail = new Map<String, List<Client_Document__c>>();
            Map<String, List<Payment__c>> paymentsByEmail = new Map<String, List<Payment__c>>();
            Map<String, String> clientNameByEmail = new Map<String, String>();
            Map<String, String> ownerNameByEmail = new Map<String, String>();

            // Process Property_Document__c (lookup User email and Property Owner email)
            for (Property_Document__c doc : pendingPropDocs) {
                // Group by User email (OwnerId)
                User owner = [SELECT Email FROM User WHERE Id = :doc.OwnerId WITH SECURITY_ENFORCED LIMIT 1];
                if (String.isNotBlank(owner.Email)) {
                    if (!propDocsByUserEmail.containsKey(owner.Email)) {
                        propDocsByUserEmail.put(owner.Email, new List<Property_Document__c>());
                    }
                    propDocsByUserEmail.get(owner.Email).add(doc);
                }

                // Group by Property Owner email (Property__r.Owner__r.Email__c)
                String ownerEmail = doc.Property__r.Owner__r.Email__c;
                if (String.isNotBlank(ownerEmail)) {
                    if (!propDocsByOwnerEmail.containsKey(ownerEmail)) {
                        propDocsByOwnerEmail.put(ownerEmail, new List<Property_Document__c>());
                        ownerNameByEmail.put(ownerEmail, doc.Property__r.Owner__r.Name__c);
                    }
                    propDocsByOwnerEmail.get(ownerEmail).add(doc);
                }
            }
            System.debug('Property_Document__c grouped by User email: ' + propDocsByUserEmail.size() + ' emails');
            System.debug('Property_Document__c grouped by Property Owner email: ' + propDocsByOwnerEmail.size() + ' emails');

            // Process Client_Document__c
            for (Client_Document__c doc : pendingClientDocs) {
                String email = doc.Client__r.Email__c;
                if (String.isNotBlank(email)) {
                    if (!clientDocsByEmail.containsKey(email)) {
                        clientDocsByEmail.put(email, new List<Client_Document__c>());
                        clientNameByEmail.put(email, doc.Client__r.Name__c);
                    }
                    clientDocsByEmail.get(email).add(doc);
                }
            }
            System.debug('Client_Document__c grouped by email: ' + clientDocsByEmail.size() + ' emails');

            // Process Payment__c
            for (Payment__c payment : pendingPayments) {
                String email = payment.Client__r.Email__c;
                if (String.isNotBlank(email)) {
                    if (!paymentsByEmail.containsKey(email)) {
                        paymentsByEmail.put(email, new List<Payment__c>());
                        clientNameByEmail.put(email, payment.Client__r.Name__c);
                    }
                    paymentsByEmail.get(email).add(payment);
                }
            }
            System.debug('Payment__c grouped by email: ' + paymentsByEmail.size() + ' emails');

            // Get Org-Wide Email Address (replace with your verified email)
            String orgWideEmailId;
            try {
                OrgWideEmailAddress owa = [SELECT Id FROM OrgWideEmailAddress WHERE Address = 'noreply@yourorg.com' WITH SECURITY_ENFORCED LIMIT 1];
                orgWideEmailId = owa.Id;
                System.debug('Org-Wide Email Address ID: ' + orgWideEmailId);
            } catch (Exception e) {
                System.debug('Org-Wide Email Address not found: ' + e.getMessage());
            }

            // Prepare email messages
            List<Messaging.SingleEmailMessage> emails = new List<Messaging.SingleEmailMessage>();
            Set<String> allEmails = new Set<String>();
            allEmails.addAll(propDocsByUserEmail.keySet());
            allEmails.addAll(propDocsByOwnerEmail.keySet());
            allEmails.addAll(clientDocsByEmail.keySet());
            allEmails.addAll(paymentsByEmail.keySet());
            System.debug('Total unique emails to process: ' + allEmails.size());

            for (String email : allEmails) {
                List<Property_Document__c> userPropDocs = propDocsByUserEmail.get(email) != null ? propDocsByUserEmail.get(email) : new List<Property_Document__c>();
                List<Property_Document__c> ownerPropDocs = propDocsByOwnerEmail.get(email) != null ? propDocsByOwnerEmail.get(email) : new List<Property_Document__c>();
                List<Client_Document__c> clientDocs = clientDocsByEmail.get(email) != null ? clientDocsByEmail.get(email) : new List<Client_Document__c>();
                List<Payment__c> payments = paymentsByEmail.get(email) != null ? paymentsByEmail.get(email) : new List<Payment__c>();
                if (userPropDocs.isEmpty() && ownerPropDocs.isEmpty() && clientDocs.isEmpty() && payments.isEmpty()) {
                    continue;
                }

                // Use Property Owner name if available, else Client name, else default to 'Client'
                String recipientName = ownerNameByEmail.get(email) != null ? ownerNameByEmail.get(email) : 
                                      clientNameByEmail.get(email) != null ? clientNameByEmail.get(email) : 'Client';
                String emailBody = 'Dear ' + recipientName + ',\n\n';
                emailBody += 'You have pending actions in the Property Management System. Please review and complete the following:\n\n';

                // User-assigned Property Documents (OwnerId)
                if (!userPropDocs.isEmpty()) {
                    emailBody += 'Assigned Property Documents:\n';
                    for (Property_Document__c doc : userPropDocs) {
                        emailBody += '- Document: ' + doc.Name + '\n';
                        emailBody += '  Property: ' + doc.Property__r.Name + '\n';
                        emailBody += '  Type: ' + doc.Document_Type__c + '\n';
                        emailBody += '  Status: ' + doc.Status__c + '\n';
                        emailBody += '  Pending Reason: ' + (String.isBlank(doc.Pending_Reason__c) ? 'N/A' : doc.Pending_Reason__c) + '\n\n';
                    }
                }

                // Property Owner Property Documents (Property__r.Owner__r.Email__c)
                if (!ownerPropDocs.isEmpty()) {
                    emailBody += 'Property Owner Documents:\n';
                    for (Property_Document__c doc : ownerPropDocs) {
                        emailBody += '- Document: ' + doc.Name + '\n';
                        emailBody += '  Property: ' + doc.Property__r.Name + '\n';
                        emailBody += '  Type: ' + doc.Document_Type__c + '\n';
                        emailBody += '  Status: ' + doc.Status__c + '\n';
                        emailBody += '  Pending Reason: ' + (String.isBlank(doc.Pending_Reason__c) ? 'N/A' : doc.Pending_Reason__c) + '\n\n';
                    }
                }

                // Client Documents
                if (!clientDocs.isEmpty()) {
                    emailBody += 'Client Documents:\n';
                    for (Client_Document__c doc : clientDocs) {
                        emailBody += '- Document: ' + doc.Name + '\n';
                        emailBody += '  Type: ' + doc.Document_Type__c + '\n';
                        emailBody += '  Status: ' + doc.Status__c + '\n';
                        emailBody += '  Pending Reason: ' + (String.isBlank(doc.Pending_Reason__c) ? 'N/A' : doc.Pending_Reason__c) + '\n\n';
                    }
                }

                // Pending Payments
                if (!payments.isEmpty()) {
                    emailBody += 'Pending Payments:\n';
                    for (Payment__c payment : payments) {
                        emailBody += '- Payment: ' + payment.Name + '\n';
                        emailBody += '  Property: ' + payment.Property__r.Name + '\n';
                        emailBody += '  Amount: ' + payment.Amount__c + '\n';
                        emailBody += '  Due Date: ' + payment.Due_Date__c.format() + '\n';
                        emailBody += '  Status: ' + payment.Status__c + '\n\n';
                    }
                }

                emailBody += 'Please log in to the Property Management System to complete these actions.\n';
                emailBody += 'Best regards,\nProperty Management Team';

                Messaging.SingleEmailMessage emailMsg = new Messaging.SingleEmailMessage();
                emailMsg.setToAddresses(new List<String>{email});
                emailMsg.setSubject('Pending Actions Reminder');
                emailBody += 'Best regards,\nProperty Management Team';
                emailMsg.setPlainTextBody(emailBody);
                if (orgWideEmailId != null) {
                    emailMsg.setOrgWideEmailAddressId(orgWideEmailId);
                } else {
                    emailMsg.setSenderDisplayName('Property Management System');
                }
                emails.add(emailMsg);
                System.debug('Prepared email for: ' + email + ', Body length: ' + emailBody.length());
            }

            // Send emails
            if (!emails.isEmpty()) {
                Messaging.SendEmailResult[] results = Messaging.sendEmail(emails);
                for (Messaging.SendEmailResult result : results) {
                    if (!result.isSuccess()) {
                        System.debug('Email send failed: ' + result.getErrors());
                    }
                }
                System.debug('Emails sent: ' + emails.size());
            } else {
                System.debug('No emails to send.');
            }

            // Delete old records
            List<Property_Document__c> oldPropDocs = [
                SELECT Id, Property__c
                FROM Property_Document__c
                WHERE CreatedDate < :cutoffDate
                AND Status__c != 'Complete'
                AND Document_Type__c = 'Deed'
                WITH SECURITY_ENFORCED
            ];
            System.debug('Old Property_Document__c records to delete: ' + oldPropDocs.size());

            List<Client_Document__c> oldClientDocs = [
                SELECT Id
                FROM Client_Document__c
                WHERE CreatedDate < :cutoffDate
                AND Status__c != 'Complete'
                AND Document_Type__c = 'Contract'
                WITH SECURITY_ENFORCED
            ];
            System.debug('Old Client_Document__c records to delete: ' + oldClientDocs.size());

            List<Payment__c> oldPayments = [
                SELECT Id, Property__c
                FROM Payment__c
                WHERE CreatedDate < :cutoffDate
                AND Status__c = 'Pending'
                WITH SECURITY_ENFORCED
            ];
            System.debug('Old Payment__c records to delete: ' + oldPayments.size());

            // Find related Client_Property_Interaction__c records
            Set<Id> propertyIds = new Set<Id>();
            for (Property_Document__c doc : oldPropDocs) {
                propertyIds.add(doc.Property__c);
            }
            for (Payment__c payment : oldPayments) {
                propertyIds.add(payment.Property__c);
            }

            List<Client_Property_Interaction__c> oldInteractions = [
                SELECT Id
                FROM Client_Property_Interaction__c
                WHERE Property__c IN :propertyIds
                AND Interaction_Type__c = 'Inquired'
                AND Status__c = 'Active'
                WITH SECURITY_ENFORCED
            ];
            System.debug('Old Client_Property_Interaction__c records to delete: ' + oldInteractions.size());

            // Perform deletions
            if (!oldInteractions.isEmpty()) {
                if (Schema.sObjectType.Client_Property_Interaction__c.isDeletable()) {
                    delete oldInteractions;
                    System.debug('Deleted Client_Property_Interaction__c records: ' + oldInteractions.size());
                } else {
                    System.debug('Insufficient permissions to delete Client_Property_Interaction__c records.');
                }
            }

            if (!oldClientDocs.isEmpty()) {
                if (Schema.sObjectType.Client_Document__c.isDeletable()) {
                    delete oldClientDocs;
                    System.debug('Deleted Client_Document__c records: ' + oldClientDocs.size());
                } else {
                    System.debug('Insufficient permissions to delete Client_Document__c records.');
                }
            }

            if (!oldPropDocs.isEmpty()) {
                if (Schema.sObjectType.Property_Document__c.isDeletable()) {
                    delete oldPropDocs;
                    System.debug('Deleted Property_Document__c records: ' + oldPropDocs.size());
                } else {
                    System.debug('Insufficient permissions to delete Property_Document__c records.');
                }
            }

            if (!oldPayments.isEmpty()) {
                if (Schema.sObjectType.Payment__c.isDeletable()) {
                    delete oldPayments;
                    System.debug('Deleted Payment__c records: ' + oldPayments.size());
                } else {
                    System.debug('Insufficient permissions to delete Payment__c records.');
                }
            }

        } catch (Exception e) {
            System.debug('Error in PendingActionsReminder: ' + e.getMessage() + ', Stack: ' + e.getStackTraceString());
            // Optionally log to a custom object or notify admin
        }
    }
}