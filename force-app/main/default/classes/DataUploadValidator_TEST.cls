@IsTest(seeAllData=false)
public with sharing class DataUploadValidator_TEST {
    
    private List<String> createCSV(String objName, String selectedFields) {
        List<String> csvResult = new List<String>();
        String header = '';

        //get object tokens for test objects
        SObjectType currentType = Schema.getGlobalDescribe().get(objName);        

        //get fields from describe info
        Map<String,Schema.SObjectField> currentFields = currentType.getDescribe().fields.getMap();
        
        for(Schema.SObjectField field: currentFields.values()){
            String fieldName = field.getDescribe().getName();

            if(String.isNotBlank(selectedFields)){
                if(selectedFields.contains(fieldName)){
                    header = header + fieldName +',';
                }
            }
            else{
                header = header + fieldName +',';
            }            
        }

        //add header row
        csvResult.add(header.removeEnd(','));

        //generate rows
        for(Integer x=0;x<10;x++){
            String currentRow = '';

        }

        return csvResult;
    }

    @IsTest
    public static void testObject(){
        //List<String> testData = createCSV('Account','Name,Description');

        List<String> csvResult = new List<String>();
        csvResult.add('Name,Description');
        for(integer x=0;x<50;x++){
            csvResult.add('Test Account'+String.valueOf(x)+',A Description');
        }
        

        Test.startTest();
        DataUploadValidator_BATCH newBatch1 = new DataUploadValidator_BATCH('', 'Account', csvResult,'insert');
        Database.executeBatch(newBatch1);
        Test.stopTest();
    }
}
