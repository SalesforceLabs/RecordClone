/*
 * Copyright (c) 2020, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */
global with sharing class RecordCloneChildRecordNamePicklist extends VisualEditor.DynamicPickList {
  public static String labelOriginalName = '[Child Record Name]';
  public static String labelWithCloned = 'Cloned - [Child Record Name]';
  public static String labelWithClonedAndDate = 'Cloned - [Child Record Name] - [YYYY/mm/dd HH:ii]';

  public static String valueOriginalName = 'originalName';
  public static String valueWithCloned = 'withCloned';
  public static String valueWithClonedAndDate = 'withClonedAndDate';

  public static Map<String, String> values = new Map<String, String>{
    labelOriginalName => valueOriginalName,
    labelWithCloned => valueWithCloned,
    labelWithClonedAndDate => valueWithClonedAndDate
  };

  global override VisualEditor.DataRow getDefaultValue() {
    VisualEditor.DataRow defaultValue = new VisualEditor.DataRow(
      labelOriginalName,
      valueOriginalName
    );
    return defaultValue;
  }
  global override VisualEditor.DynamicPickListRows getValues() {
    VisualEditor.DynamicPickListRows picklistValues = new VisualEditor.DynamicPickListRows();
    for (String label : values.keySet()) {
      picklistValues.addRow(new VisualEditor.DataRow(label, values.get(label)));
    }
    return picklistValues;
  }
}
