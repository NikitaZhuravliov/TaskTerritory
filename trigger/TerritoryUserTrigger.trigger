trigger TerritoryUserTrigger on TerritoryUser__c (after insert, after update, after delete, after undelete) {
    TerritoryUserTriggerHandler handler = new TerritoryUserTriggerHandler();

    if(Trigger.isInsert) {
        handler.onInsert(Trigger.new);
    }

    if(Trigger.isUpdate) {
        handler.onUpdate(Trigger.new, Trigger.old);
    }

    if(Trigger.isDelete) {
        handler.onDelete(Trigger.old);
    }

    if(Trigger.isUndelete) {
        handler.onUndelete(Trigger.new);
    }
}
