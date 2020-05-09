/*
  Copyright (c) 2020, salesforce.com, inc.
  All rights reserved.
  SPDX-License-Identifier: BSD-3-Clause
  For full license text, see LICENSE.txt file in the repo root or https://opensource.org/licenses/BSD-3-Clause 
*/
/**
 * For the original lightning/platformShowToastEvent mock that comes by default with
 * @salesforce/sfdx-lwc-jest, see:
 * https://github.com/salesforce/sfdx-lwc-jest/blob/master/src/lightning-stubs/platformShowToastEvent/platformShowToastEvent.js
 */

export const ShowToastEventName = 'lightning__showtoast';

export class ShowToastEvent extends CustomEvent {
    constructor(toast) {
        super(ShowToastEventName, {
            composed: true,
            cancelable: true,
            bubbles: true,
            detail: toast
        });
    }
}