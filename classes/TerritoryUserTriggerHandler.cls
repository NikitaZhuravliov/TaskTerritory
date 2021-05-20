public with sharing class TerritoryUserTriggerHandler {

    public static void shareToUserById(Id idUser) {
        List<TerritoryUser__c> territoryUserList = createTerritoryUserListById(idUser);

        // List of the territories for the current user.
        List<Id> currentUserTerritoryList = new List<Id>();

        for(TerritoryUser__c territoryUser : territoryUserList) {
            currentUserTerritoryList.add(territoryUser.Territory__r.Id);

            // Get sub territories for the territory.
            List<Territory__c> subTerritoriesList = createSubTerritoryList(territoryUser.Territory__r.Id);
            if(subTerritoriesList.size() != 0) {
                // Add each sub territory to the currentUserTerritoryList.
                for(Territory__c subTerritory : subTerritoriesList) {
                    currentUserTerritoryList.add(subTerritory.Id);
                }
            }

            // Add Sharing.
            addSharing(currentUserTerritoryList, idUser);
        }
    }

    // Get TerritoryUser list by User ID.
    private static List<TerritoryUser__c> createTerritoryUserListById(Id idUser) {
        return [SELECT Name, Territory__r.Id, User__r.Id FROM TerritoryUser__c WHERE User__r.Id =: idUser];
    }

    // Get all sub territories for the territory.
    private static List <Territory__c> createSubTerritoryList(Id territoryId) {
        List<Territory__c> allSubTerritories = new List<Territory__c>();
        List <Territory__c> subTerritoriesList = [SELECT Id, Name FROM Territory__c WHERE Parent_Territory__r.Id =: territoryId];
        allSubTerritories.addAll(subTerritoriesList);
        for(Territory__c subTerritory : subTerritoriesList) {
            List <Territory__c> subTerritories = createSubTerritoryList(subTerritory.Id);
            allSubTerritories.addAll(subTerritories);
        }

        return allSubTerritories;
    }

    // Add Sharing.
    private static void addSharing(List<Id> currentUserTerritoryList, Id idUser) {
        List<AccountShare> accountShareList = new List<AccountShare>();
        List<ContactShare> contactShareList = new List<ContactShare>();

        if (currentUserTerritoryList.size() != 0) {
            System.debug(currentUserTerritoryList);
            for (Id territoryId : currentUserTerritoryList) {
                // Add Account sharing based on territory and sub territory.
                List <Account> accountList = getAccountListBasedOnTerritoryId(territoryId);
                if (accountList.size() != 0) {
                    for (Account account : accountList) {
                        // Share Account.
                        AccountShare accountShare = new AccountShare();
                        accountShare.AccountId = account.Id;
                        accountShare.UserOrGroupId = idUser;
                        accountShare.OpportunityAccessLevel = 'none';
                        accountShare.AccountAccessLevel = 'Edit';
                        accountShareList.add(accountShare);

                        // Share Contacts.
                        List <Reference__c> contactList = getContactListBasedOnAccountId(account.Id);
                        if (contactList.size() != 0) {
                            for (Reference__c contact : contactList) {
                                ContactShare contactShare = new ContactShare();
                                contactShare.ContactId = contact.Contacts__r.Id;
                                contactShare.UserOrGroupId = idUser;
                                contactShare.ContactAccessLevel = 'Edit';
                                contactShareList.add(contactShare);
                            }
                        }
                    }
                }
            }
        }

        Database.upsert(accountShareList, false);
        Database.upsert(contactShareList, false);
    }

    // Get list of Accounts based on territory id.
    private static List<Account> getAccountListBasedOnTerritoryId(Id territoryId) {
        return [SELECT Id FROM Account WHERE Territory__r.Id = :territoryId];
    }

    // Get list of Contacts based on Account Id.
    private static List<Reference__c> getContactListBasedOnAccountId(Id accountId) {
        return [SELECT Contacts__r.Id FROM Reference__c WHERE Account__r.Id = :accountId];
    }

    public static void closeAccessForUser(Id idUser) {
        List<ContactShare> contactShares = getContactShareListForDelete(idUser);
        Database.delete (contactShares, false);

        List <AccountShare> accountShares = getAccountShareForDelete (idUser);
        Database.delete (accountShares, false);

        List <Territory__Share> territoryShares = getTerritoryShareListForDel (idUser);
        Database.delete (territoryShares, false);
    }

    private static List <ContactShare> getContactShareListForDelete (Id idUser) {
        return [SELECT Id, ContactId, UserOrGroupId FROM ContactShare WHERE  UserOrGroupId = :idUser];
    }

    private static List<AccountShare> getAccountShareForDelete (Id idUser){
        return [SELECT Id, AccountId, UserOrGroupId FROM  AccountShare WHERE UserOrGroupId = :idUser];
    }

    private static List<Territory__Share> getTerritoryShareListForDel (Id idUser) {
        return [SELECT Id FROM Territory__Share WHERE UserOrGroupId = :idUser];
    }
}