public with sharing class AgentAPIConfig {
    public static Agent_API_Config__c getConfig(String name) {
        try {
            return [SELECT Agent_Id__c, API_Type__c, Auth_Token__c, ConsumerKey__c, ConsumerSecret__c, 
                    Developer_Name__c, Entry_Id__c, Name, Org_Id__c, Org_Url__c, Session_Id__c  
                    FROM Agent_API_Config__c
                    WHERE Name = :name];
        } catch (Exception ex) {
            System.debug('Error retrieving API config: ' + ex.getMessage());
            return new Agent_API_Config__c();
        }
    }

    public static String saveConfig(Agent_API_Config__c record) {
        try {
            update record;
            return 'Update Successful';
        } catch (Exception ex) {
            System.debug('Update failed: ' + ex.getMessage());
            return ('Update failed: ' + ex.getMessage());
        }
    }
}