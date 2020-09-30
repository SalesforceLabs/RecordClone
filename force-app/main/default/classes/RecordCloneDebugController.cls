/*
 * Copyright (c) 2020, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */
public with sharing class RecordCloneDebugController {
  public with sharing class RecordCloneDebugSummary {
    @AuraEnabled
    public String objectName;
    @AuraEnabled
    public Map<String, String> relations;

    private RecordCloneDebugSummary(
      String objectName,
      Map<String, String> relations
    ) {
      this.objectName = objectName;
      this.relations = relations;
    }
  }

  @AuraEnabled(cacheable=true)
  public static RecordCloneDebugSummary showAllChildRelationships(
    Id recordId,
    String objectName
  ) {
    if (String.isBlank(objectName)) {
      if (String.isBlank(recordId)) {
        return null;
      }
      DescribeSObjectResult describe = recordId.getSObjectType().getDescribe();
      objectName = describe.getLocalName();
    }
    System.debug(objectName);
    Map<String, String> result = new Map<String, String>();
    sObjectType sObjType = (sObjectType) Schema.getGlobalDescribe()
      .get(objectName);
    if (sObjType == null) {
      return null;
    }
    for (
      Schema.ChildRelationship rel : sObjType.getDescribe()
        .getChildRelationships()
    ) {
      if (String.isBlank(rel.getRelationshipName())) {
        continue;
      }
      result.put(
        rel.getRelationshipName(),
        rel.getChildSObject().getDescribe().getLabel()
      );
    }
    RecordCloneDebugSummary summary = new RecordCloneDebugSummary(
      objectName,
      result
    );

    return summary;
  }
}
