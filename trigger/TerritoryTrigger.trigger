trigger TerritoryTrigger on Territory__c (before insert, before update) {
    TerritoryTriggerHandler handler = new TerritoryTriggerHandler();
    handler.addTerritoryError(Trigger.new);
}
