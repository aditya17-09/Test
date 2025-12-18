public with sharing class PagePersistenceController {
    @AuraEnabled
    public static void saveLastVisitedPage(String pageDetails) {
        try {
            if (String.isBlank(pageDetails)) {
                throw new AuraHandledException('Page details cannot be empty.');
            }
            User currentUser = [SELECT Id, Last_Visited_Page__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            currentUser.Last_Visited_Page__c = pageDetails;
            update currentUser;
        } catch (Exception e) {
            System.debug('Error saving last visited page: ' + e.getMessage());
            throw new AuraHandledException('Error saving page: ' + e.getMessage());
        }
    }

    @AuraEnabled(cacheable=true)
    public static String getLastVisitedPage() {
        try {
            User currentUser = [SELECT Last_Visited_Page__c FROM User WHERE Id = :UserInfo.getUserId() LIMIT 1];
            return String.isNotBlank(currentUser.Last_Visited_Page__c) ? currentUser.Last_Visited_Page__c : null;
        } catch (Exception e) {
            System.debug('Error retrieving last visited page: ' + e.getMessage());
            throw new AuraHandledException('Error retrieving page: ' + e.getMessage());
        }
    }
}