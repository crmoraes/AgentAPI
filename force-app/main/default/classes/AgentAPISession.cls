public with sharing class AgentAPISession {
    // Apex Class - Input
    public class inputVar {
        @InvocableVariable(label='API Configuration Name' required=true)
        public String APIConfigName;
    }
    
    // Apex Class - Response
    public class outputVar {
        @InvocableVariable
        public String sessionId;
        @InvocableVariable
        public String Response;
        @InvocableVariable
        public Boolean isSessionActive;
    }
    
    // Agent aPI - Request Payload
    public class reqPayload {
        public String externalSessionKey;
        public InstanceConfig instanceConfig;
        public String tz;
        public List<String> variables;
        public String featureSupport;
        public StreamingCapabilities streamingCapabilities;
        
        public reqPayload(String sessionKey, String orgURL) {
            this.externalSessionKey = sessionKey;
            this.instanceConfig = new InstanceConfig(orgURL);
            this.tz = 'America/New_York';
            this.variables = new List<String>();
            this.featureSupport = 'Sync';
            this.streamingCapabilities = new StreamingCapabilities();
        }
    }
    
    public class InstanceConfig {
        public String endpoint;
        
        public InstanceConfig(String orgURL) {
            this.endpoint = orgURL;
        }
    }
    
    public class StreamingCapabilities {
        public List<String> chunkTypes = new List<String>();
        
        public StreamingCapabilities() {
            this.chunkTypes.add('Text');
        }
    }
    
    // MIAW API - Class to represent the request payload
    public class RequestPayload {
        public String conversationId;
        public RoutingAttributes routingAttributes;
        public String esDeveloperName;
        
        // Constructor
        public RequestPayload(String conversationId, String esDeveloperName) {
            this.conversationId = conversationId;
            this.routingAttributes = new RoutingAttributes('Claudio','Moraes','cm@example.com');
            this.esDeveloperName = esDeveloperName;
        }
    }
    
    // Inner class for routingAttributes
    public class RoutingAttributes {
        public String firstName;
        public String lastName;
        public String email;
        
        // Constructor
        public RoutingAttributes(String firstName, String lastName, String email) {
            this.firstName = firstName;
            this.lastName = lastName;
            this.email = email;
        }
    }
    
    // Method to create a new Conversation Session - List<inputVar> input
    @InvocableMethod(label='Agent API Create Conversation Session' description='Create Conversation for AI Agent')
    public static List<outputVar> createSession(List<inputVar> input) {
        // Set output paramaters
        List<outputVar> msgResp = new List<outputVar>();
        outputVar msg = new outputVar();
        msg.sessionId = '';
        msg.Response = '';
        msg.isSessionActive = false;
        
        // Retrieve Agent API configuration parameters
        Agent_API_Config__c recAPIConfig = AgentAPIConfig.getConfig(input[0].APIConfigName);
        
        // if expired request a new token
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        if (recAPIConfig.API_Type__c == 'Agent API') {
            // Set the endpoint and method
            request.setEndpoint('https://api.salesforce.com/einstein/ai-agent/v1/agents/' + recAPIConfig.Agent_Id__c + '/sessions');
            request.setMethod('POST');
            
            // Set headers
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', 'Bearer ' + recAPIConfig.Auth_Token__c);
            
            // Generate Random UUID for new Conversation
            UUID randomUUID = UUID.randomUUID();
            
            // Prepare JSON body
            reqPayload payload = new reqPayload(randomUUID.toString(), recAPIConfig.Org_Url__c);
            String jsonBody = JSON.serialize(payload);
            System.debug('JSON: ' + jsonBody);
            
            request.setBody(jsonBody);
            
            // Execute the HTTP request
            HttpResponse response;
            try {
                response = http.send(request);
                
                // Process the response
                if (response.getStatusCode() == 200) {
                    // Deserialize JSON response
                    Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
                    
                    String sContent = (String) jsonMap.get('sessionId'); //get the entries
                    if (sContent != null) {
                        //return tokenResponse;
                        msg.sessionId = sContent;
                        msg.Response = 'Session Active';
                    } else {
                        msg.Response = 'break - response null';
                    }
                } else {
                    // Handle errors
                    System.debug('Error: ' + response.getStatusCode() + ' - ' + response.getBody());
                    msg.Response = response.getBody();
                }
            } catch (System.CalloutException e) {
                System.debug('HTTP Request failed: ' + e.getMessage());
                msg.Response = e.getMessage();
            }
            
        } else if (recAPIConfig.API_Type__c == 'MIAW API') {
            // Set the endpoint and method
            request.setEndpoint(recAPIConfig.Org_Url__c + '/iamessage/api/v2/conversation');
            request.setMethod('POST');
            
            // Set headers
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', 'Bearer ' + recAPIConfig.Auth_Token__c);
            
            // Generate Random UUID for new Conversation
            UUID randomUUID = UUID.randomUUID();
            
            // Prepare JSON body
            RequestPayload payload = new RequestPayload(randomUUID.toString(), recAPIConfig.Developer_Name__c);
            String jsonBody = JSON.serialize(payload);
            request.setBody(jsonBody);
            
            // Execute the HTTP request
            HttpResponse response;
            try {
                response = http.send(request);
                // Process the response
                if (response.getStatusCode() == 201) {
                    msg.sessionId = randomUUID.toString();
                    msg.Response = 'Session Active';
                } else {
                    System.debug('Error: ' + response.getStatusCode() + ' - ' + response.getBody());
                    msg.Response = response.getStatusCode() + ' - ' + response.getBody();
                }
            } catch (System.CalloutException e) {
                System.debug('HTTP Request failed: ' + e.getMessage());
                msg.Response = e.getMessage();
            }
        }
        
        try {
            // Save last message and auth token into the API Configuration record
            recAPIConfig.lastResponse__c = msg.Response;
            recAPIConfig.Session_Id__c = msg.sessionId;
            String saveMsg = AgentAPIConfig.saveConfig(recAPIConfig);
            
            if (msg.Response == 'Session Active') msg.isSessionActive = true;
        } catch (System.CalloutException e) {
            System.debug('Save failed: ' + e.getMessage());
            msg.Response = e.getMessage();
        }
        
        msgResp.add(msg);
        return msgResp;
    }
}