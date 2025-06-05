public with sharing class AgentAPIWait {
    public class inputFlow {
        @InvocableVariable(required=true)
        public String waitSeconds;
    }

	@InvocableMethod(label='Agent API Wait' description='Wait XX seconds')
    public static void wait(List<inputFlow> input) {
        Integer waitTime = Integer.valueof(input[0].waitSeconds);
        
        Long startTimerTime = DateTime.now().getTime();
        Long finishTimerTime = DateTime.now().getTime();
        
        while ((finishTimerTime - startTimerTime ) < (waitTime * 1000)) {
            //delay for X seconds
            finishTimerTime = DateTime.now().getTime();
        } 
    }
}