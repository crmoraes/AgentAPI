public with sharing class AgentAPIMIAWStreaming {
    // MIAW API Request Payload
    public class reqPayload {
        public String conversationId;
        public String esDeveloperName;
        
        public reqPayload(String myconvId, String myDevName) {
            this.conversationId = myconvId;
            this.esDeveloperName = myDevName;
        }
    }
    
    // Input parameters for Flow
    public class inputFlow {
        @InvocableVariable(label='API Configuration Record' required=true)
        public Agent_API_Config__c inputAgentAPI;
    }
    
    // Output parameters for Flow
    public class OutputFlow {
        @InvocableVariable
        public String response;
        
        @InvocableVariable
        public Boolean isSuccess;
        
        @InvocableVariable
        public String errorMessage;
    }
    
    // Method to handle streaming response
    
    @InvocableMethod(label='Agent MIAW API Streaming Response' description='Handle streaming response from MIAW API')
    public static List<OutputFlow> sendStreamResponse(List<InputFlow> input) {
        List<OutputFlow> responses = new List<OutputFlow>();
        OutputFlow output = new OutputFlow();
        output.isSuccess = False;
        output.response = '';
        output.errorMessage = '';
        
        try {
            // Pass the Agent API Config record to get the Token
            Agent_API_Config__c recAPIConfig = input[0].inputAgentAPI;
            
            // Prepare the HTTP request
            Http http = new Http();
            HttpRequest request = new HttpRequest();
            
            // Set endpoint for MIAW API streaming
            request.setEndpoint(recAPIConfig.Org_Url__c + '/eventrouter/v1/sse');
            request.setMethod('GET');
            
            // Set headers
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('X-Org-Id', recAPIConfig.Org_Id__c);
            request.setHeader('Authorization', 'Bearer ' + recAPIConfig.Auth_Token__c);
            request.setHeader('Accept', 'text/event-stream');
            
            // Prepare message payload
            reqPayload payload = new reqPayload(recAPIConfig.Session_Id__c, recAPIConfig.Developer_Name__c);
            String jsonBody = JSON.serialize(payload);
            System.debug('JSON: ' + jsonBody);
            
            request.setBody(jsonBody);
            
            // Set timeout to 120 seconds for streaming
            request.setTimeout(120000);
            
            // Execute the request
            HttpResponse response = http.send(request);
            
            if (response.getStatusCode() == 200) {
                // Deserialize JSON response
                jsonBody = response.getBody();
                System.debug('jsonBody : '+jsonBody);
                
                Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(jsonBody);
                
                Map<String,Object> convEntry = (Map<String,Object>)jsonMap.get('conversationEntry');
                if (convEntry != null) {
                    String senderName = (String) convEntry.get('senderDisplayName');
                    String entryType = (String) convEntry.get('entryType');
                    String entryPayload = (String) convEntry.get('entryPayload');
                    
                    Map<String,Object> sender = (Map<String,Object>)convEntry.get('sender');
                    String role = (String) sender.get('role');
                    String appType = (String) sender.get('appType');
                    
                    if ((entryType == 'Message') && (role == 'Chatbot')) {
                        output.response = entryPayload;
                        output.isSuccess = True;
                        output.errorMessage = '';
                    }
                }
            } else {
                // Handle errors
                output.response = 'Error:' + response.getStatusCode() + ' - ' + response.getBody();
            }
        } catch (Exception e) {
            output.isSuccess = false;
            output.errorMessage = 'Exception: ' + e.getMessage();
        }
        
        responses.add(output);
        return responses;
    }
}