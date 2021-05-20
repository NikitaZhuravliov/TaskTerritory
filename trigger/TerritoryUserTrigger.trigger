trigger TerritoryUserTrigger on TerritoryUser__c (after insert, after update, after delete) {
    if(Trigger.isInsert) {
        for(TerritoryUser__c territoryUser : Trigger.new) {
            TerritoryUserTriggerHandler.shareToUserById(territoryUser.User__c);
        }
    }

    if(Trigger.isUpdate) {
        for(TerritoryUser__c territoryUser : Trigger.new) {
            // Close all sharing.
            TerritoryUserTriggerHandler.closeAccessForUser(territoryUser.User__c);
            // Add sharing.
            TerritoryUserTriggerHandler.shareToUserById(territoryUser.User__c);
        }
    }

    if(Trigger.isDelete) {
        for(TerritoryUser__c territoryUser : Trigger.old) {
            // Close all sharing.
            TerritoryUserTriggerHandler.closeAccessForUser(territoryUser.User__c);
            // Add sharing.
            TerritoryUserTriggerHandler.shareToUserById(territoryUser.User__c);
        }
    }
}
