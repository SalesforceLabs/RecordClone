/*
  Copyright (c) 2020, salesforce.com, inc.
  All rights reserved.
  SPDX-License-Identifier: BSD-3-Clause
  For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause 
*/
import { createElement } from "lwc";
import RecordCloneConfigurator from "c/recordCloneConfigurator";
import { registerApexTestWireAdapter } from "@salesforce/sfdx-lwc-jest";
import showAllChildRelationships from "@salesforce/apex/RecordCloneDebugController.showAllChildRelationships";
import { ShowToastEventName } from "lightning/platformShowToastEvent";

jest.mock(
  "@salesforce/apex/RecordCloneDebugController.showAllChildRelationships",
  () => {
    return {
      default: jest.fn()
    };
  },
  { virtual: true }
);

const WIRE_RESULT_SUCCESS = {
  objectName: "Opportunity",
  relations: {
    AccountPartners: "Account Partner",
    ActivityHistories: "Activity History",
    AttachedContentDocuments: "Attached Content Document",
    Attachments: "Attachment"
  }
};

const showAllChildRelationshipsAdapter = registerApexTestWireAdapter(
  showAllChildRelationships
);

describe("c-record-clone-configurator", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders list of child relationships", () => {
    const element = createElement("c-record-clone-configurator", {
      is: RecordCloneConfigurator
    });
    document.body.appendChild(element);
    element.recordId = "MockRecordId";

    showAllChildRelationshipsAdapter.emit(WIRE_RESULT_SUCCESS);

    return Promise.resolve().then(() => {
      const sectionTitle = element.shadowRoot.querySelector(".section-title");
      expect(sectionTitle.textContent).toBe(
        "Child objects related to Opportunity"
      );
    });
  });

  it("show error toast on wire error", () => {
    const element = createElement("c-record-clone-configurator", {
      is: RecordCloneConfigurator
    });
    document.body.appendChild(element);
    element.recordId = "MockRecordId";
    const handler = jest.fn();
    element.addEventListener(ShowToastEventName, handler);

    showAllChildRelationshipsAdapter.error({
      fieldErrors: [{ statusCode: 400, message: "error" }],
      pageErrors: {
        sampleError: [{ statusCode: 400, message: "error" }]
      },
      otherCase: "whaaaat"
    });

    return Promise.resolve().then(() => {
      expect(handler).toHaveBeenCalled();
      expect(handler.mock.calls[0][0].detail.title).toBe("RecordClone Error");
      expect(handler.mock.calls[0][0].detail.message).not.toBe("Unknown error");
      expect(handler.mock.calls[0][0].detail.variant).toBe("error");
    });
  });

  it("show error toast on wire error 2", () => {
    const element = createElement("c-record-clone-configurator", {
      is: RecordCloneConfigurator
    });
    document.body.appendChild(element);
    element.recordId = "MockRecordId";
    const handler = jest.fn();
    element.addEventListener(ShowToastEventName, handler);

    showAllChildRelationshipsAdapter.error({
      fieldErrors: {
        aaa: [{ statusCode: 400, message: "error" }]
      },
      pageErrors: [{ statusCode: 400, message: "error" }],
      otherCase: "whaaaat"
    });

    return Promise.resolve().then(() => {
      expect(handler).toHaveBeenCalled();
      expect(handler.mock.calls[0][0].detail.title).toBe("RecordClone Error");
      expect(handler.mock.calls[0][0].detail.message).not.toBe("Unknown error");
      expect(handler.mock.calls[0][0].detail.variant).toBe("error");
    });
  });
});
