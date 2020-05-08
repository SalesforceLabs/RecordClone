@IsTest
private class RecordCloneHandlerTest {
  @IsTest
  private static void testGetOriginalRecord() {
    Account acc = new Account(Name = 'TestAccount');
    Contact con = new Contact(LastName = 'TestContact');
    insert acc;
    insert con;

    sObjectSummary accSummary = new sObjectSummary(
      Account.sObjectType.getDescribe()
    );

    sObject withNullRecordId = RecordCloneHandler.getOriginalRecord(
      null,
      accSummary
    );
    System.assertEquals(withNullRecordId, null);
    sObject withInvalidRecordId = RecordCloneHandler.getOriginalRecord(
      con.Id,
      accSummary
    );
    System.assertEquals(withInvalidRecordId, null);
    sObject withNullSummary = RecordCloneHandler.getOriginalRecord(
      acc.Id,
      null
    );
    System.assertEquals(withNullSummary, null);
    sObject withCorrectRecordId = RecordCloneHandler.getOriginalRecord(
      acc.Id,
      accSummary
    );
    System.assertNotEquals(withCorrectRecordId, null);
  }

  @IsTest
  private static void testGetOriginalRecords() {
    List<Account> accs = new List<Account>();
    accs.add(new Account(Name = 'TestAccount1'));
    accs.add(new Account(Name = 'TestAccount2'));
    List<Contact> cons = new List<Contact>();
    cons.add(new Contact(LastName = 'TestContact1'));
    cons.add(new Contact(LastName = 'TestContact2'));
    insert accs;
    insert cons;

    List<Id> accIds = new List<Id>(new Map<Id, Account>(accs).keySet());
    List<Id> conIds = new List<Id>(new Map<Id, Contact>(cons).keySet());

    sObjectSummary accSummary = new sObjectSummary(
      Account.sObjectType.getDescribe()
    );

    List<sObject> withNullRecordIds = RecordCloneHandler.getOriginalRecords(
      null,
      accSummary
    );
    System.assertEquals(withNullRecordIds, null);
    List<sObject> withEmptyRecordIds = RecordCloneHandler.getOriginalRecords(
      new List<Id>(),
      accSummary
    );
    System.assertEquals(withEmptyRecordIds, null);
    List<sObject> withInvalidRecordIds = RecordCloneHandler.getOriginalRecords(
      conIds,
      accSummary
    );
    System.assertNotEquals(withInvalidRecordIds, null);
    System.assertEquals(withInvalidRecordIds.size(), 0);
    List<sObject> withNullSummary = RecordCloneHandler.getOriginalRecords(
      accIds,
      null
    );
    System.assertEquals(withNullSummary, null);
    List<sObject> withCorrectRecordId = RecordCloneHandler.getOriginalRecords(
      accIds,
      accSummary
    );
    System.assertNotEquals(withCorrectRecordId, null);
    System.assertEquals(withCorrectRecordId.size(), accIds.size());
  }

  @IsTest
  private static void testCloneRecord() {
    String newRecordName = 'New Record Name';

    Account acc = new Account(Name = 'TestAccount');
    insert acc;
    Contact con = new Contact(LastName = 'TestContact', AccountId = acc.Id);
    insert con;

    Opportunity opp = new Opportunity(
      Name = 'Test Opp',
      StageName = 'Test Stage Name',
      CloseDate = Date.today(),
      AccountId = acc.Id
    );
    insert opp;

    OpportunityContactRole ocr = new OpportunityContactRole(
      ContactId = con.Id,
      OpportunityId = opp.Id,
      IsPrimary = true,
      Role = 'TestRole'
    );
    insert ocr;

    sObjectSummary accSummary1 = new sObjectSummary(
      Account.sObjectType.getDescribe()
    );

    sObjectSummary oppSummary1 = sObjectSummary.getByRecordId(
      opp.Id,
      'OpportunityContactRoles',
      'StageName'
    );

    // no child, no excluded
    sObject cloned1 = RecordCloneHandler.cloneRecord(
      acc,
      accSummary1,
      newRecordName,
      RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
    );
    System.assertNotEquals(cloned1.Id, null);

    // with children and excluded fields
    sObjectSummary accSummary2 = sObjectSummary.getByRecordId(
      acc.Id,
      'Contacts',
      'excludedFieldNames'
    );
    sObject cloned2 = RecordCloneHandler.cloneRecord(
      acc,
      accSummary2,
      newRecordName,
      RecordCloneChildRecordNamePicklist.valueWithCloned
    );
    System.assertNotEquals(cloned2.Id, null);

    // not namable
    accSummary1.isNamable = false;
    sObject notNamable = RecordCloneHandler.cloneRecord(
      acc,
      accSummary1,
      null,
      RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
    );
    System.assertNotEquals(notNamable.Id, null);

    // with opp and auto created opp contact role
    sObject oppCloned = RecordCloneHandler.cloneRecord(
      opp,
      oppSummary1,
      newRecordName,
      RecordCloneChildRecordNamePicklist.valueOriginalName
    );
    System.assertNotEquals(oppCloned.Id, null);
  }

  @IsTest
  private static void testCloneRecords() {
    Account acc = new Account(Name = 'TestAccount');
    insert acc;
    Account acc2 = new Account(Name = 'TestAccount2');
    insert acc2;
    Contact con = new Contact(LastName = 'TestContact', AccountId = acc.Id);
    insert con;

    Opportunity opp = new Opportunity(
      Name = 'Test Opp',
      StageName = 'Test Stage Name',
      CloseDate = Date.today(),
      AccountId = acc.Id
    );
    insert opp;

    OpportunityContactRole ocr = new OpportunityContactRole(
      ContactId = con.Id,
      OpportunityId = opp.Id,
      IsPrimary = true,
      Role = 'TestRole'
    );
    insert ocr;

    sObjectSummary accSummary1 = new sObjectSummary(
      Account.sObjectType.getDescribe()
    );

    List<sObject> originals = new List<SObject>();
    originals.add(acc);
    originals.add(acc2);

    List<sObject> clones = RecordCloneHandler.cloneRecords(originals, accSummary1);
    System.assertNotEquals(clones, null);
    System.assertEquals(clones.size(), 2);
  }
}
