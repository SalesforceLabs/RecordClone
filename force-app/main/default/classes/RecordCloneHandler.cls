/*
 * Copyright (c) 2020, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */
public with sharing class RecordCloneHandler {
  // single records
  public static CloneQueryResult getOriginalRecord(
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
        ' FROM ' +
        sObjSummary.apiName +
        ' WHERE Id = \'' +
        recordId +
        '\'';
      sObject parent = Database.query(q);
      Map<String, List<sObject>> childrens = execChildQueries(
        recordId,
        sObjSummary
      );
      CloneQueryResult cqr = new CloneQueryResult(parent, childrens);
      return cqr;
    } catch (System.QueryException e) {
      return null;
    }
  }

  // multiple records
  public static List<CloneQueryResult> getOriginalRecords(
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
        ' FROM ' +
        sObjSummary.apiName +
        ' WHERE Id IN (\'' +
        String.join(recordIds, '\',\'') +
        '\' )';
      List<sObject> parents = Database.query(q);

      Map<String, Map<String, List<sObject>>> childrens = execChildrenQueries(
        recordIds,
        sObjSummary
      );
      List<CloneQueryResult> cqrs = new List<CloneQueryResult>();
      for (sObject parent : parents) {
        Map<String, List<sObject>> children = childrens.get(parent.Id);
        cqrs.add(new CloneQueryResult(parent, children));
      }

      return cqrs;
    } catch (System.QueryException e) {
      return null;
    }
  }

  public static Map<String, List<sObject>> execChildQueries(
    Id parentId,
    sObjectSummary parentSummary
  ) {
    Map<String, List<sObject>> childrens = new Map<String, List<sObject>>();
    if (parentSummary.children != null && parentSummary.children.size() > 0) {
      for (String childRelName : parentSummary.children.keySet()) {
        sObjectSummary child = parentSummary.children.get(childRelName);
        List<String> childFields = child.filterClonableFields();
        if (child.isClonable && childFields.size() > 0) {
          String q =
            'SELECT Id, ' +
            String.join(childFields, ',') +
            ' FROM ' +
            child.apiName +
            ' WHERE ' +
            child.parentRelationshipField +
            ' = \'' +
            parentId +
            '\'';
          List<sObject> res = Database.query(q);
          childrens.put(childRelName, res);
        }
      }
    }
    return childrens;
  }

  public static Map<String, Map<String, List<sObject>>> execChildrenQueries(
    List<Id> parentIds,
    sObjectSummary parentSummary
  ) {
    Map<String, Map<String, List<sObject>>> childrens = new Map<String, Map<String, List<sObject>>>();
    Map<String, List<sObject>> children = new Map<String, List<sObject>>();
    if (parentSummary.children != null && parentSummary.children.size() > 0) {
      for (String childRelName : parentSummary.children.keySet()) {
        sObjectSummary child = parentSummary.children.get(childRelName);
        List<String> childFields = child.filterClonableFields();

        List<String> parentRelFieldNameArr = child.parentRelationshipField.split(
          '__'
        );
        if (parentRelFieldNameArr.size() > 2) {
          // with name space.
          Boolean hasMatched = false;
          for (String childField : childFields) {
            if (
              childField == child.parentRelationshipField ||
              childField ==
              parentRelFieldNameArr[1] + '__' + parentRelFieldNameArr[2]
            ) {
              hasMatched = true;
            }
          }

          if (!hasMatched) {
            childFields.add(child.parentRelationshipField);
          }
        } else {
          childFields.add(child.parentRelationshipField);
        }
        childFields = new List<String>(new Set<String>(childFields));
        if (child.isClonable && childFields.size() > 0) {
          String q =
            'SELECT Id, ' +
            String.join(childFields, ',') +
            ' FROM ' +
            child.apiName +
            ' WHERE ' +
            child.parentRelationshipField +
            ' IN (\'' +
            String.join(parentIds, '\',\'') +
            '\')';
          List<sObject> records = Database.query(q);
          for (sObject record : records) {
            Id pId = (Id) record.get(child.parentRelationshipField);
            if (childrens.get(pId) == null) {
              childrens.put(
                pId,
                new Map<String, List<sObject>>{
                  childRelName => new List<sObject>{ record }
                }
              );
            } else if (childrens.get(pId).get(childRelName) == null) {
              childrens.get(pId).put(childRelName, new List<sObject>{ record });
            } else {
              childrens.get(pId).get(childRelName).add(record);
            }
          }
        }
      }
    }
    return childrens;
  }

  public static sObject cloneRecord(
    sObject cloned,
    Map<String, List<sObject>> childrens,
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
      for (String childRelName : childrens.keySet()) {
        sObjectSummary childSummary = sObjectSummary.children.get(childRelName);

        if (!childSummary.isClonable) {
          continue;
        }

        List<sObject> children = childrens.get(childRelName);
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

  public static List<sObject> cloneRecords(
    List<CloneQueryResult> results,
    sObjectSummary sObjectSummary
  ) {
    // append to child records' name fields
    String todayStr = Datetime.now().format('yyyy/MM/dd HH:mm');

    List<sObject> parents = new List<sObject>();
    for (CloneQueryResult result : results) {
      parents.add(result.parent);
    }

    List<Id> oldIds = new List<Id>();
    for (sObject cloning : parents) {
      oldIds.add(cloning.Id);
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

    // insert parent records
    insert parents;

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

        for (CloneQueryResult result : results) {
          if (result.childrens == null) {
            continue;
          }
          List<sObject> children = result.childrens.get(childRelName);
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
            ocrIds.add(result.parent.Id);
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

            children[i]
              .put(childSummary.parentRelationshipField, result.parent.Id);
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

      if (childrens.size() > 0) {
        insert childrens;
      }
    }

    return parents;
  }
}
