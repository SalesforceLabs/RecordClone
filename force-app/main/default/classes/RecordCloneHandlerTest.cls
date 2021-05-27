/*
 * Copyright (c) 2020, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */
@IsTest
private class RecordCloneHandlerTest {
  @IsTest
  private static void testGetOriginalRecord() {
    Account acc = new Account(Name = 'TestAccount');
    Contact con = new Contact(LastName = 'TestContact');
    insert acc;
    insert con;

    Account acc2 = new Account(Name = 'TestAccount2');
    insert acc2;
    List<Contact> cons = new List<Contact>();
    for (Integer i = 0; i < 200; i++) {
      cons.add(new Contact(LastName = 'TestContact' + i, AccountId = acc2.Id));
    }
    insert cons;
    List<Opportunity> opps = new List<Opportunity>();
    for (Integer i = 0; i < 100; i++) {
      opps.add(
        new Opportunity(
          Name = 'TestOpp' + i,
          StageName = 'New',
          CloseDate = Date.today(),
          AccountId = acc2.Id
        )
      );
    }
    insert opps;

    List<Case> cases = new List<Case>();
    for (Integer i = 0; i < 50; i++) {
      cases.add(new Case(Subject = 'TestOpp' + i, AccountId = acc2.Id));
    }
    insert cases;

    sObjectSummary accSummary = new sObjectSummary(
      Account.sObjectType.getDescribe()
    );

    CloneQueryResult withNullRecordId = RecordCloneHandler.getOriginalRecord(
      null,
      accSummary
    );
    System.assertEquals(withNullRecordId, null);
    CloneQueryResult withInvalidRecordId = RecordCloneHandler.getOriginalRecord(
      con.Id,
      accSummary
    );
    System.assertEquals(withInvalidRecordId, null);
    CloneQueryResult withNullSummary = RecordCloneHandler.getOriginalRecord(
      acc.Id,
      null
    );
    System.assertEquals(withNullSummary, null);
    CloneQueryResult withCorrectRecordId = RecordCloneHandler.getOriginalRecord(
      acc.Id,
      accSummary
    );
    System.assertNotEquals(withCorrectRecordId, null);

    sObjectSummary accSummary2 = sObjectSummary.getByRecordId(
      acc2.Id,
      'Contacts,Opportunities,Cases',
      ''
    );
    CloneQueryResult acc2WithManyChildren = RecordCloneHandler.getOriginalRecord(
      acc2.Id,
      accSummary2
    );

    // exec clone
    sObject clonedAcc2WithManyChildren = RecordCloneHandler.cloneRecord(
      acc2WithManyChildren.parent,
      acc2WithManyChildren.childrens,
      accSummary2,
      'hello',
      RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
    );

    System.debug(clonedAcc2WithManyChildren);
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

    List<CloneQueryResult> withNullRecordIds = RecordCloneHandler.getOriginalRecords(
      null,
      accSummary
    );
    System.assertEquals(withNullRecordIds, null);
    List<CloneQueryResult> withEmptyRecordIds = RecordCloneHandler.getOriginalRecords(
      new List<Id>(),
      accSummary
    );
    System.assertEquals(withEmptyRecordIds, null);
    List<CloneQueryResult> withInvalidRecordIds = RecordCloneHandler.getOriginalRecords(
      conIds,
      accSummary
    );
    System.assertNotEquals(withInvalidRecordIds, null);
    System.assertEquals(withInvalidRecordIds.size(), 0);
    List<CloneQueryResult> withNullSummary = RecordCloneHandler.getOriginalRecords(
      accIds,
      null
    );
    System.assertEquals(withNullSummary, null);
    List<CloneQueryResult> withCorrectRecordId = RecordCloneHandler.getOriginalRecords(
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

    Map<String, List<sObject>> accChildren = new Map<String, List<sObject>>{
      'Contacts' => new List<sObject>{ con }
    };
    Map<String, List<sObject>> oppChildren = new Map<String, List<sObject>>{
      'OpportunityContactRoles' => new List<sObject>{ ocr }
    };

    // no child, no excluded
    sObject cloned1 = RecordCloneHandler.cloneRecord(
      acc,
      accChildren,
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
      accChildren,
      accSummary2,
      newRecordName,
      RecordCloneChildRecordNamePicklist.valueWithCloned
    );
    System.assertNotEquals(cloned2.Id, null);

    // not namable
    accSummary1.isNamable = false;
    sObject notNamable = RecordCloneHandler.cloneRecord(
      acc,
      accChildren,
      accSummary1,
      null,
      RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
    );
    System.assertNotEquals(notNamable.Id, null);

    // with opp and auto created opp contact role
    sObject oppCloned = RecordCloneHandler.cloneRecord(
      opp,
      oppChildren,
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

    List<Id> originals = new List<Id>();
    originals.add(acc.Id);
    originals.add(acc2.Id);

    // get original records
    List<CloneQueryResult> cloneQueryResults = RecordCloneHandler.getOriginalRecords(
      originals,
      accSummary1
    );

    // exec clone
    List<sObject> cloneds = RecordCloneHandler.cloneRecords(
      cloneQueryResults,
      accSummary1
    );

    System.assertNotEquals(cloneds, null);
    System.assertEquals(cloneds.size(), 2);
  }
}
