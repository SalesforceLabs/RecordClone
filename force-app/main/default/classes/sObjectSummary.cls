/*
 * Copyright (c) 2020, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */
public with sharing class sObjectSummary {
  @AuraEnabled
  public String label;
  @AuraEnabled
  public String apiName;
  @AuraEnabled
  public Boolean isClonable;
  @AuraEnabled
  public String nameField;
  @AuraEnabled
  public Boolean isNamable;
  @AuraEnabled
  public String parentRelationshipField;
  @AuraEnabled
  public List<sFieldSummary> fields;
  @AuraEnabled
  public Boolean isDeletable;
  @AuraEnabled
  public String errorMessage;
  @AuraEnabled
  public Map<String, sObjectSummary> children;

  // for multiple records cloning
  @AuraEnabled
  public String parentRecordNameFormat;
  @AuraEnabled
  public String childRecordNameFormat;

  public with sharing class sFieldSummary {
    @AuraEnabled
    public String apiName;
    @AuraEnabled
    public String label;
    @AuraEnabled
    public Boolean isClonable;
    @AuraEnabled
    public String errorMessage;

    public sFieldSummary(
      DescribeSObjectResult describe,
      Schema.DescribeFieldResult dfr,
      Set<String> excludedFieldNameSet
    ) {
      this.apiName = dfr.getLocalName();
      this.label = dfr.getLabel();

      List<String> errors = new List<String>();
      // BASE64 field is not supported
      if (dfr.getType().name() == 'BASE64') {
        errors.add('BASE64');
      }
      // Inserting a OpportunityLineItem record with both of TotalPrice and UnitPrice filled causes DML Exception
      if (
        describe.getLocalName() == 'OpportunityLineItem' &&
        dfr.getLocalName() == 'TotalPrice'
      ) {
        errors.add('OPP_LINE_ITEM');
      }
      // Case ClosedDate cannot be manually edited
      if (
        describe.getLocalName() == 'Case' &&
        dfr.getLocalName() == 'ClosedDate'
      ) {
        errors.add('CASE_CLOSED_DATE');
      }
      if (!dfr.isAccessible()) {
        errors.add('NOT_ACCESSIBLE');
      }
      if (!dfr.isCreateable()) {
        errors.add('NOT_CREATEABLE');
      }
      if (dfr.isUnique()) {
        errors.add('IS_UNIQUE');
      }
      if (dfr.getLocalName().endsWith('__pc')) {
        errors.add('IS_PERSON_ACCOUNT');
      }
      if (dfr.isCalculated()) {
        errors.add('IS_CALCULATED');
      }
      if (
        excludedFieldNameSet != null &&
        excludedFieldNameSet.contains(dfr.getLocalName()) &&
        (dfr.isNillable() || dfr.isDefaultedOnCreate())
      ) {
        errors.add('IS_EXCLUDED');
      }

      this.errorMessage = String.join(errors, ',');
      this.isClonable = errors.size() == 0;
    }
  }

  public sObjectSummary(DescribeSObjectResult describe) {
    this(describe, '', '');
  }

  public sObjectSummary(
    DescribeSObjectResult describe,
    String excludedFieldNames
  ) {
    this(describe, excludedFieldNames, '');
  }

  public sObjectSummary(
    DescribeSObjectResult describe,
    String excludedFieldNames,
    String specifiedNameField
  ) {
    this.label = describe.getLabel();
    this.apiName = describe.getLocalName();
    this.isNamable = false;
    this.fields = new List<sFieldSummary>();

    // check if sObject is able to be cloned
    List<String> errors = new List<String>();
    if (!describe.isAccessible()) {
      errors.add('NOT_ACCESSIBLE');
    }
    if (!describe.isCreateable()) {
      errors.add('NOT_CREATEABLE');
    }

    if (!describe.isQueryable()) {
      errors.add('NOT_QUERYABLE');
    }
    if (this.apiName == 'Task') {
      errors.add('IS_TASK');
    }
    if (this.apiName == 'Event') {
      errors.add('IS_EVENT');
    }
    if (this.apiName == 'Attachment') {
      errors.add('IS_ATTACHMENT');
    }
    if (this.apiName == 'Document') {
      errors.add('IS_DOCUMENT');
    }
    if (this.apiName == 'QuoteDocument') {
      errors.add('IS_QUOTE_DOCUMENT');
    }
    if (this.apiName == 'ContentDocumentLink') {
      errors.add('IS_CONTENT_DOCUMENT_LINK');
    }
    if (this.apiName == 'Partner') {
      errors.add('IS_PARTNER');
    }
    if (this.apiName == 'AccountPartner') {
      errors.add('IS_ACCOUNT_PARTNER');
    }
    if (this.apiName == 'OpportunityPartner') {
      errors.add('IS_OPPORTUNITY_PARTNER');
    }
    if (this.apiName.endsWith('__share') || this.apiName.endsWith('Share')) {
      // https://salesforce.stackexchange.com/questions/219200/how-to-distinguish-manual-sharing-and-apex-sharing-in-code-level
      errors.add('IS_SHARE_OBJECT');
    }
    if (this.apiName == 'NetworkUserHistoryRecent') {
      // Implementation restriction: When querying the NetworkUserHistoryRecent object, you must filter using the following syntax: NetworkUserId = [single ID] or Id = [single ID] or Id in [Multiple Ids]
      errors.add('IS_COMMUNITY_RELATED_RESTRICTION');
    }
    this.errorMessage = String.join(errors, ',');
    this.isClonable = errors.size() == 0;

    this.isDeletable = describe.isDeletable();

    Set<String> excludedFieldNameSet = new Set<String>(
      new List<String>{
        'CreatedDate',
        'LastModifiedDate',
        'CreatedById',
        'LastModifiedById'
      }
    );

    // PersonAccount Name field is not able to clone.
    if (this.apiName == 'Account' && specifiedNameField == 'LastName') {
      excludedFieldNameSet.add('Name');
    }

    if (String.isNotBlank(excludedFieldNames)) {
      List<String> excludedFieldNameList = excludedFieldNames.deleteWhitespace()
        .split(',');
      excludedFieldNameSet.addAll(excludedFieldNameList);
    }

    Map<String, Schema.SObjectField> fieldMap = describe.fields.getMap();
    String autoNumberField = null;
    String uniqueField = null;
    String notNillableField = null;

    if (String.isNotBlank(specifiedNameField)) {
      this.nameField = specifiedNameField;
      this.isNamable = true;
    }

    for (Schema.SObjectField sfield : fieldMap.Values()) {
      Schema.DescribeFieldResult dfr = sfield.getDescribe();

      if (dfr.getLocalName() != 'Id') {
        this.fields.add(new sFieldSummary(describe, dfr, excludedFieldNameSet));
      }

      if (dfr.isNameField() && dfr.isUpdateable()) {
        this.nameField = dfr.getLocalName();
        this.isNamable = !dfr.isAutoNumber() && !dfr.isUnique();
      }
    }
  }

  // Return list of api names of clonable fields
  public List<String> filterClonableFields() {
    List<String> fieldList = new List<String>();
    for (sFieldSummary sField : this.fields) {
      if (sField.isClonable) {
        fieldList.add(sField.apiName);
      }
    }
    return fieldList;
  }

  // fetching sObjectSummary from a custom metadata type
  // Used with process builder or flow
  public static sObjectSummary getByRecordId(Id recordId) {
    if (recordId == null) {
      return null;
    }
    DescribeSObjectResult describe = recordId.getSObjectType().getDescribe();

    String objectName = describe.getLocalName();
    List<RecordCloneSettings__mdt> settings = [
      SELECT
        Id,
        ObjectName__c,
        ChildRelationshipNames__c,
        ExcludedFieldNames__c,
        ChildRecordNameType__c
      FROM RecordCloneSettings__mdt
      WHERE ObjectName__c = :objectName
    ];

    String childRelationshipNames = '';
    String excludedFieldNames = '';
    String childRecordNameFormat = RecordCloneChildRecordNamePicklist.valueOriginalName;
    if (settings != null && settings.size() > 0) {
      childRelationshipNames = settings[0].ChildRelationshipNames__c;
      excludedFieldNames = settings[0].ExcludedFieldNames__c;
      String settingChildRecordNameFormat = RecordCloneChildRecordNamePicklist.values.get(
        settings[0].ChildRecordNameType__c
      );
      if (settingChildRecordNameFormat == null) {
        childRecordNameFormat = settingChildRecordNameFormat;
      }
    }

    sObjectSummary sObjSummary = getByRecordId(
      recordId,
      childRelationshipNames,
      excludedFieldNames
    );
    sObjSummary.childRecordNameFormat = childRecordNameFormat;
    return sObjSummary;
  }

  public static sObjectSummary getByRecordId(
    Id recordId,
    String childRelationshipNames,
    String excludedFieldNames
  ) {
    if (recordId == null) {
      return null;
    }
    DescribeSObjectResult describe = recordId.getSObjectType().getDescribe();

    String specifiedNameField = '';

    // Distinguish the name field of person accounts from that of regular accounts
    if (describe.getLocalName() == 'Account') {
      if (
        Schema.sObjectType.Account.fields.getMap()
          .containsKey('IsPersonAccount')
      ) {
        try {
          sObject acc = Database.query(
            'SELECT Id, IsPersonAccount FROM Account where Id = \'' +
            recordId +
            '\''
          );
          Boolean IsPersonAccount = (Boolean) acc.get('IsPersonAccount');
          if (IsPersonAccount) {
            specifiedNameField = 'LastName';
          } else {
            specifiedNameField = 'Name';
          }
        } catch (QueryException qe) {
          return null;
        } catch (System.TypeException te) {
          return null;
        } catch (System.SObjectException sobje) {
          return null;
        }
      }
    }

    sObjectSummary sObj = new sObjectSummary(
      describe,
      excludedFieldNames,
      specifiedNameField
    );
    sObj.children = getChildren(describe, childRelationshipNames);
    return sObj;
  }

  private static Map<String, sObjectSummary> getChildren(
    DescribeSObjectResult describe,
    String childRelationshipNames
  ) {
    // Split up childRelationshipNames
    if (String.isBlank(childRelationshipNames)) {
      return null;
    }

    List<String> childRelationshipList = childRelationshipNames.deleteWhitespace()
      .split(',');
    Set<String> childRelationshipSet = new Set<String>(childRelationshipList);

    Map<String, sObjectSummary> children = new Map<String, sObjectSummary>();
    for (Schema.ChildRelationship child : describe.getChildRelationships()) {
      // Match inputted child relationship names with actual object names.
      if (childRelationshipSet.contains(child.getRelationshipName())) {
        sObjectSummary sObjectSummary = new sObjectSummary(
          child.getChildSObject().getDescribe()
        );
        sObjectSummary.parentRelationshipField = child.getField()
          .getDescribe()
          .getName();
        children.put(child.getRelationshipName(), sObjectSummary);
      }
    }
    return children;
  }
}
