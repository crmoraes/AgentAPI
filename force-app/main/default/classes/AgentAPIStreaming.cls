public with sharing class AgentAPIStreaming {
    public class reqPayload {
        public List<String> variables;
        public Message message;
        
        public reqPayload(String msg) {
            this.variables = new List<String>();
            this.message = new Message(msg);
        }
    }
    
    public class Message {
        public String text;
        public String type = 'Text';
        public String sequenceId = Datetime.now().format('yyyyMMddHHmmss');
        
        public Message(String msg) {
            this.text = msg;
        }
    }
    
    // Apex Class - Input from Flow
    public class inputFlow {
        @InvocableVariable(required=true)
        public String sessionId;
        @InvocableVariable(required=true)
        public String AuthToken;
        @InvocableVariable(required=true)
        public String msg2Send;
    }
    
    // Apex Class - Response to Flow
    public class outputFlow {
        @InvocableVariable
        public String Response;
    }
    
    // Method to send a new Message
    @InvocableMethod(label='Agent API Send Stream Message' description='Send Stream Message to Agent')
    public static List<outputFlow> sendStreamMessage(List<inputFlow> input) {
        // Set output paramaters
        List<outputFlow> msgResp = new List<outputFlow>();
        outputFlow msg = new outputFlow();
        msg.Response = '';
        
        // if expired request a new token
        Http http = new Http();
        HttpRequest request = new HttpRequest();
        
        // Set the endpoint and method
        request.setEndpoint('https://api.salesforce.com/einstein/ai-agent/v1/sessions/' + input[0].sessionId + '/messages/stream');
        request.setMethod('POST');
        
        // Set headers
        request.setHeader('Accept', 'application/json');
        request.setHeader('Content-Type', 'application/json');
        request.setHeader('Authorization', 'Bearer ' + input[0].AuthToken);
        
        // Prepare JSON body
        reqPayload payload = new reqPayload(input[0].msg2Send);
        String jsonBody = JSON.serialize(payload);
        System.debug('JSON: ' + jsonBody);
        request.setBody(jsonBody);
        
        // Execute the HTTP request
        HttpResponse response;         
        try {
            response = http.send(request);
            
            // Process the response
            if (response.getStatusCode() == 200) {
                msg.Response = 'Message Sent Successfully';
            } else {
                System.debug('Error: ' + response.getStatusCode() + ' - ' + response.getBody());
                msg.Response = response.getStatusCode() + ' - ' + response.getBody();
            }
        } catch (System.CalloutException e) {
            System.debug('HTTP Request failed: ' + e.getMessage());
            msg.Response = e.getMessage();
        }
        msgResp.add(msg);
        return msgResp;
    }
}