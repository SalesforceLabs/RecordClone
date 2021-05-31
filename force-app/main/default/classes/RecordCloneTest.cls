/*
 * Copyright (c) 2020, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */
@isTest
private class RecordCloneTest {
  @IsTest
  private static void picklistTest() {
    RecordCloneChildRecordNamePicklist crnPick = new RecordCloneChildRecordNamePicklist();
    VisualEditor.DataRow row = crnPick.getDefaultValue();
    VisualEditor.DynamicPickListRows rows = crnPick.getValues();

    System.assertEquals(
      row.getLabel(),
      RecordCloneChildRecordNamePicklist.labelOriginalName
    );
    System.assertEquals(
      row.getValue(),
      RecordCloneChildRecordNamePicklist.valueOriginalName
    );
    System.assertEquals(
      rows.size(),
      RecordCloneChildRecordNamePicklist.values.size()
    );
  }

  @IsTest
  private static void testGetSobjectSummary() {
    // insert a record
    Case c = new Case(Subject = 'Test Case');
    insert c;

    // Id recordId, String childRelationshipNames, String excludedFieldNames
    // without relationship, without excludedFields
    sObjectSummary noNoSummary1 = RecordCloneController.getSObjectSummary(
      c.Id,
      '',
      ''
    );
    System.assertNotEquals(noNoSummary1, null);
    System.assertEquals(noNoSummary1.isClonable, true);
    System.assertEquals(noNoSummary1.children, null);
    System.assertNotEquals(noNoSummary1.fields, null);
    System.assertNotEquals(noNoSummary1.fields.size(), 0);

    sObjectSummary noNoSummary2 = RecordCloneController.getSObjectSummary(
      c.Id,
      null,
      null
    );
    System.assertNotEquals(noNoSummary1, null);
    System.assertEquals(noNoSummary1.isClonable, true);
    System.assertEquals(noNoSummary1.children, null);
    System.assertNotEquals(noNoSummary1.fields, null);
    System.assertNotEquals(noNoSummary1.fields.size(), 0);

    // with relationship, without excludedFields
    sObjectSummary yesNoSummary1 = RecordCloneController.getSObjectSummary(
      c.Id,
      'CaseSolutions',
      ''
    );
    System.assertNotEquals(yesNoSummary1, null);
    System.assertEquals(yesNoSummary1.isClonable, true);
    System.assertNotEquals(yesNoSummary1.children, null);
    System.assertEquals(yesNoSummary1.children.size(), 1);
    System.assertNotEquals(yesNoSummary1.fields, null);
    System.assertNotEquals(yesNoSummary1.fields.size(), 0);

    sObjectSummary yesNoSummary2 = RecordCloneController.getSObjectSummary(
      c.Id,
      'CaseContactRoles, Cases, OpenActivities',
      null
    );
    System.assertNotEquals(yesNoSummary2, null);
    System.assertEquals(yesNoSummary2.isClonable, true);
    System.assertNotEquals(yesNoSummary2.children, null);
    System.assertEquals(yesNoSummary2.children.size(), 3);
    System.assertNotEquals(yesNoSummary2.fields, null);
    System.assertNotEquals(yesNoSummary2.fields.size(), 0);

    for (String childApiName : yesNoSummary2.children.keySet()) {
      sObjectSummary child = yesNoSummary2.children.get(childApiName);
      if (child.apiName == 'OpenActivity') {
        System.assertEquals(child.isClonable, false);
      } else {
        System.assertEquals(child.isClonable, true);
      }
    }

    // without relationship, with excludedFields
    sObjectSummary noYesSummary1 = RecordCloneController.getSObjectSummary(
      c.Id,
      '',
      'AccountId'
    );
    System.assertNotEquals(noYesSummary1, null);
    System.assertEquals(noYesSummary1.isClonable, true);
    System.assertEquals(noYesSummary1.children, null);
    System.assertNotEquals(noYesSummary1.fields, null);
    System.assertNotEquals(noYesSummary1.fields.size(), 0);
    for (sObjectSummary.sFieldSummary field : noYesSummary1.fields) {
      if (field.apiName == 'AccountId') {
        System.assertEquals(field.isClonable, false);
      }
    }

    sObjectSummary noYesSummary2 = RecordCloneController.getSObjectSummary(
      c.Id,
      null,
      'AccountId, SourceId, SuppliedCompany, NotExistingField'
    );
    System.assertNotEquals(noYesSummary2, null);
    System.assertEquals(noYesSummary2.isClonable, true);
    System.assertEquals(noYesSummary2.children, null);
    System.assertNotEquals(noYesSummary2.fields, null);
    System.assertNotEquals(noYesSummary2.fields.size(), 0);
    for (sObjectSummary.sFieldSummary field : noYesSummary2.fields) {
      if (
        field.apiName == 'AccountId' ||
        field.apiName == 'SourceId' ||
        field.apiName == 'SuppliedCompany'
      ) {
        System.assertEquals(field.isClonable, false);
      }
    }

    // with relationship, with excludedFields
    sObjectSummary yesYesSummary1 = RecordCloneController.getSObjectSummary(
      c.Id,
      'CaseContactRoles, Cases, OpenActivities     , , , NotExistingRelationship',
      'AccountId, SourceId, SuppliedCompany, , , , NotExistingField'
    );
    System.assertNotEquals(yesYesSummary1, null);
    System.assertEquals(yesYesSummary1.isClonable, true);
    System.assertNotEquals(yesYesSummary1.children, null);
    System.assertEquals(yesYesSummary1.children.size(), 3);
    System.assertNotEquals(yesYesSummary1.fields, null);
    System.assertNotEquals(yesYesSummary1.fields.size(), 0);

    for (String childApiName : yesYesSummary1.children.keySet()) {
      sObjectSummary child = yesYesSummary1.children.get(childApiName);
      if (child.apiName == 'OpenActivity') {
        System.assertEquals(child.isClonable, false);
      } else {
        System.assertEquals(child.isClonable, true);
      }
    }

    for (sObjectSummary.sFieldSummary field : yesYesSummary1.fields) {
      if (
        field.apiName == 'AccountId' ||
        field.apiName == 'SourceId' ||
        field.apiName == 'SuppliedCompany'
      ) {
        System.assertEquals(field.isClonable, false);
      }
    }
  }

  @IsTest
  private static void testNameFieldValue() {
    String correctName = 'Test Account';
    Account a = new Account(Name = correctName, BillingCountry = 'Japan');
    insert a;

    String correctUsage = RecordCloneController.getNameFieldValue(
      a.Id,
      'Account',
      'Name'
    );
    System.assertEquals(correctUsage, correctName);

    String wrongSObjName = RecordCloneController.getNameFieldValue(
      a.Id,
      'Contact',
      'Name'
    );
    System.assertEquals(wrongSObjName, null);

    String wrongFieldName = RecordCloneController.getNameFieldValue(
      a.Id,
      'Account',
      'NotExistingField'
    );
    System.assertEquals(wrongFieldName, null);

    String wrongFieldName2 = RecordCloneController.getNameFieldValue(
      a.Id,
      'Account',
      'BillingAddress'
    );
    System.assertEquals(wrongFieldName2, null);
  }

  @IsTest
  private static void testExecClone() {
    // insert a record

    Account a = new Account(
      Name = 'Test Account',
      NumberOfEmployees = 1000,
      Phone = '0123456789'
    );
    insert a;

    Case c = new Case(Subject = 'Test Case', AccountId = a.Id);
    insert c;
    Case c2 = new Case(Subject = 'Test Child Case', ParentId = c.Id);
    insert c2;
    Case c3 = new Case(Subject = 'Test Child Case', ParentId = c.Id);
    insert c3;

    Opportunity o = new Opportunity(
      Name = 'Test Opp',
      StageName = 'aaa',
      CloseDate = Date.today(),
      AccountId = a.Id
    );
    insert o;

    Contact con = new Contact(
      FirstName = 'hello',
      LastName = 'hoho',
      accountId = a.Id
    );
    insert con;

    OpportunityContactRole ocr = new OpportunityContactRole(
      ContactId = con.Id,
      OpportunityId = o.Id,
      IsPrimary = true,
      Role = 'TestRole'
    );

    insert ocr;

    CaseContactRole ccr = new CaseContactRole(
      CasesId = c.Id,
      ContactId = con.Id,
      Role = 'Business Contact'
    );
    insert ccr;

    Id pricebookId = Test.getStandardPricebookId();
    Product2 prod = new Product2(
      Name = 'Product X',
      ProductCode = 'Pro-X',
      isActive = true
    );
    insert prod;

    PricebookEntry pbEntry = new PricebookEntry(
      Pricebook2Id = pricebookId,
      Product2Id = prod.Id,
      UnitPrice = 100.00,
      IsActive = true
    );
    insert pbEntry;

    //create your opportunity line item.  This assumes you already have an opportunity created, called opp
    OpportunityLineItem oli = new OpportunityLineItem(
      OpportunityId = o.Id,
      Quantity = 5,
      PricebookEntryId = pbEntry.Id,
      TotalPrice = 5 * pbEntry.UnitPrice
    );
    insert oli;

    sObject invalidRecordIdCloned1 = RecordCloneController.execClone(
      null,
      '',
      '',
      '',
      RecordCloneChildRecordNamePicklist.valueOriginalName
    );
    System.assertEquals(invalidRecordIdCloned1, null);

    sObject invalidRecordIdCloned2 = RecordCloneController.execClone(
      '0062w00000testoppo',
      null,
      null,
      null,
      RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
    );
    System.assertEquals(invalidRecordIdCloned2, null);

    // without record name, relationship, nor excludedFields
    sObject noNoNoCloned1 = RecordCloneController.execClone(
      a.Id,
      '',
      '',
      '',
      RecordCloneChildRecordNamePicklist.valueOriginalName
    );
    System.assertEquals(noNoNoCloned1, null);

    sObject noNoNoCloned2 = RecordCloneController.execClone(
      a.Id,
      null,
      null,
      null,
      RecordCloneChildRecordNamePicklist.valueOriginalName
    );
    System.assertEquals(noNoNoCloned2, null);

    sObject noNoNoCloned3 = RecordCloneController.execClone(
      c.Id,
      '',
      null,
      null,
      RecordCloneChildRecordNamePicklist.valueWithCloned
    );
    System.assertNotEquals(noNoNoCloned3, null);
    System.assertNotEquals(noNoNoCloned3.Id, null);

    // with parent name
    sObject yesNoNoCloned1 = RecordCloneController.execClone(
      a.Id,
      'New Record Name',
      null,
      null,
      RecordCloneChildRecordNamePicklist.valueWithCloned
    );
    System.assertNotEquals(yesNoNoCloned1, null);
    System.assertNotEquals(yesNoNoCloned1.Id, null);

    // not namable
    sObject yesNoNoCloned2 = RecordCloneController.execClone(
      c.Id,
      'New Record Name',
      null,
      null,
      RecordCloneChildRecordNamePicklist.valueWithCloned
    );
    System.assertNotEquals(yesNoNoCloned2, null);
    System.assertNotEquals(yesNoNoCloned2.Id, null);
    System.debug(yesNoNoCloned2);

    // with relationship, without excludedFields
    sObject noYesNoCloned1 = RecordCloneController.execClone(
      c.Id,
      'Case is not namable',
      'CaseContactRoles, Cases, OpenActivities     , , , NotExistingRelationship, CaseArticles',
      '',
      RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
    );
    System.assertNotEquals(noYesNoCloned1, null);
    System.assertNotEquals(noYesNoCloned1.Id, null);
    System.assertNotEquals(
      noYesNoCloned1.getSObjects('CaseContactRoles'),
      null
    );
    System.assertNotEquals(
      noYesNoCloned1.getSObjects('CaseContactRoles').size(),
      0
    );
    System.assertNotEquals(noYesNoCloned1.getSObjects('Cases'), null);
    System.assertNotEquals(noYesNoCloned1.getSObjects('Cases').size(), 0);

    sObject yesYesNoCloned1 = RecordCloneController.execClone(
      a.Id,
      'New Record Name',
      'Contacts, Cases, NotExistingRelationship, , ,',
      null,
      RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
    );
    System.assertNotEquals(yesYesNoCloned1, null);
    System.assertNotEquals(yesYesNoCloned1.Id, null);
    System.assertNotEquals(yesYesNoCloned1.getSObjects('Cases'), null);
    System.assertNotEquals(yesYesNoCloned1.getSObjects('Cases').size(), 0);
    System.assertNotEquals(yesYesNoCloned1.getSObjects('Contacts'), null);
    System.assertNotEquals(yesYesNoCloned1.getSObjects('Contacts').size(), 0);

    sObject yesYesNoCloned2 = RecordCloneController.execClone(
      a.Id,
      'New Record Name',
      'Opportunities, Contacts',
      '',
      RecordCloneChildRecordNamePicklist.valueWithCloned
    );
    System.assertNotEquals(yesYesNoCloned2, null);
    System.assertNotEquals(yesYesNoCloned2.Id, null);
    System.assertNotEquals(yesYesNoCloned2.getSObjects('Opportunities'), null);
    System.assertNotEquals(
      yesYesNoCloned2.getSObjects('Opportunities').size(),
      0
    );
    System.assertNotEquals(yesYesNoCloned2.getSObjects('Contacts'), null);
    System.assertNotEquals(yesYesNoCloned2.getSObjects('Contacts').size(), 0);

    // without relationship, with excludedFields
    sObject noNoYesCloned1 = RecordCloneController.execClone(
      a.Id,
      'New Record Name',
      '',
      'NumberOfEmployees',
      RecordCloneChildRecordNamePicklist.valueOriginalName
    );
    System.assertNotEquals(noNoYesCloned1, null);
    System.assertNotEquals(noNoYesCloned1.Id, null);
    Account checkNoNoYesCloned1 = [
      SELECT NumberOfEmployees
      FROM Account
      WHERE Id = :noNoYesCloned1.Id
    ];
    System.assertEquals(checkNoNoYesCloned1.NumberOfEmployees, null);

    sObject yesNoYesCloned1 = RecordCloneController.execClone(
      a.Id,
      'New Record Name',
      null,
      'Phone, NotExistingField, NumberOfEmployees',
      RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
    );
    System.assertNotEquals(yesNoYesCloned1, null);
    System.assertNotEquals(yesNoYesCloned1.Id, null);
    Account checkYesNoYesCloned1 = [
      SELECT Phone, NumberOfEmployees
      FROM Account
      WHERE Id = :yesNoYesCloned1.Id
    ];
    System.assertEquals(checkYesNoYesCloned1.Phone, null);
    System.assertEquals(checkYesNoYesCloned1.NumberOfEmployees, null);

    // with relationship, with excludedFields
    sObject noYesYesCloned1 = RecordCloneController.execClone(
      c.Id,
      null,
      'CaseContactRoles, Cases, OpenActivities     , , , NotExistingRelationship, CaseArticles',
      'AccountId, ClosedDate',
      RecordCloneChildRecordNamePicklist.valueWithCloned
    );
    System.assertNotEquals(noYesYesCloned1, null);
    System.assertNotEquals(noYesYesCloned1.Id, null);
    Case checkNoYesYesCloned1 = [
      SELECT AccountId, ClosedDate
      FROM Case
      WHERE Id = :noYesYesCloned1.Id
    ];
    System.assertEquals(checkNoYesYesCloned1.AccountId, null);
    System.assertEquals(checkNoYesYesCloned1.ClosedDate, null);
    System.assertNotEquals(
      noYesYesCloned1.getSObjects('CaseContactRoles'),
      null
    );
    System.assertNotEquals(
      noYesYesCloned1.getSObjects('CaseContactRoles').size(),
      0
    );
    System.assertNotEquals(noYesYesCloned1.getSObjects('Cases'), null);
    System.assertNotEquals(noYesYesCloned1.getSObjects('Cases').size(), 0);

    sObject withNullChildRecordName = RecordCloneController.execClone(
      a.Id,
      'New Record Name',
      'CaseArticles, CaseContactRoles, Cases',
      'AccountId, SourceId, SuppliedCompany, CreatedDate, CreatedById, LastModifiedDate, LastModifiedById',
      null
    );
    System.assertNotEquals(withNullChildRecordName, null);
    System.assertNotEquals(withNullChildRecordName.Id, null);
    System.assertNotEquals(withNullChildRecordName.getSObjects('Cases'), null);
    System.assertNotEquals(
      withNullChildRecordName.getSObjects('Cases').size(),
      0
    );

    sObject oppExceptional = RecordCloneController.execClone(
      o.Id,
      'New Record Name',
      'OpportunityContactRoles, OpportunityLineItems',
      '',
      RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
    );
    System.assertNotEquals(oppExceptional, null);
    System.assertNotEquals(oppExceptional.Id, null);
    System.assertNotEquals(
      oppExceptional.getSObjects('OpportunityContactRoles'),
      null
    );
    System.assertNotEquals(
      oppExceptional.getSObjects('OpportunityContactRoles').size(),
      0
    );
    System.assertNotEquals(
      oppExceptional.getSObjects('OpportunityLineItems'),
      null
    );
    System.assertNotEquals(
      oppExceptional.getSObjects('OpportunityLineItems').size(),
      0
    );
  }

  @IsTest
  private static void testExecCloneMultiple() {
    // Multiple records

    // insert a record
    Case c = new Case(Subject = 'Test Case');
    insert c;
    Case c2 = new Case(Subject = 'Test Child Case', ParentId = c.Id);
    insert c2;
    Case c3 = new Case(Subject = 'Test Child Case', ParentId = c.Id);
    insert c3;

    Account a = new Account(Name = 'Test Account');
    insert a;

    Opportunity o = new Opportunity(
      Name = 'Test Opp',
      StageName = 'aaa',
      CloseDate = Date.today(),
      AccountId = a.Id
    );
    insert o;

    Contact con = new Contact(
      FirstName = 'hello',
      LastName = 'hoho',
      accountId = a.Id
    );
    insert con;

    OpportunityContactRole ocr = new OpportunityContactRole(
      ContactId = con.Id,
      OpportunityId = o.Id,
      IsPrimary = true,
      Role = 'TestRole'
    );
    insert ocr;

    // !!!CAUTION!!!
    // Custom Metadata Types cannot be inserted via Apex.
    // Here is a sample records which you have to add MANUALLY.
    RecordCloneSettings__mdt caseSettings = new RecordCloneSettings__mdt();
    caseSettings.DeveloperName = 'TestCaseClone';
    caseSettings.MasterLabel = 'TestCaseClone';
    caseSettings.Language = 'ja';
    caseSettings.Label = 'TestCaseClone';
    caseSettings.QualifiedApiName = 'TestCaseClone';
    caseSettings.ObjectName__c = 'Case';
    caseSettings.ChildRelationshipNames__c = 'CaseSolutions';
    caseSettings.ExcludedFieldNames__c = 'Priority';
    caseSettings.ChildRecordNameType__c = RecordCloneChildRecordNamePicklist.valueWithClonedAndDate;
    // insert caseSettings;

    RecordCloneSettings__mdt oppSettings = new RecordCloneSettings__mdt();
    oppSettings.DeveloperName = 'TestOppClone';
    oppSettings.MasterLabel = 'TestOppClone';
    oppSettings.Language = 'ja';
    oppSettings.Label = 'TestOppClone';
    oppSettings.QualifiedApiName = 'TestOppClone';
    oppSettings.ObjectName__c = 'Opportunity';
    oppSettings.ChildRelationshipNames__c = 'OpportunityLineItems,OpportunityContactRoles';
    oppSettings.ExcludedFieldNames__c = '';
    oppSettings.ChildRecordNameType__c = RecordCloneChildRecordNamePicklist.valueWithCloned;
    // insert oppSettings;

    List<Id> caseIds = new List<Id>();
    caseIds.add(c.Id);
    caseIds.add(c2.Id);
    caseIds.add(c3.Id);
    List<Id> oppIds = new List<Id>();
    oppIds.add(o.Id);
    List<List<Id>> forInvocable = new List<List<Id>>();
    forInvocable.add(caseIds);
    forInvocable.add(oppIds);

    List<List<Id>> clonedMultiple = RecordCloneController.clone(forInvocable);

    System.assertNotEquals(clonedMultiple, null);
    System.assertNotEquals(clonedMultiple.size(), 0);
    System.assertNotEquals(clonedMultiple[0], null);
    System.assertNotEquals(clonedMultiple[0].size(), 0);
    System.assertNotEquals(clonedMultiple[0][0], null);
  }

  @IsTest
  private static void debuggerTest() {
    // insert a record
    Case c = new Case(Subject = 'Test Case');
    insert c;

    // Debug
    RecordCloneDebugController.RecordCloneDebugSummary summary1 = RecordCloneDebugController.showAllChildRelationships(
      null,
      'Account'
    );
    System.assertNotEquals(summary1, null);
    System.assertEquals(summary1.objectName, 'Account');
    System.assertNotEquals(summary1.relations, null);
    System.assertNotEquals(summary1.relations.size(), 0);

    RecordCloneDebugController.RecordCloneDebugSummary summary2 = RecordCloneDebugController.showAllChildRelationships(
      c.Id,
      null
    );
    System.assertNotEquals(summary2, null);
    System.assertEquals(summary2.objectName, 'Case');
    System.assertNotEquals(summary2.relations, null);
    System.assertNotEquals(summary2.relations.size(), 0);

    RecordCloneDebugController.RecordCloneDebugSummary summary3 = RecordCloneDebugController.showAllChildRelationships(
      c.Id,
      'Account'
    );
    System.assertNotEquals(summary3, null);
    System.assertEquals(summary3.objectName, 'Account');
    System.assertNotEquals(summary3.relations, null);
    System.assertNotEquals(summary3.relations.size(), 0);

    RecordCloneDebugController.RecordCloneDebugSummary summary4 = RecordCloneDebugController.showAllChildRelationships(
      null,
      null
    );
    System.assertEquals(summary4, null);

    RecordCloneDebugController.RecordCloneDebugSummary summary5 = RecordCloneDebugController.showAllChildRelationships(
      '0062w00000testoppo',
      null
    );
    System.assertNotEquals(summary5, null);
    System.assertEquals(summary5.objectName, 'Opportunity');
    System.assertNotEquals(summary5.relations, null);
    System.assertNotEquals(summary5.relations.size(), 0);

    RecordCloneDebugController.RecordCloneDebugSummary summary6 = RecordCloneDebugController.showAllChildRelationships(
      null,
      'abcdefg'
    );
    System.assertEquals(summary6, null);
  }
}
