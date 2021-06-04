public with sharing class TerritoryTriggerHandler {
    public void addTerritoryError(Territory__c[] newTerritories) {
        for(Territory__c territory : newTerritories) {
            Map<Id, Territory__c> territories = new Map<Id, Territory__c>([SELECT Id
                FROM Territory__c
                WHERE Name = :territory.Name
                AND Parent_Territory__c = :territory.Parent_Territory__c
            ]);

            if (!territories.isEmpty()) {
                territory.addError('Territory with the same Name and in the same hierarchy can not be duplicated.');
            }
        }
    }
}