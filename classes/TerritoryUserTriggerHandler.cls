public with sharing class TerritoryUserTriggerHandler {

    public void onInsert(TerritoryUser__c[] newTerritoryUser) {
        List<SObject> objectsToShare = new List<SObject>();
        Map<Id, Id> territoryToUser = new Map<Id, Id>();
        for(TerritoryUser__c territoryUser : newTerritoryUser) {
            territoryToUser.put(territoryUser.Territory__c, territoryUser.User__c);
            objectsToShare.addAll(shareTerritoriesToUser(territoryToUser));
        }

        Database.upsert(objectsToShare, false);
    }

    public void onUpdate(TerritoryUser__c[] newTerritoryUser, TerritoryUser__c[] oldTerritoryUser) {
        // Old record.
        List<SObject> objectsToDeleteSharingOld = new List<SObject>();
        List<SObject> objectsToShareOld = new List<SObject>();
        Map<Id, Id> territoryToUserOld = new Map<Id, Id>();
        for(TerritoryUser__c territoryUser : oldTerritoryUser) {
            // Close all sharing.
            objectsToDeleteSharingOld.addAll(closeSharingTerritoriesToUser(territoryUser.User__c));
            // Add sharing except deleted.
            territoryToUserOld.putAll(getAllTerritoryUser(territoryUser.User__c));
            territoryToUserOld.remove(territoryUser.Territory__c);
            objectsToShareOld.addAll(shareTerritoriesToUser(territoryToUserOld));
        }

        Database.delete(objectsToDeleteSharingOld, false);
        Database.upsert(objectsToShareOld, false);

        // New record.
        List<SObject> objectsToDeleteSharingNew = new List<SObject>();
        List<SObject> objectsToShareNew = new List<SObject>();
        Map<Id, Id> territoryToUserNew = new Map<Id, Id>();
        for(TerritoryUser__c territoryUser : newTerritoryUser) {
            territoryToUserNew.put(territoryUser.Territory__c, territoryUser.User__c);
            // Close all sharing.
            objectsToDeleteSharingNew.addAll(closeSharingTerritoriesToUser(territoryUser.User__c));
            // Add sharing.
            territoryToUserNew.putAll(getAllTerritoryUser(territoryUser.User__c));
            objectsToShareNew.addAll(shareTerritoriesToUser(territoryToUserNew));
        }

        Database.delete(objectsToDeleteSharingNew, false);
        Database.upsert(objectsToShareNew, false);
    }

    public void onDelete(TerritoryUser__c[] oldTerritoryUser) {
        List<SObject> objectsToDeleteSharing = new List<SObject>();
        List<SObject> objectsToShare = new List<SObject>();
        Map<Id, Id> territoryToUser = new Map<Id, Id>();
        for(TerritoryUser__c territoryUser : oldTerritoryUser) {
            // Close all sharing.
            objectsToDeleteSharing.addAll(closeSharingTerritoriesToUser(territoryUser.User__c));
            // Add sharing except deleted.
            territoryToUser.putAll(getAllTerritoryUser(territoryUser.User__c));
            territoryToUser.remove(territoryUser.Territory__c);
            objectsToShare.addAll(shareTerritoriesToUser(territoryToUser));
        }

        Database.delete(objectsToDeleteSharing, false);
        Database.upsert(objectsToShare, false);
    }

    public void onUndelete(TerritoryUser__c[] newTerritoryUser) {
        List<SObject> objectsToShare = new List<SObject>();
        Map<Id, Id> territoryToUser = new Map<Id, Id>();
        for(TerritoryUser__c territoryUser : newTerritoryUser) {
            territoryToUser.put(territoryUser.Territory__c, territoryUser.User__c);
            objectsToShare.addAll(shareTerritoriesToUser(territoryToUser));
        }

        Database.upsert(objectsToShare, false);
    }

    // Share territories to user.
    public List<SObject> shareTerritoriesToUser(Map<Id, Id> territoryToUser) {
        List<SObject> objectsToShare = new List<SObject>();

        for(Id territoryId : territoryToUser.keySet()) {
            Map<Id, Territory__c> subTerritories = getSubTerritories(territoryId);
            subTerritories.putAll(new Map<Id, Territory__c>([SELECT Id FROM Territory__c WHERE Id = :territoryId]));
            Id userId = territoryToUser.get(territoryId);
            objectsToShare.addAll(addSharing(subTerritories, userId));
        }

        return objectsToShare;
    }

    // Share territories to user.
    public Map<Id, Territory__c> getSubTerritories(Id territoryId) {
        Map<Id, Territory__c> allSubTerritories = new Map<Id, Territory__c>();
        Map<Id, Territory__c> subTerritories = new Map<Id, Territory__c>([SELECT Id
            FROM Territory__c
            WHERE Parent_Territory__c = :territoryId
        ]);

        allSubTerritories.putAll(subTerritories);

        if (!subTerritories.isEmpty()) {
            for(Territory__c subTerritory : subTerritories.values()) {
                Map<Id, Territory__c> subSubTerritories = getSubTerritories(subTerritory.Id);
                allSubTerritories.putAll(subSubTerritories);
            }
        }

        return allSubTerritories;
    }

    // Add Sharing.
    private List<SObject> addSharing(Map<Id, Territory__c> subTerritories, Id userId) {
        List<SObject> objectsToShare = new List<SObject>();
        List<SObject> accountsToShare = new List<SObject>();
        List<SObject> contactsToShare = new List<SObject>();

        if(!subTerritories.isEmpty()) {
            for (Id territoryId : subTerritories.keySet()) {
                // Add Account sharing based on territory and sub territory.
                Map<Id, Account> accounts = getAccountsBasedOnTerritoryId(territoryId);
                if (!accounts.isEmpty()) {
                    for (Id accountId : accounts.keySet()) {
                        // Share Account.
                        AccountShare accountShare = new AccountShare();
                        accountShare.AccountId = accountId;
                        accountShare.UserOrGroupId = userId;
                        accountShare.OpportunityAccessLevel = 'none';
                        accountShare.AccountAccessLevel = 'Edit';
                        accountsToShare.add(accountShare);

                        // Share Contacts.
                        Map<Id, Reference__c> contacts = getContactsBasedOnAccountId(accountId);
                        if (!contacts.isEmpty()) {
                            for (Reference__c contact : contacts.values()) {
                                ContactShare contactShare = new ContactShare();
                                contactShare.ContactId = contact.Contacts__r.Id;
                                contactShare.UserOrGroupId = userId;
                                contactShare.ContactAccessLevel = 'Edit';
                                contactsToShare.add(contactShare);
                            }
                        }
                    }
                }
            }
        }

        objectsToShare.addAll(accountsToShare);
        objectsToShare.addAll(contactsToShare);
        return objectsToShare;
    }

    // Get Accounts map based on Territory id.
    private Map<Id, Account> getAccountsBasedOnTerritoryId(Id territoryId) {
        return new Map<Id, Account>([SELECT Id FROM Account WHERE Territory__r.Id = :territoryId]);
    }

    // Get Contacts map based on Account Id.
    private Map<Id, Reference__c> getContactsBasedOnAccountId(Id accountId) {
        return new Map<Id, Reference__c>([SELECT Contacts__r.Id FROM Reference__c WHERE Account__r.Id = :accountId]);
    }

    // Close sharing by user Id on specified territories.
    public List<SObject> closeSharingTerritoriesToUser(Id userId) {
        List<SObject> objectsToCloseSharing = new List<SObject>();

        // Close Account Sharing.
        Map<Id, AccountShare> accountShares = getAccountsShareForDelete(userId);
        objectsToCloseSharing.addAll(accountShares.values());

        // Close Contacts Sharing.
        Map<Id, ContactShare> contactShares = getContactsShareForDelete(userId);
        objectsToCloseSharing.addAll(contactShares.values());

        return objectsToCloseSharing;
    }

    // Get all territory to user.
    public Map<Id, Id> getAllTerritoryUser(Id userId) {
        Map<Id, Id> territoryToUser = new Map<Id, Id>();
        Map<Id, TerritoryUser__c> territoriesUser = new Map<Id, TerritoryUser__c>([SELECT Territory__c, User__c FROM TerritoryUser__c WHERE User__c = :userId]);
        System.debug(territoriesUser);
        for(TerritoryUser__c territoryUser : territoriesUser.values()) {
            System.debug(territoryUser);
            territoryToUser.put(territoryUser.Territory__c, territoryUser.User__c);
        }

        return territoryToUser;
    }

    // Get ContactShare map.
    private Map<Id, ContactShare> getContactsShareForDelete (Id userId) {
        return new Map<Id, ContactShare>([SELECT Id, ContactId, UserOrGroupId FROM ContactShare WHERE UserOrGroupId = :userId]);
    }

    // Get AccountShare map.
    private Map<Id, AccountShare> getAccountsShareForDelete (Id userId){
        return new Map<Id, AccountShare>([SELECT Id, AccountId, UserOrGroupId FROM AccountShare WHERE UserOrGroupId = :userId]);
    }
}