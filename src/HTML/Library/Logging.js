// ----------------------------------------------------------------------------
// Copyright (c) Microsoft Corporation. All rights reserved.
// ----------------------------------------------------------------------------
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
// http://www.apache.org/licenses/LICENSE-2.0
//
// THIS CODE IS PROVIDED *AS IS* BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, EITHER EXPRESS OR IMPLIED,
// INCLUDING WITHOUT LIMITATION ANY IMPLIED WARRANTIES OR CONDITIONS OF TITLE,
// FITNESS FOR A PARTICULAR PURPOSE, MERCHANTABLITY OR NON-INFRINGEMENT.
//

// This file contains a test library for logging facilities

// Set up a global namespace object for all the sub-modules to use.
var PLAYER_SEQUENCER_TEST_LIBRARY = PLAYER_SEQUENCER_TEST_LIBRARY || {};

// A logging facility
PLAYER_SEQUENCER_TEST_LIBRARY.logBook = (function ( message ) {
"use strict";

// TODO: add Date.now() time stamps to the logList items.
//       logList array will be of {'ts':number,'msg':string}
//       format out the time in HH:MM:SS.sss when generating HTML
    var logList = [],
        logListMaxLength = 20, // a reasonable alert box number of lines
        logType = 0, // eType.eNone
        logLevel = 1, // eLevel.eError
        logLineNumber = 1,
        logStartDateTime = (new Date()).getTime();
        
    return {
        eType: Object.freeze({
                eNone: 0,
                eAlert: 1,
                eConsole: 2,
                eDump: 3,
                etop: 4
        }),
        eLevel: Object.freeze({
                eNone: 0,
                eError: 1,
                eWarning: 2,
                eInfo: 3,
                eVerbose: 4,
                etop: 5
        }),
        setLoggingType: function ( aType, maxListLength ) {
            if ((logType === this.eType.eAlert) && (logType !== aType) && logList.length > 0) {
                this.dumpAlert();
            }
            logList = [];
            logType = aType; // TODO: validity checking
            if (maxListLength !== 'undefined') {
                logListMaxLength = maxListLength;
            }
        },
        setLoggingLevel: function ( aLevel ) {
            logLevel = aLevel;
        },
        log: function ( message, level ) {
            var timeStamp = (new Date()).getTime() - logStartDateTime;
            if (level === undefined) { 
                level = this.eLevel.eError;
            }
            if (logType !== this.eType.eNone && level <= logLevel) {
                switch (logType) {
                    case this.eType.eAlert:
                        logList.push( message );
                        if (logList.length >= logListMaxLength) { // max lines per alert
                            this.dumpAlert();
                        }
                        break;
                    case this.eType.eConsole:
                        console.log(message);
                        break;
                    case this.eType.eDump:
                        logList.push( "<b>" + logLineNumber.toString() + "</b>[" + timeStamp.toString() + "] " + message );
                        logLineNumber += 1;
                        if (logList.length >= logListMaxLength) { // max lines per list
                            logList.shift(); // discard oldest list item
                        }
                        break;
                }
            }
        },
        logException: function ( ex, level ) {
            var i, stackArray;
            if (level === undefined) { 
                level = this.eLevel.eError;
            }
            if (level <= logLevel) {
                this.log( 'name: ' + ex.name + '; msg: ' + ex.message + ((ex.stack) ? '; stack follows:' : '; no stack trace available'), level);
                if (typeof ex.stack === 'string') {
                    stackArray = ex.stack.split('\n');
                }
                if (ex.stack) {
                    if (!stackArray) {
                        stackArray = ex.stack;
                    }
                    for (i = 0; i < stackArray.length; i += 1) {
                        this.log( '->' + stackArray[i], level);
                    }
                }
            }
        },
        onFinished: function () {
            if (logType === this.eType.eAlert) {
                this.dumpAlert();
            }
            else {
                logList = [];
            }
        },
        dumpAlert: function () {
            var i,
                alertMsg = "";
            if (logList.length > 0) {
                for (i = 0; i < logList.length; i += 1) {
                    if (i > 0) {
                        alertMsg += '\n';
                    }
                    alertMsg += logList[i];
                }
                alert( alertMsg );
                logList = [];
            }
        },
        dumpJSON: function () {
            var retVal = JSON.stringify(logList);
            logList = [];
            return retVal;
        },
        dumpHTML: function () {
            var i, retVal = "<p>";
            for ( i = 0; i < logList.length; i += 1) {
                retVal += logList[i];
                if ((i+1) !== logList.length) {
                    retVal += "<br>";
                }
            }
            retVal += "</p>";
            logList = [];
            return retVal;
        }
    };
}());
