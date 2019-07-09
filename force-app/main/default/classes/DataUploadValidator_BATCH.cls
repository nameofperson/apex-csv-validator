global class DataUploadValidator_BATCH implements Database.Batchable<String>, System.Iterable<String>, Iterator<String>, Database.Stateful{
    global String targetObjectName;
    global Map<String, MappingDefinition> targetObjectMapping;
    global Schema.SObjectType targetType;
    global List<String> targetRows;
    global String targetOperation;
    global List<List<String>> results;
    global Integer index;

    /**************************************/
    //  Constructor for reading static resource
    /*************************************/

    public DataUploadValidator_BATCH(String targetResource, String objectName, List<String> testData, String operationType) {
        Blob resourceData;
        String[] dataRows;
        String[] header;
        index=0;

        //initialize vars
        targetObjectMapping = new Map<String, MappingDefinition>();
        results = new List<List<String>>();
        targetOperation = operationType;

        try{
            if(!Test.isRunningTest()){
                //query static resource to get csv
                resourceData = [SELECT Body FROM StaticResource WHERE Name = :targetResource LIMIT 1][0].Body;

                //if exists, convert to single string then split
                String contentFile = resourceData.toString();
                dataRows = contentFile.replaceAll('\\r','').split('\n');
                header = dataRows.remove(0).split(',');
            }
            else{
                //if inside a test, build list from provided data
                header = testData.remove(0).split(',');
                dataRows = testData;                

                System.debug('Current Header:'+header);
                System.debug('Current Rows:'+testData);
            }
        }
        catch(Exception ex){

        }
        
        //set object name
        targetObjectName = objectName;
        
        //set global var to define scope
        targetRows = dataRows;

        try{
            //get target object information and mapping
            targetType = Schema.getGlobalDescribe().get(targetObjectName);

            //get field mapping
            Map<String,Schema.SObjectField> targetFields = targetType.getDescribe().fields.getMap();

            //build map from available field names in header
            for(String headerField : header){
                if(targetFields.keySet().contains(headerField.toLowerCase())){
                    System.debug('Adding '+headerField+' to mapping');
                    //System.debug('Field type:'+targetFields.get(headerField.toLowerCase()).getDescribe().getType());
                    System.debug('Current Position of column: '+header.indexOf(headerField));  

                    MappingDefinition currentMapping = new MappingDefinition();                  
                    currentMapping.fieldPosition = header.indexOf(headerField);
                    currentMapping.fieldType = targetFields.get(headerField.toLowerCase()).getDescribe().getType();
                    targetObjectMapping.put(headerField, currentMapping);
                }
            }
            System.debug('Current Mapping: '+targetObjectMapping);
        }
        catch(Exception ex){
            System.debug('Exception Caught:'+ex.getMessage());
        }
        
    }

    /********************************/
    //  Batch Interface Methods
    /********************************/

    global Iterable<String> start(Database.BatchableContext context) {
        return this;
    }

    global void execute(Database.BatchableContext context, List<String> scope) {
        List<SObject> targetRecords = new List<SObject>();
        List<String> fieldValues;
        Integer failed = 0;
        Integer success = 0;
        Integer skipped = 0;

        System.debug('Current Mapping: '+this.targetObjectMapping);

        for(String item : scope){
            //create new object from type token
            SObject currentRecord = targetType.newSObject();

            //split record string values
            //but anticipate composite fields 
            //code copied from http://parsecsvfilesfdc.blogspot.com/
            try{
                String compositeField;
                Boolean makeCompositeField = false;

                //container for the split line as-is
                List<String> rawFields = item.split(','); 

                //check for blank line
                if (item.replaceAll(',','').trim().length() == 0) continue;
                
                //list for clean values 
                fieldValues = new List<String>();
                
                for(String field : rawFields) {
                    if (field.startsWith('"') && field.endsWith('"')) {
                        fieldValues.add(field.replaceAll('DBLQT','"'));
                    } else if (field.startsWith('"')) {
                        makeCompositeField = true;
                        compositeField = field;
                    } else if (field.endsWith('"')) {
                        compositeField += ',' + field;
                        fieldValues.add(compositeField.replaceAll('DBLQT','"'));
                        makeCompositeField = false;
                    } else if (makeCompositeField) {
                        compositeField +=  ',' + field;
                    } else {
                        fieldValues.add(field.replaceAll('DBLQT','"'));
                    }
                }
            }
            catch(Exception ex){
                System.debug('Malformed record or parsing problem, skipping...');
                continue;
            }

            //set all included properties by getting index from map
            for(String fieldName : targetObjectMapping.keySet()){
                //System.debug('Current values array size:'+fieldValues.size());
                //System.debug('Current value position:'+targetObjectMapping.get(fieldName));

                //check here if position index outside bounds
                MappingDefinition currentMapping = targetObjectMapping.get(fieldName);
                if(currentMapping.fieldPosition < fieldValues.size() && currentMapping.fieldPosition!= -1){
                    try{
                        switch on currentMapping.fieldType{
                            when BOOLEAN{
                                Boolean value = Boolean.valueOf(fieldValues[currentMapping.fieldPosition]);
                                currentRecord.put(fieldName,value);
                            }
                            when DOUBLE, CURRENCY, PERCENT{
                                Decimal value = Decimal.valueOf(fieldValues[currentMapping.fieldPosition]);
                                currentRecord.put(fieldName,value);
                            }
                            when DATE {
                                Date value = Date.parse(fieldValues[currentMapping.fieldPosition]);
                                currentRecord.put(fieldName,value);
                            }
                            when DATETIME {
                                DateTime value = DateTime.parse(fieldValues[currentMapping.fieldPosition]);
                                currentRecord.put(fieldName,value);
                            }
                            when else{
                                currentRecord.put(fieldName,fieldValues[currentMapping.fieldPosition]);
                            }
                        }                        
                    }
                    catch(Exception ex){
                        System.debug('Exception Caught:'+ex.getMessage());
                    }
                    
                }
                else{
                    System.debug(fieldName + ' value is blank or cannot be found, skipping...');
                }                    
            }

            //add to collection
            targetRecords.add(currentRecord);            
        }

        //set savepoint to rollback changes
        Savepoint sp = Database.setSavepoint();

        try {
            //generate list for current batch results
            List<String> currentResults = new List<String>();

            //make database operation and get results
            switch on targetOperation {
                when 'insert', 'update' {
                    Database.SaveResult[] saveResults;
                    if(targetOperation == 'insert') {
                        saveResults = Database.insert(targetRecords, false);
                    }
                    else {
                        saveResults = Database.update(targetRecords, false);   
                    }

                    //Iterate through each returned result
                    for (Database.SaveResult sr : saveResults) {
                        if (sr.isSuccess()) {
                            //System.debug('Successfully inserted record');
                            currentResults.add('Success');
                            success++;
                        }
                        else {
                            // Operation failed, so get all errors and concatenate               
                            //System.debug('Errors while inserting record');
                            String errorString = '';
                            for(Database.Error err : sr.getErrors()) {                                            
                                errorString = errorString + err.getMessage() + '|';
                            }
                            currentResults.add('Failed: '+errorString);
                            failed++;
                        }
                    }
                }
                when 'delete' {
                    Database.DeleteResult[] deleteResults = Database.delete(targetRecords, false);
                    //Iterate through each returned result
                    for (Database.DeleteResult dr : deleteResults) {
                        if (dr.isSuccess()) {
                            //System.debug('Successfully inserted record');
                            currentResults.add('Success');
                            success++;
                        }
                        else {
                            // Operation failed, so get all errors and concatenate               
                            //System.debug('Errors while inserting record');
                            String errorString = '';
                            for(Database.Error err : dr.getErrors()) {                                            
                                errorString = errorString + err.getMessage() + '|';
                            }
                            currentResults.add('Failed: '+errorString);
                            failed++;
                        }
                    }
                }
                when 'upsert'{
                    Database.UpsertResult[] upsertResults = Database.upsert(targetRecords, false);
                    //Iterate through each returned result
                    for (Database.UpsertResult upr : upsertResults) {
                        if (upr.isSuccess()) {
                            //System.debug('Successfully inserted record');
                            currentResults.add('Success');
                            success++;
                        }
                        else {
                            // Operation failed, so get all errors and concatenate               
                            //System.debug('Errors while inserting record');
                            String errorString = '';
                            for(Database.Error err : upr.getErrors()) {                                            
                                errorString = errorString + err.getMessage() + '|';
                            }
                            currentResults.add('Failed: '+errorString);
                            failed++;
                        }
                    }
                }
                when else{
                    System.debug('No operation specified');
                }
            }

            results.add(currentResults);

            skipped = scope.size() - (success + failed);
            System.debug('Current Batch Result: '+scope.size()+ ' rows processed, '+success+ ' rows inserted, '+failed+' rows failed, '+skipped+ ' rows skipped');
        }
        catch(Exception ex){
            System.debug('Exception Caught:'+ex.getMessage());
            System.debug('Information:'+ex.getCause());
        }

        //operation finished, rolling back
        Database.rollback(sp);
    }

    global void finish(Database.BatchableContext context) {
        //collate logs from separate lists
        Integer counter = 1;
        Integer success = 0;

        System.debug('Current results: '+results.size());

        if(results.size() > 1){            
            for(List<String> batchResults : results){
                for(String itemResult: batchResults){
                    System.debug('Record '+String.valueOf(counter)+': '+itemResult);
                    if(itemResult.contains('Success')){
                        success++;
                    }
                    counter++;
                }
            }
        }
        else{
            for(String itemResult: results[0]){
                System.debug('Record '+String.valueOf(counter)+': '+itemResult);
                if(itemResult.contains('Success')){
                    success++;
                }
                counter++;
            }
        }
    }

    /********************************/
    //  String Iterable Methods
    /********************************/

    global Iterator<String> iterator()
    {
        return this;
    }
    global Boolean hasNext()
    {
        return index < targetRows.size();
    }
    global String next()
    {
        return targetRows[index++];
    }

    private class MappingDefinition{
        public String fieldName;
        public Integer fieldPosition;
        public Schema.DisplayType fieldType;
    }
}