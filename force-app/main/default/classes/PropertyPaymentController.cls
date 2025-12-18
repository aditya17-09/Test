public with sharing class PropertyPaymentController {
    @AuraEnabled
    public static String initiatePayment(String propertyId, String clientId, Decimal amount, Datetime dueDate) {
        String errorContext = 'Initial validation';
        try {
            if (String.isBlank(propertyId) || !Pattern.matches('[a-zA-Z0-9]{15,18}', propertyId)) {
                throw new AuraHandledException('Invalid or missing property ID.');
            }
            if (String.isBlank(clientId)) {
                throw new AuraHandledException('Invalid or missing client ID.');
            }
            if (amount <= 0) {
                throw new AuraHandledException('Payment amount must be greater than zero.');
            }
            if (dueDate == null || dueDate < System.now()) {
                throw new AuraHandledException('Due date is required and cannot be in the past.');
            }

            errorContext = 'Validating client document';
            List<Client_Document__c> docs = [
                SELECT Id, Status__c
                FROM Client_Document__c
                WHERE Client__c = :clientId
                AND Document_Type__c = 'Contract'
                AND Status__c = 'Complete'
                WITH SECURITY_ENFORCED
                LIMIT 1
            ];
            if (docs.isEmpty()) {
                throw new AuraHandledException('A completed contract is required before initiating payment.');
            }

            errorContext = 'Creating payment record';
            Payment__c payment = new Payment__c(
                Client__c = clientId,
                Property__c = propertyId,
                Amount__c = amount,
                Due_Date__c = dueDate,
                Status__c = 'Pending',
                OwnerId = UserInfo.getUserId()
            );
            insert payment;

            errorContext = 'Generating .ics file';
            String icsContent = PropertyVisitController.generatePaymentIcs(payment.Id, propertyId, clientId, amount, dueDate);

            return icsContent;
        } catch (Exception e) {
            String errorMessage = 'Error in initiatePayment at ' + errorContext + ': ' + e.getMessage() + '\nStack Trace: ' + e.getStackTraceString();
            System.debug(LoggingLevel.ERROR, errorMessage);
            throw new AuraHandledException('Error initiating payment: ' + e.getMessage());
        }
    }
}