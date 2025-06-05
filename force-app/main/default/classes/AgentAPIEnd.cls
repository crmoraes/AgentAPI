public with sharing class AgentAPIEnd {
    // Apex Class - Input from Flow
    public class inputFlow {
        @InvocableVariable(label='API Configuration Record' required=true)
        public Agent_API_Config__c inputAgentAPI;
    }
    
    // Method to close the conversation
    
    @InvocableMethod(label='Agent API End Session' description='Close Agent active session')
    public static void closeConv(List<inputFlow> input) {
        // Pass the Agent API Config record to get the Token
        Agent_API_Config__c recAPIConfig = input[0].inputAgentAPI;
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        if (recAPIConfig.API_Type__c == 'Agent API') {
            // Set endpoint and HTTP method
            request.setEndpoint('https://api.salesforce.com/einstein/ai-agent/v1/sessions/' + recAPIConfig.Session_Id__c);
            request.setMethod('DELETE');
            
            // Set headers
            request.setHeader('x-session-end-reason', 'UserRequest');
            request.setHeader('Authorization', 'Bearer ' + recAPIConfig.Auth_Token__c);
            
            // Execute the HTTP request
            HttpResponse response;
            try {
                response = http.send(request);
            } catch (System.CalloutException e) {
                System.debug('HTTP Request failed: ' + e.getMessage());
                throw new AuraHandledException('HTTP Request failed: ' + e.getMessage());
            }
        } else if (recAPIConfig.API_Type__c == 'MIAW API') {
            // Set endpoint and HTTP method
            request.setEndpoint(recAPIConfig.Org_Url__c + '/iamessage/api/v2/conversation/' + recAPIConfig.Session_Id__c + '?esDeveloperName=' + recAPIConfig.Developer_Name__c);
            request.setMethod('DELETE');
            
            // Set headers
            request.setHeader('Authorization', 'Bearer ' + recAPIConfig.Auth_Token__c);
            
            // Execute the HTTP request
            HttpResponse response;
            try {
                response = http.send(request);
            } catch (System.CalloutException e) {
                System.debug('HTTP Request failed: ' + e.getMessage());
                throw new AuraHandledException('HTTP Request failed: ' + e.getMessage());
            }
        }
    }
}