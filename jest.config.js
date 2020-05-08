const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');
module.exports = {
    ...jestConfig,
    moduleNameMapper: {
        '^@salesforce/apex/RecordCloneController.getSObjectSummary': '<rootDir>/force-app/test/jest-mocks/apex/getSObjectSummary',
        '^@salesforce/apex/RecordCloneController.getNameFieldValue': '<rootDir>/force-app/test/jest-mocks/apex/getNameFieldValue',
        '^@salesforce/apex/RecordCloneController.execClone': '<rootDir>/force-app/test/jest-mocks/apex/execClone',
        '^@salesforce/apex/RecordCloneDebugController.showAllChildRelationships': '<rootDir>/force-app/test/jest-mocks/apex/showAllChildRelationships',
        '^lightning/navigation$':
            '<rootDir>/force-app/test/jest-mocks/lightning/navigation',
        '^lightning/platformShowToastEvent$':
            '<rootDir>/force-app/test/jest-mocks/lightning/platformShowToastEvent',
    }
};