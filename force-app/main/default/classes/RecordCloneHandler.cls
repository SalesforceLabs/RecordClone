/*
 * Copyright (c) 2020, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */
public with sharing class RecordCloneHandler {
  // single records
  public static sObject getOriginalRecord(
    Id recordId,
    sObjectSummary sObjSummary
  ) {
    if (recordId == null || sObjSummary == null) {
      return null;
    }

    try {
      // Build query string
      String q =
        'SELECT Id, ' +
        String.join(sObjSummary.filterClonableFields(), ',') +
        buildChildrenSelectQuery(sObjSummary) +
        ' FROM ' +
        sObjSummary.apiName +
        ' WHERE Id = \'' +
        recordId +
        '\'';
      return Database.query(q);
    } catch (System.QueryException e) {
      return null;
    }
  }

  // multiple records
  public static List<sObject> getOriginalRecords(
    List<Id> recordIds,
    sObjectSummary sObjSummary
  ) {
    if (recordIds == null || recordIds.size() == 0 || sObjSummary == null) {
      return null;
    }

    try {
      // Build query string
      String q =
        'SELECT Id, ' +
        String.join(sObjSummary.filterClonableFields(), ',') +
        buildChildrenSelectQuery(sObjSummary) +
        ' FROM ' +
        sObjSummary.apiName +
        ' WHERE Id IN (\'' +
        String.join(recordIds, '\',\'') +
        '\' )';
      return Database.query(q);
    } catch (System.QueryException e) {
      return null;
    }
  }

  public static sObject cloneRecord(
    sObject cloned,
    sObjectSummary sObjectSummary,
    String newRecordName,
    String childRecordNameType
  ) {
    // remove original record ID, then insert.
    cloned.Id = null;

    // update the record name field to user specified
    if (sObjectSummary.isNamable) {
      cloned.put(sObjectSummary.nameField, newRecordName);
    }

    // insert a parent object record
    try {
      insert cloned;
    } catch (DMLException e) {
      return null;
    }

    // cloning child records
    if (
      sObjectSummary.children != null &&
      sObjectSummary.children.keySet().size() > 0
    ) {
      // append to child records' name fields
      String todayStr = Datetime.now().format('yyyy/MM/dd HH:mm');

      // remove child record IDs, assign then cloned parent record Id to ref field
      for (String childRelName : sObjectSummary.children.keySet()) {
        sObjectSummary childSummary = sObjectSummary.children.get(childRelName);

        if (!childSummary.isClonable) {
          continue;
        }

        List<sObject> children;
        try {
          try {
            // System.QueryException: Aggregate query has too many rows for direct assignment, use FOR loop
            // https://www.kineticgrowth.com/system-queryexception-aggregate-query-many-rows-direct-assignment-use-loop/
            // https://developer.salesforce.com/docs/atlas.en-us.apexcode.meta/apexcode/langCon_apex_loops_for_SOQL.htm
            // There are weird cases.
            // https://developer.salesforce.com/forums/?id=906F0000000AtTyIAK
            children = cloned.getSObjects(childRelName);
          } catch (System.QueryException qe) {
            System.debug('QueryException. Now try using for loop.');
            children = new List<sObject>();
            for (sObject child : cloned.getSObjects(childRelName)) {
              children.add(child);
            }
          }
        } catch (System.SObjectException e) {
          System.debug('SObjectException');
          continue;
        }
        if (children == null || children.size() == 0) {
          continue;
        }

        // On creating an opportunity record, system automatically creates an OpportunityContactRole record.
        // Delete the created record as of now.
        if (
          sObjectSummary.apiName == 'Opportunity' &&
          childRelName == 'OpportunityContactRoles'
        ) {
          OpportunityContactRole[] ocrs = [
            SELECT Id
            FROM OpportunityContactRole
            WHERE OpportunityId = :cloned.Id
          ];

          if (ocrs.size() > 0 && childSummary.isDeletable) {
            try {
              delete ocrs;
            } catch (DMLException e) {
              // if failed to delete auto-generated OpportunityContactRole,
              // leave it.
            }
          }
        }

        for (Integer i = 0; i < children.size(); i++) {
          children[i].put('Id', null);
          if (childSummary.isNamable) {
            String originalRecordName = (String) children[i]
              .get(childSummary.nameField);
            String nameValue = originalRecordName;

            if (
              childRecordNameType ==
              RecordCloneChildRecordNamePicklist.valueWithCloned
            ) {
              nameValue = 'Cloned - ' + originalRecordName;
            } else if (
              childRecordNameType ==
              RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
            ) {
              nameValue = 'Cloned - ' + originalRecordName + ' - ' + todayStr;
            }
            children[i].put(childSummary.nameField, nameValue);
          }

          children[i].put(childSummary.parentRelationshipField, cloned.Id);
        }
        insert children;
      }
    }

    return cloned;
  }

  private static String buildChildrenSelectQuery(sObjectSummary sObjSummary) {
    // concatenate clonable field names of child sObjects to build SOQL string
    String childrenSelect = '';
    if (sObjSummary.children != null && sObjSummary.children.size() > 0) {
      for (String childRelName : sObjSummary.children.keySet()) {
        sObjectSummary child = sObjSummary.children.get(childRelName);
        List<String> childFields = child.filterClonableFields();
        if (child.isClonable && childFields.size() > 0) {
          childrenSelect +=
            ', ( SELECT Id, ' +
            String.join(childFields, ',') +
            ' FROM ' +
            childRelName +
            ' )';
        }
      }
    }
    return childrenSelect;
  }

  public static List<sObject> cloneRecords(
    List<sObject> clonings,
    sObjectSummary sObjectSummary
  ) {
    // append to child records' name fields
    String todayStr = Datetime.now().format('yyyy/MM/dd HH:mm');
    for (sObject cloning : clonings) {
      cloning.Id = null;
      if (sObjectSummary.isNamable) {
        // Parent record name
        // use sObject parentRecordNameFormat or specify custom record name inputted by user.
        // cloning.put(sObjectSummary.nameField, newRecordName);

        if (sObjectSummary.isNamable) {
          String originalRecordName = (String) cloning.get(
            sObjectSummary.nameField
          );
          String nameValue = originalRecordName;
          if (
            sObjectSummary.childRecordNameFormat ==
            RecordCloneChildRecordNamePicklist.valueWithCloned
          ) {
            nameValue = 'Cloned - ' + originalRecordName;
          } else if (
            sObjectSummary.childRecordNameFormat ==
            RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
          ) {
            nameValue = 'Cloned - ' + originalRecordName + ' - ' + todayStr;
          }
          cloning.put(sObjectSummary.nameField, nameValue);
        }
      }
    }

    insert clonings;

    if (
      sObjectSummary.children != null &&
      sObjectSummary.children.keySet().size() > 0
    ) {
      // remove child record IDs, assign then cloned parent record Id to ref field
      List<sObject> childrens = new List<sObject>();
      List<Id> ocrIds = new List<Id>();
      Boolean ocrIsDeletable = false;
      for (String childRelName : sObjectSummary.children.keySet()) {
        sObjectSummary childSummary = sObjectSummary.children.get(childRelName);

        if (!childSummary.isClonable) {
          continue;
        }

        for (sObject cloning : clonings) {
          sObject[] children;
          try {
            children = cloning.getSObjects(childRelName);
          } catch (System.SObjectException e) {
            continue;
          }

          if (children == null) {
            continue;
          }

          // On creating an opportunity record, system automatically creates an OpportunityContactRole record.
          // Delete the created record as of now.
          if (
            sObjectSummary.apiName == 'Opportunity' &&
            childRelName == 'OpportunityContactRoles'
          ) {
            ocrIsDeletable = sObjectSummary.isDeletable;
            ocrIds.add(cloning.Id);
          }

          for (Integer i = 0; i < children.size(); i++) {
            children[i].put('Id', null);
            if (childSummary.isNamable) {
              String originalRecordName = (String) children[i]
                .get(childSummary.nameField);
              String nameValue = originalRecordName;
              if (
                sObjectSummary.childRecordNameFormat ==
                RecordCloneChildRecordNamePicklist.valueWithCloned
              ) {
                nameValue = 'Cloned - ' + originalRecordName;
              } else if (
                sObjectSummary.childRecordNameFormat ==
                RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
              ) {
                nameValue = 'Cloned - ' + originalRecordName + ' - ' + todayStr;
              }
              children[i].put(childSummary.nameField, nameValue);
            }

            children[i].put(childSummary.parentRelationshipField, cloning.Id);
          }
          childrens.addAll(children);
        }
      }

      if (ocrIds.size() > 0 && ocrIsDeletable) {
        List<OpportunityContactRole> ocrs = [
          SELECT Id
          FROM OpportunityContactRole
          WHERE OpportunityId IN :ocrIds
        ];
        try {
          delete ocrs;
        } catch (DMLException e) {
          // if failed to delete auto-generated OpportunityContactRole,
          // leave it.
        }
      }

      insert childrens;
    }

    return clonings;
  }
}
