public with sharing class AgentAPIMessage {
    // Apex Class - Input
    public class inputVar {
        @InvocableVariable(label='API Configuration Name' required=true)
        public String APIConfigName;
        @InvocableVariable(label='Message to Send' required=true)
        public String msg2Send;
    }
    
    // Apex Class - Response
    public class outputVar {
        @InvocableVariable
        public String entryId;
        @InvocableVariable
        public String Response;
    }

    // Agent API - Request Payload
    public class reqPayload {
        public List<String> variables;
        public AgentMessage message;
        
        public reqPayload(String msg) {
            this.variables = new List<String>();
            this.message = new AgentMessage(msg);
        }
    }
    
    public class AgentMessage {
        public String text;
        public String type = 'Text';
        public String sequenceId = Datetime.now().format('yyyyMMddHHmmss');
        
        public AgentMessage(String msg) {
            this.text = msg;
        }
    }
    
    // MIAW API - Class to represent the request payload
    public class RequestPayload {
        public MIAWMessage message;
        public String esDeveloperName;
        public Boolean isNewMessagingSession;
        public RoutingAttributes routingAttributes;
        public String language;
        
        // Constructor
        public RequestPayload(MIAWMessage message, String esDeveloperName, Boolean isNewMessagingSession, RoutingAttributes routingAttributes, String language) {
            this.message = message;
            this.esDeveloperName = esDeveloperName;
            this.isNewMessagingSession = isNewMessagingSession;
            this.routingAttributes = routingAttributes;
            this.language = language;
        }
    }
    
    // Inner class for message
    public class MIAWMessage {
        public String inReplyToMessageId;
        public String id;
        public String messageType;
        public StaticContent staticContent;
        
        // Constructor
        public MIAWMessage(String inReplyToMessageId, String id, String messageType, StaticContent staticContent) {
            this.inReplyToMessageId = inReplyToMessageId;
            this.id = id;
            this.messageType = messageType;
            this.staticContent = staticContent;
        }
    }
    
    // Inner class for Static Content
    public class StaticContent {
        public String formatType;
        public String text;
        
        // Constructor
        public StaticContent(String formatType, String text) {
            this.formatType = formatType;
            this.text = text;
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
    
    // Method to send a new Message
    @InvocableMethod(label='Agent API Send Sync Message' description='Send Sync Message to Agent')
    public static List<outputVar> sendSyncMessage(List<inputVar> input) {
        // Set output paramaters
        List<outputVar> msgResp = new List<outputVar>();
        outputVar msg = new outputVar();
        msg.entryId = '';
        msg.Response = '';
        
        // Retrieve Agent API configuration parameters
        Agent_API_Config__c recAPIConfig = AgentAPIConfig.getConfig(input[0].APIConfigName);
        
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        if (recAPIConfig.API_Type__c == 'Agent API') {
            // Set the endpoint and method
            request.setEndpoint('https://api.salesforce.com/einstein/ai-agent/v1/sessions/' + recAPIConfig.Session_Id__c + '/messages');
            request.setMethod('POST');
            
            // Set headers
            request.setHeader('Accept', 'application/json');
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', 'Bearer ' + recAPIConfig.Auth_Token__c);
            
            // Prepare JSON body
            reqPayload payload = new reqPayload(input[0].msg2Send);
            String jsonBody = JSON.serialize(payload);
            System.debug('JSON: ' + jsonBody);
            request.setBody(jsonBody);
            
            // Increase timeout
            request.setTimeout(20000); // 20 seconds - timeout in milliseconds
            
            // Execute the HTTP request
            HttpResponse response;
            try {
                response = http.send(request);
                
                // Process the response
                if (response.getStatusCode() == 200) {
                    // Deserialize JSON response
                    jsonBody = response.getBody();
                    System.debug('jsonBody : '+jsonBody);
                    
                    // Deserialize the JSON string into a Map
                    Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(jsonBody);
                    
                    // Get the 'messages' list from the Map
                    List<Object> messages = (List<Object>) jsonMap.get('messages');
                    
                    // Loop through the 'messages' list and print each message
                    String sContent = '';
                    for (Object m : messages) {
                        Map<String, Object> mMap = (Map<String, Object>)m;
                        System.debug('message : ' + mMap);
                        
                        // Print the message text
                        sContent = (String) mMap.get('message');
                    }
                    msg.Response = sContent;
                } else {
                    System.debug('Error: ' + response.getStatusCode() + ' - ' + response.getBody());
                    msg.Response = response.getStatusCode() + ' - ' + response.getBody();
                }
            } catch (System.CalloutException e) {
                System.debug('HTTP Request failed: ' + e.getMessage());
                msg.Response = e.getMessage();
            }
        } else if (recAPIConfig.API_Type__c == 'MIAW API') {
            // Set endpoint and HTTP method
            request.setEndpoint(recAPIConfig.Org_Url__c + '/iamessage/api/v2/conversation/' + recAPIConfig.Session_Id__c + '/message');
            request.setMethod('POST');
            
            // Set headers
            request.setHeader('Content-Type', 'application/json');
            request.setHeader('Authorization', 'Bearer ' + recAPIConfig.Auth_Token__c);
            
            // Generate Random UUID for new Entry
            UUID randomUUID = UUID.randomUUID();
            
            // Prepare JSON body
            StaticContent myContent = new StaticContent('Text', input[0].msg2Send);
            MIAWMessage myMsg = new MIAWMessage('', randomUUID.toString(), 'StaticContentMessage', myContent);
            
            RequestPayload payload = new RequestPayload(myMsg, recAPIConfig.Developer_Name__c, false, new RoutingAttributes('','',''), 'en_US');
            
            String jsonBody = JSON.serialize(payload);
            request.setBody(jsonBody);
            
            // Execute the HTTP request
            HttpResponse response;
            try {
                response = http.send(request);
                
                // Process the response
                if (response.getStatusCode() == 202) {
                    msg.entryId = randomUUID.toString();
                } else if (response.getStatusCode() == 403) { // No active conversations found
                    msg.entryId = '403';
                } else {
                    System.debug('Error: ' + response.getStatusCode() + ' - ' + response.getBody());
                    msg.entryId = '403';
                }
            } catch (System.CalloutException e) {
                System.debug('HTTP Request failed: ' + e.getMessage());
                msg.entryId = '403';
            }
        }
        
        try {
            // Save last message and auth token into the API Configuration record
            recAPIConfig.lastResponse__c = msg.Response;
            recAPIConfig.Entry_Id__c = msg.entryId;
            String saveMsg = AgentAPIConfig.saveConfig(recAPIConfig);            
        } catch (System.CalloutException e) {
            System.debug('Save failed: ' + e.getMessage());
            msg.Response = e.getMessage();
        }

        msgResp.add(msg);
        return msgResp;
    }
}