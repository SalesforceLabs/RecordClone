/*
  Copyright (c) 2020, salesforce.com, inc.
  All rights reserved.
  SPDX-License-Identifier: BSD-3-Clause
  For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause 
*/
import { createElement } from "lwc";
import RecordClone from "c/recordClone";
import { registerApexTestWireAdapter } from "@salesforce/sfdx-lwc-jest";
import getSObjectSummary from "@salesforce/apex/RecordCloneController.getSObjectSummary";
import getNameFieldValue from "@salesforce/apex/RecordCloneController.getNameFieldValue";
import execClone from "@salesforce/apex/RecordCloneController.execClone";

const sObjectSummaryError = require("./data/sObjectSummaryError.json");
const sObjectSummarySuccess = require("./data/sObjectSummarySuccess.json");
const sObjectSummaryNonSupport = require("./data/sObjectSummaryNonSupport.json");
const sObjectSummaryTooManyChildren = require("./data/sObjectSummaryTooManyChildren.json");
import { ShowToastEventName } from "lightning/platformShowToastEvent";
import { getNavigateCalledWith } from "lightning/navigation";

jest.mock(
  "@salesforce/apex/RecordCloneController.getSObjectSummary",
  () => {
    return {
      default: jest.fn()
    };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/RecordCloneController.getNameFieldValue",
  () => {
    return {
      default: jest.fn()
    };
  },
  { virtual: true }
);

jest.mock(
  "@salesforce/apex/RecordCloneController.execClone",
  () => {
    return {
      default: jest.fn()
    };
  },
  { virtual: true }
);

const getNameFieldValueAdapter = registerApexTestWireAdapter(getNameFieldValue);
const getSObjectSummaryAdapter = registerApexTestWireAdapter(getSObjectSummary);

describe("c-record-clone", () => {
  afterEach(() => {
    while (document.body.firstChild) {
      document.body.removeChild(document.body.firstChild);
    }
    jest.clearAllMocks();
  });

  it("renders clone button after initialization done", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);
    element.nameInputLabel = "nanikore";
    getNameFieldValueAdapter.emit("Test Record Name");
    getSObjectSummaryAdapter.emit(sObjectSummarySuccess);

    return Promise.resolve().then(() => {
      const cloneButton = element.shadowRoot.querySelector("lightning-button");
      expect(cloneButton).not.toBeUndefined();
      expect(cloneButton).not.toBeNull();
    });
  });

  it("renders not supported", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);
    element.nameInputLabel = "nanikore";
    getNameFieldValueAdapter.emit("Test Record Name");
    getSObjectSummaryAdapter.emit(sObjectSummaryNonSupport);

    return Promise.resolve().then(() => {
      const errorMessage = element.shadowRoot.querySelector("h6");
      expect(errorMessage.textContent).toBe("This sObject is not supported.");
    });
  });

  it("renders input default value after init", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);

    const recordName = "Test Record Name";
    element.recordId = "MockRecordId";
    element.showDetails = true;
    getSObjectSummaryAdapter.emit(sObjectSummarySuccess);
    getNameFieldValueAdapter.emit(recordName);

    return Promise.resolve().then(() => {
      const nameInput = element.shadowRoot.querySelector("lightning-input");
      expect(nameInput.value).toBe(recordName);
    });
  });

  it("show toast on error getNameValue", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);
    const handler = jest.fn();
    element.addEventListener(ShowToastEventName, handler);

    getNameFieldValueAdapter.error({
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

  it("reflects input value change", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);

    const recordName = "Test Record Name";
    element.recordId = "MockRecordId";
    element.showDetails = true;
    getSObjectSummaryAdapter.emit(sObjectSummarySuccess);
    getNameFieldValueAdapter.emit(recordName);

    return Promise.resolve()
      .then(() => {
        const nameInput = element.shadowRoot.querySelector("lightning-input");
        expect(nameInput.value).toBe(recordName);
      })
      .then(() => {
        const nameInput = element.shadowRoot.querySelector("lightning-input");
        nameInput.value = "changed name";
        nameInput.dispatchEvent(new CustomEvent("change"));
      })
      .then(() => {
        const nameInput = element.shadowRoot.querySelector("lightning-input");
        expect(nameInput.value).toBe("changed name");
      });
  });

  it("renders error message after initialization done with any error", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);

    // getNameFieldValueAdapter.emit("Test Record Name");
    getSObjectSummaryAdapter.error(sObjectSummaryError);

    return Promise.resolve().then(() => {
      const initElem = element.shadowRoot.querySelector("h6");
      expect(initElem.textContent).toBe("Initializing...");
    });
  });

  it("shows unknown error message when no meaningful message in response", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);
    const handler = jest.fn();
    element.addEventListener(ShowToastEventName, handler);

    getSObjectSummaryAdapter.error({
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

  it("shows error toast on too many children", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);
    const handler = jest.fn();
    element.addEventListener(ShowToastEventName, handler);
    const recordName = "Test Record Name";
    element.recordId = "MockRecordId";
    element.showDetails = true;
    getSObjectSummaryAdapter.emit(sObjectSummaryTooManyChildren);
    getNameFieldValueAdapter.emit(recordName);

    return Promise.resolve().then(() => {
      expect(handler).toHaveBeenCalled();
      expect(handler.mock.calls[0][0].detail.title).toBe("RecordClone Error");
      expect(handler.mock.calls[0][0].detail.message).toBe(
        "You can't include more than 20 different child types."
      );
      expect(handler.mock.calls[0][0].detail.variant).toBe("error");
    });
  });

  it("renders a component title if title property set.", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);

    const titleText = "Hello Record Clone";
    element.componentTitle = titleText;
    return Promise.resolve().then(() => {
      const titleElement = element.shadowRoot.querySelector(
        ".slds-card__header-title .slds-truncate"
      );
      expect(titleElement.textContent).toBe(titleText);
    });
  });

  it("does not render a header if title property not set.", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);
    return Promise.resolve().then(() => {
      const header = element.shadowRoot.querySelector(".slds-card__header");
      expect(header).toBe(null);
    });
  });

  it("exec Clone on click clone button", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);

    const recordId = "MockRecordId";
    element.recordId = recordId;
    element.showDetails = true;
    element.childRecordNameType = "originalName";
    execClone.mockResolvedValue({
      Id: recordId
    });
    getNameFieldValueAdapter.emit("Test Record Name");
    getSObjectSummaryAdapter.emit(sObjectSummarySuccess);

    return Promise.resolve()
      .then(() => {
        const cloneButton =
          element.shadowRoot.querySelector("lightning-button");
        cloneButton.click();
      })
      .then(() => {
        const cloningText = element.shadowRoot.querySelector("h6");
        expect(cloningText.textContent).toBe("Cloning...");
      })
      .then(() => {
        const { pageReference } = getNavigateCalledWith();
        expect(pageReference.type).toBe("standard__recordPage");
        expect(pageReference.attributes.actionName).toBe("view");
      });
  });

  it("throw Error when clone execution returns null", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);

    const recordId = "MockRecordId";
    element.recordId = recordId;
    element.childRecordNameType = "originalName";
    execClone.mockResolvedValue(null);
    getNameFieldValueAdapter.emit("Test Record Name");
    getSObjectSummaryAdapter.emit(sObjectSummarySuccess);

    return Promise.resolve()
      .then(() => {
        const cloneButton =
          element.shadowRoot.querySelector("lightning-button");
        cloneButton.click();
      })
      .then(() => {
        expect(() => execClone()).toThrow(Error);
      });
  });

  it("shows custom toast events after clone complete", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);
    const handler = jest.fn();
    element.addEventListener(ShowToastEventName, handler);

    const recordId = "MockRecordId";
    element.recordId = recordId;
    element.childRecordNameType = "originalName";
    execClone.mockResolvedValue({
      Id: recordId
    });
    getNameFieldValueAdapter.emit("Test Record Name");
    getSObjectSummaryAdapter.emit(sObjectSummarySuccess);

    return Promise.resolve()
      .then(() => {
        const cloneButton =
          element.shadowRoot.querySelector("lightning-button");
        cloneButton.click();
      })
      .then(() => {
        const cloningText = element.shadowRoot.querySelector("h6");
        expect(cloningText.textContent).toBe("Cloning...");
      })
      .then(() => {
        expect(handler).toHaveBeenCalled();
        expect(handler.mock.calls[0][0].detail.title).toBe("Clone well done!");
        expect(handler.mock.calls[0][0].detail.message).toBe(
          "Now navigating to the newly cloned record."
        );
        expect(handler.mock.calls[0][0].detail.variant).toBe("success");
      });
  });

  it("shows custom toast events on clone error", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);
    const handler = jest.fn();
    element.addEventListener(ShowToastEventName, handler);

    element.childRecordNameType = "originalName";
    execClone.mockRejectedValue({
      message: "mock error"
    });
    getNameFieldValueAdapter.emit("Test Record Name");
    getSObjectSummaryAdapter.emit(sObjectSummarySuccess);

    return Promise.resolve()
      .then(() => {
        const cloneButton =
          element.shadowRoot.querySelector("lightning-button");
        cloneButton.click();
      })
      .then(() => {
        const cloningText = element.shadowRoot.querySelector("h6");
        expect(cloningText.textContent).toBe("Cloning...");
      })
      .then(() => {
        expect(handler).toHaveBeenCalled();
        expect(handler.mock.calls[0][0].detail.title).toBe("RecordClone Error");
        expect(handler.mock.calls[0][0].detail.message).toBe(
          "There is no available Record Id"
        );
        expect(handler.mock.calls[0][0].detail.variant).toBe("error");
      });
  });

  it("toggles related list on click list-title", () => {
    const element = createElement("c-record-clone", {
      is: RecordClone
    });
    document.body.appendChild(element);
    element.showDetails = true;
    getNameFieldValueAdapter.emit("Test Record Name");
    getSObjectSummaryAdapter.emit(sObjectSummarySuccess);

    return Promise.resolve()
      .then(() => {
        const item = element.shadowRoot.querySelector(
          "c-record-clone-related-list-item"
        );

        const listItemTitle = item.shadowRoot.querySelector(
          ".details-item-title"
        );
        listItemTitle.click();

        expect(listItemTitle.textContent).toBe("Included child objects (1)");
        expect(listItemTitle).not.toBeUndefined();
        expect(listItemTitle).not.toBeNull();
      })
      .then(() => {
        const item = element.shadowRoot.querySelector(
          "c-record-clone-related-list-item"
        );
        const detailList = item.shadowRoot.querySelector(
          ".details-item-elements"
        );
        expect(detailList).not.toBeUndefined();
        expect(detailList).not.toBeNull();
      });
  });
});
