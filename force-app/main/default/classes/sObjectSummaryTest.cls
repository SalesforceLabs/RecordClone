@IsTest
private class sObjectSummaryTest {
  @IsTest
  private static void simpleConstructor() {
    sObjectSummary accObj = new sObjectSummary(
      Account.sObjectType.getDescribe()
    );
    System.assertEquals(accObj.apiName, 'Account');

    sObjectSummary caseObj = new sObjectSummary(Case.sObjectType.getDescribe());
    System.assertEquals(caseObj.apiName, 'Case');

    sObjectSummary oliObj = new sObjectSummary(
      OpportunityLineItem.sObjectType.getDescribe()
    );
    System.assertEquals(oliObj.apiName, 'OpportunityLineItem');
  }

  @IsTest
  private static void withExcludedField() {
    String accExcluded = 'Phone, OperatingHoursId';
    sObjectSummary accObj = new sObjectSummary(
      Account.sObjectType.getDescribe(),
      accExcluded
    );
    for (sObjectSummary.sFieldSummary fs : accObj.fields) {
      if (stringToList(accExcluded).contains(fs.apiName)) {
        System.assertEquals(fs.isClonable, false);
      }
    }

    String caseExcluded = 'BusinessHoursId, Description';
    sObjectSummary caseObj = new sObjectSummary(
      Case.sObjectType.getDescribe(),
      caseExcluded
    );
    for (sObjectSummary.sFieldSummary fs : caseObj.fields) {
      if (stringToList(caseExcluded).contains(fs.apiName)) {
        System.assertEquals(fs.isClonable, false);
      }
    }

    String oliExcluded = 'Discount, Description';
    sObjectSummary oliObj = new sObjectSummary(
      OpportunityLineItem.sObjectType.getDescribe(),
      oliExcluded
    );
    for (sObjectSummary.sFieldSummary fs : oliObj.fields) {
      if (stringToList(oliExcluded).contains(fs.apiName)) {
        System.assertEquals(fs.isClonable, false);
      }
    }
  }

  @IsTest
  private static void notSupportedObj() {
    sObjectSummary taskObj = new sObjectSummary(Task.sObjectType.getDescribe());
    System.assertEquals(taskObj.isClonable, false);

    sObjectSummary eventObj = new sObjectSummary(
      Event.sObjectType.getDescribe()
    );
    System.assertEquals(eventObj.isClonable, false);

    sObjectSummary attachmentObj = new sObjectSummary(
      Attachment.sObjectType.getDescribe()
    );
    System.assertEquals(attachmentObj.isClonable, false);

    sObjectSummary docObj = new sObjectSummary(
      Document.sObjectType.getDescribe()
    );
    System.assertEquals(docObj.isClonable, false);

    sObjectSummary cdlObj = new sObjectSummary(
      ContentDocumentLink.sObjectType.getDescribe()
    );
    System.assertEquals(cdlObj.isClonable, false);

    sObjectSummary cdObj = new sObjectSummary(
      ContentDocument.sObjectType.getDescribe()
    );
    System.assertEquals(cdObj.isClonable, false);
  }

  @IsTest
  private static void exceptionalFields() {
    sObjectSummary caseObj = new sObjectSummary(Case.sObjectType.getDescribe());
    for (sObjectSummary.sFieldSummary fs : caseObj.fields) {
      if (fs.apiName == 'ClosedDate') {
        System.assertEquals(fs.isClonable, false);
      }
    }

    sObjectSummary oliObj = new sObjectSummary(
      OpportunityLineItem.sObjectType.getDescribe()
    );
    for (sObjectSummary.sFieldSummary fs : oliObj.fields) {
      if (fs.apiName == 'TotalPrice') {
        System.assertEquals(fs.isClonable, false);
      }
    }
  }

  @IsTest
  private static void testFilterClonableFields() {
    String accExcluded = 'Phone, Email';
    sObjectSummary accObj = new sObjectSummary(
      Account.sObjectType.getDescribe(),
      accExcluded
    );

    List<String> accClonableFields = accObj.filterClonableFields();
    for (String accExcludedField : stringToList(accExcluded)) {
      System.assertEquals(accClonableFields.contains(accExcludedField), false);
    }
  }

  @IsTest
  private static void testGetByRecordId() {
    OperatingHours oh = new OperatingHours(Name = 'test');
    insert oh;

    Account acc = new Account(
      Name = 'Hello',
      Phone = '0123456789',
      OperatingHoursId = oh.Id
    );
    insert acc;

    Contact con = new Contact(LastName = 'Test', AccountId = acc.Id);
    insert con;

    Opportunity opp1 = new Opportunity(
      Name = 'Test Opp 1',
      AccountId = acc.Id,
      StageName = 'First Step',
      CloseDate = Date.today()
    );
    insert opp1;

    Opportunity opp2 = new Opportunity(
      Name = 'Test Opp 2',
      AccountId = acc.Id,
      StageName = 'First Step',
      CloseDate = Date.today()
    );
    insert opp2;

    String fieldsExcluded = 'Stage, Phone, Email ';
    String childrenIncluded = 'Contacts, Opportunities';
    String childrenIncludedApiNames = 'Contact, Opportunity';
    sObjectSummary accById = sObjectSummary.getByRecordId(acc.Id);
    sObjectSummary accWithChildren = sObjectSummary.getByRecordId(
      acc.Id,
      childrenIncluded,
      fieldsExcluded
    );

    System.assertEquals(accById.apiName, 'Account');
    System.assertEquals(accById.isClonable, true);
    System.assertEquals(accById.isNamable, true);
    System.assertEquals(accById.children, null);
    System.assertNotEquals(accById.fields.size(), 0);

    System.assertEquals(accWithChildren.apiName, 'Account');
    System.assertEquals(accWithChildren.isClonable, true);
    System.assertEquals(accWithChildren.isNamable, true);
    System.assertEquals(accWithChildren.children.size(), 2);
    System.assertNotEquals(accWithChildren.fields.size(), 0);

    List<String> clonableFields = accWithChildren.filterClonableFields();
    for (String excludedField : stringToList(fieldsExcluded)) {
      System.assertEquals(clonableFields.contains(excludedField), false);
    }

    for (String child : stringToList(childrenIncluded)) {
      sObjectSummary childSummary = accWithChildren.children.get(child);
      System.assertEquals(
        stringToList(childrenIncludedApiNames).contains(childSummary.apiName),
        true
      );
    }
  }

  private static List<String> stringToList(String commaSeparatedString) {
    List<String> splitted = commaSeparatedString.split(',');
    for (Integer i = 0; i < splitted.size(); i++) {
      splitted[i] = splitted[i].trim();
    }
    return splitted;
  }

  private static String listToString(List<String> stringList) {
    return String.join(stringList, ',');
  }
}
