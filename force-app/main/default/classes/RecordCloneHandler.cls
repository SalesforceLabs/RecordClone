/*
 * Copyright (c) 2020, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */
public with sharing class RecordCloneHandler {
  // single record
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

      // fetch child records
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

  private static Map<String, List<sObject>> execChildQueries(
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

    if (
      sObjectSummary.children == null ||
      sObjectSummary.children.keySet().size() == 0
    ) {
      return cloned;
    }

    // cloning child records

    // <objectApiName, <recordId, sObject>>
    Map<String, Map<Id, sObject>> childrensMap = new Map<String, Map<Id, sObject>>();
    Map<String, List<String>> parentRelFieldMap = new Map<String, List<String>>();
    Map<String, sObjectSummary> summaryMap = new Map<String, sObjectSummary>();

    for (String childRelName : childrens.keySet()) {
      sObjectSummary childSummary = sObjectSummary.children.get(childRelName);

      if (!childSummary.isClonable) {
        continue;
      }

      List<sObject> children = childrens.get(childRelName);
      if (children == null || children.size() == 0) {
        continue;
      }

      List<String> existingParentNames = parentRelFieldMap.get(
        childSummary.apiName
      );
      if (existingParentNames == null) {
        // is first time to check the sObject type
        summaryMap.put(childSummary.apiName, childSummary);
        childrensMap.put(childSummary.apiName, new Map<Id, sObject>(children));
        parentRelFieldMap.put(
          childSummary.apiName,
          new List<String>{ childSummary.parentRelationshipField }
        );
      } else {
        // has existing sObject type
        Map<Id, sObject> existingChildren = childrensMap.get(
          childSummary.apiName
        );
        existingChildren.putAll(children);
        childrensMap.put(childSummary.apiName, existingChildren);
        existingParentNames.add(childSummary.parentRelationshipField);
        parentRelFieldMap.put(childSummary.apiName, existingParentNames);
      }
    }

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

      Map<Id, sObject> childrenMap = childrensMap.get(childSummary.apiName);

      // TODO: If child record has master-detail relationship with its parent,
      // and "Allow reparenting" setting is off, the field is not updatable.
      // take it into account with the following options
      // 1: skip the child relation,
      // 2: leave the field with the original record id,
      // 3: let admin choose the behaviour by user.
      // * option 2 is dangerous when children is able to copy, which id (before/after clone) should be attached to the children?
      System.debug(
        childSummary.parentRelationshipField +
        ' ' +
        childSummary.isEditableParentRelationship
      );

      for (Integer i = 0; i < children.size(); i++) {
        Id childId = (Id) children[i].get('Id');
        sObject child = childrenMap.get(childId);
        if (childSummary.isNamable) {
          // set cloned child records' name value
          child.put(
            childSummary.nameField,
            getNameValue(
              (String) child.get(childSummary.nameField),
              childRecordNameType
            )
          );
        }

        child.put(childSummary.parentRelationshipField, cloned.Id);
      }
    }

    // remove child record Ids and exec insertion
    for (String childrensKey : childrensMap.keySet()) {
      Map<Id, sObject> childrenMap = childrensMap.get(childrensKey);
      List<sObject> children = childrenMap.values();
      for (Integer i = 0; i < children.size(); i++) {
        children[i].put('Id', null);
      }
      insert children;
    }

    return cloned;
  }

  public static List<sObject> cloneRecords(
    List<CloneQueryResult> results,
    sObjectSummary sObjectSummary
  ) {
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
          cloning.put(
            sObjectSummary.nameField,
            getNameValue(
              (String) cloning.get(sObjectSummary.nameField),
              sObjectSummary.childRecordNameFormat
            )
          );
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
              children[i]
                .put(
                  childSummary.nameField,
                  getNameValue(
                    (String) children[i].get(childSummary.nameField),
                    sObjectSummary.childRecordNameFormat
                  )
                );
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

  private static String todayStr = Datetime.now().format('yyyy/MM/dd HH:mm');

  private static String getNameValue(
    String originalRecordName,
    String childRecordNameFormat
  ) {
    if (
      childRecordNameFormat ==
      RecordCloneChildRecordNamePicklist.valueWithCloned
    ) {
      return 'Cloned - ' + originalRecordName;
    } else if (
      childRecordNameFormat ==
      RecordCloneChildRecordNamePicklist.valueWithClonedAndDate
    ) {
      return 'Cloned - ' + originalRecordName + ' - ' + todayStr;
    } else {
      return originalRecordName;
    }
  }
}
