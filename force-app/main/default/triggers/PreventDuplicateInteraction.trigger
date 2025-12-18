trigger PreventDuplicateInteraction on Client_Property_Interaction__c (before insert, before update) {
    // Iterate through new or updated records
    for (Client_Property_Interaction__c interaction : Trigger.new) {
        // Skip if required fields are null to avoid query errors
        if (interaction.Client__c == null || interaction.Property__c == null || interaction.Interaction_Type__c == null) {
            continue;
        }
        // Check for existing records with matching Client, Property, and Interaction Type
        List<Client_Property_Interaction__c> existing = [
            SELECT Id
            FROM Client_Property_Interaction__c
            WHERE Client__c = :interaction.Client__c
            AND Property__c = :interaction.Property__c
            AND Interaction_Type__c = :interaction.Interaction_Type__c
            AND Id != :interaction.Id
            LIMIT 1
        ];
        // If a duplicate is found, add an error to prevent save
        if (!existing.isEmpty()) {
            interaction.addError('Duplicate interaction for this client, property, and interaction type.');
        }
    }
}