trigger TerritoryTrigger on Territory__c (before insert, before update) {
    for(Territory__c territory : Trigger.new) {
        List<Territory__c> territories = [SELECT Id
            FROM Territory__c
            WHERE Name = :territory.Name
            AND Parent_Territory__c = :territory.Parent_Territory__c
        ];

        if (territories.size() != 0) {
            territory.addError('Territory with the same Name and in the same hierarchy can not be duplicated.');
        }
    }
}