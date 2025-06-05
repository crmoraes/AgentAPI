public with sharing  class AgentAPIToken {
    // Apex Class - Input
    public class inputVar {
        @InvocableVariable(label='API Configuration Name' required=true)
        public String APIConfigName;
    }
    
    // Apex Class - Response
    public class outputVar {
        @InvocableVariable
        public String AuthToken;
        @InvocableVariable
        public String Response;
        @InvocableVariable
        public Boolean isAuthorized;
    }
    
    // MIAW API Request Payload
    public class reqPayload {
        public String orgId;
        public String esDeveloperName;
        public String capabilitiesVersion;
        public String platform;
        
        public reqPayload(String myorgId, String myDevName) {
            this.orgId = myorgId;
            this.esDeveloperName = myDevName;
            this.capabilitiesVersion = '1';
            this.platform = 'Web';
        }
    }
    
    // Method to check if access Token is expired
    
    @InvocableMethod(label='Agent API Create Token' description='Create Token for API Access')
    public static List<outputVar> createToken(List<inputVar> input) {
        // Set output paramaters
        List<outputVar> msgResp = new List<outputVar>();
        outputVar msg = new outputVar();
        msg.AuthToken = '';
        msg.Response = '';
        msg.isAuthorized = false;
        
        // Retrieve Agent API configuration parameters
        Agent_API_Config__c recAPIConfig = AgentAPIConfig.getConfig(input[0].APIConfigName);
        
        // if expired request a new token
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        if (recAPIConfig.API_Type__c == 'Agent API') {
            // Set the endpoint and method
            request.setEndpoint(recAPIConfig.Org_Url__c + '/services/oauth2/token');
            request.setMethod('POST');
            
            // Set headers
            request.setHeader('Content-Type', 'application/x-www-form-urlencoded');
            
            // Set Body
            String payLoad = 'grant_type=client_credentials' +
                '&client_id=' + EncodingUtil.urlEncode(recAPIConfig.ConsumerKey__c,'UTF-8') +
                '&client_secret=' + EncodingUtil.urlEncode(recAPIConfig.ConsumerSecret__c, 'UTF-8');
            request.setBody(payLoad);
        } else if (recAPIConfig.API_Type__c == 'MIAW API') {
            // Set the endpoint and method
            request.setEndpoint(recAPIConfig.Org_Url__c + '/iamessage/api/v2/authorization/unauthenticated/access-token');
            request.setMethod('POST');
            
            // Set headers
            request.setHeader('Content-Type', 'application/json');
            
            // Prepare JSON body
            reqPayload payload = new reqPayload(recAPIConfig.Org_Id__c, recAPIConfig.Developer_Name__c);
            String jsonBody = JSON.serialize(payload);
            System.debug('JSON: ' + jsonBody);
            
            request.setBody(jsonBody);
        }
        
        // Execute the HTTP request
        HttpResponse response;
        try {
            response = http.send(request);
            
            // Process the response
            if (response.getStatusCode() == 200) {
                // Deserialize JSON response
                Map<String, Object> jsonMap = (Map<String, Object>)JSON.deserializeUntyped(response.getBody());
                
                if (recAPIConfig.API_Type__c == 'Agent API') {
                    // Get the token from the response
                    msg.AuthToken = (String)jsonMap.get('access_token');
                } else if (recAPIConfig.API_Type__c == 'MIAW API') {
                    // Get the token from the response
                    msg.AuthToken = (String)jsonMap.get('accessToken');
                }
                
                msg.Response = 'Authorized';
            } else {
                // Handle errors
                System.debug('Error: ' + response.getStatusCode() + ' - ' + response.getBody());
                msg.Response = response.getBody();
            }
        } catch (System.CalloutException e) {
            System.debug('HTTP Request failed: ' + e.getMessage());
            msg.Response = e.getMessage();
        }
        
        try {
            // Save last message and auth token into the API Configuration record
            recAPIConfig.lastResponse__c = msg.Response;
            recAPIConfig.Auth_Token__c = msg.AuthToken;
            String saveMsg = AgentAPIConfig.saveConfig(recAPIConfig);
            
            if (msg.Response == 'Authorized') msg.isAuthorized = true;
        } catch (System.CalloutException e) {
            System.debug('Save failed: ' + e.getMessage());
            msg.Response = e.getMessage();
        }
        
        msgResp.add(msg);
        return msgResp;
    }
}