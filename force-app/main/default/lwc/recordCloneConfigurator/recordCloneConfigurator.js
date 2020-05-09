/*
 * Copyright (c) 2020, salesforce.com, inc.
 * All rights reserved.
 * SPDX-License-Identifier: BSD-3-Clause
 * For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause
 */
import { LightningElement, api, track, wire } from "lwc";
import showAllChildRelationships from "@salesforce/apex/RecordCloneDebugController.showAllChildRelationships";
import { ShowToastEvent } from "lightning/platformShowToastEvent";

export default class RecordCloneConfigurator extends LightningElement {
  @api
  recordId;

  @track
  childrenList = [];

  childrenListStr = "";

  objectName = "";

  @api
  targetSObject = "";

  isInvalidObjectName = false;

  @wire(showAllChildRelationships, {
    recordId: "$recordId",
    objectName: "$targetSObject"
  })
  allChildRelationships({ error, data }) {
    if (!data) {
      if (error) {
        this.handleErrors(error);
        this.isInvalidObjectName = true;
      }
      return;
    }

    const childrenList = [];
    const childrenListStr = [];
    this.objectName = data.objectName;
    for (let key of Object.keys(data.relations)) {
      childrenList.push(key + " : " + data.relations[key]);
      childrenListStr.push(key);
    }
    this.childrenList = childrenList;
    this.childrenListStr = childrenListStr.join(",");
  }

  get hasObjectName() {
    return this.objectName && this.objectName.length > 0;
  }

  buildErrorMessage = errors => {
    let errorMessage = "";

    if (Array.isArray(errors)) {
      errors.forEach(err => {
        errorMessage += `[${err.statusCode}] ${err.message}\n`;
      });
    } else if (errors instanceof Object) {
      for (let key in errors) {
        if (errors.hasOwnProperty(key)) {
          const errs = errors[key];
          for (let err of errs) {
            errorMessage += `${key} - [${err.statusCode}] ${err.message}\n`;
          }
        }
      }
    }
    return errorMessage;
  };

  handleErrors = errors => {
    console.log(errors);
    let errorMessage = "Unknown error";
    if (errors && errors.body) {
      errorMessage = "";
      if (errors.body.fieldErrors) {
        errorMessage += this.buildErrorMessage(errors.body.fieldErrors);
      }
      if (errors.body.pageErrors) {
        errorMessage += this.buildErrorMessage(errors.body.pageErrors);
      }
    }
    const errorToast = new ShowToastEvent({
      variant: "error",
      title: "RecordClone Error",
      message: errorMessage
    });
    this.dispatchEvent(errorToast);
  };
}
