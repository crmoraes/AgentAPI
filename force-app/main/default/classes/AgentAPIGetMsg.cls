public with sharing class AgentAPIGetMsg {
    // Apex Class - Input
    public class inputVar {
        @InvocableVariable(label='API Configuration Name' required=true)
        public String APIConfigName;
    }
    
    // Apex Class - Response
    public class outputVar {
        @InvocableVariable
        public String entryId;
        @InvocableVariable
        public String Response;
        @InvocableVariable
        public Boolean isAgentReady;
    }
    
    // Method to get the last response (last enntry in a conversation)
    @InvocableMethod(label='Agent API MIAW Get Response' description='Get Last Response from the AI Agent')
    public static List<outputVar> getResp(List<inputVar> input) {
        // Set output paramaters
        List<outputVar> msgResp = new List<outputVar>();
        outputVar msg = new outputVar();
        msg.entryId = '';
        msg.Response = '';
        msg.isAgentReady = false;
       
        String responseRole = '';
        
        // Retrieve Agent API configuration parameters
        Agent_API_Config__c recAPIConfig = AgentAPIConfig.getConfig(input[0].APIConfigName);
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        // Set endpoint and HTTP method
        request.setEndpoint(recAPIConfig.Org_Url__c + '/iamessage/api/v2/conversation/' + recAPIConfig.Session_Id__c + '/entries?entryTypeFilter=Message&limit=1');
        request.setMethod('GET');
        
        // Set headers
        request.setHeader('Authorization', 'Bearer '+recAPIConfig.Auth_Token__c);
        
        // Set counter to control a max of 4 loop
        Integer counter = 1;
        Integer maxLoop = 4;
        do {
            HttpResponse response;
            
            try {
                // Execute the HTTP request
                response = http.send(request);
                
                // Process the response
                if (response.getStatusCode() == 200) {
                    // Deserialize JSON response
                    String payload = response.getBody();
                    System.debug('response: ' + payload);
                    
                    Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(payload);
                    
                    List<Object> records = (List<Object>) jsonMap.get('conversationEntries'); //get last entry
                    if (records != null) {
                        for (Object r : records) {
                            Map<String,Object> rMap = (Map<String,Object>)r;
                            Map<String,Object> sender = (Map<String,Object>)rMap.get('sender');
                            responseRole = (String) sender.get('role');
                            Map<String,Object> ePayload = (Map<String,Object>)rMap.get('entryPayload');
                            msg.entryId = (String) ePayload.get('id');
                            
                            Map<String,Object> aMsg = (Map<String,Object>)ePayload.get('abstractMessage');
                            Map<String,Object> sContent = (Map<String,Object>)aMsg.get('staticContent');
                            msg.Response = (String) sContent.get('text');
                        }
                    } else {
                        system.debug('break - null.. : ' + records);
                    }
                }
            } catch (System.CalloutException e) {
                counter = maxLoop;
                System.debug('HTTP Request failed: ' + e.getMessage());
                throw new AuraHandledException('HTTP Request failed: ' + e.getMessage());
            }
            
            msg.isAgentReady = (responseRole == 'Chatbot' || responseRole == 'Agent');

            if (counter < maxLoop && msg.isAgentReady == false) {
                // Wait 3 seconds
                Long startTimerTime = DateTime.now().getTime();
                Long finishTimerTime = DateTime.now().getTime();
                
                while ((finishTimerTime - startTimerTime ) < (3 * 1000)) {
                    finishTimerTime = DateTime.now().getTime();
                }
            }
            
        } while (counter++ < maxLoop && msg.isAgentReady == false);
        
        msgResp.add(msg);
        return msgResp;
    }
}