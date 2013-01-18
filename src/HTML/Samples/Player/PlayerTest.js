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

// This file contains a test HTML player that uses the Player Sequencer

// PLAYER_SEQUENCER namespace must already be defined. Let linters know about it:
/*global PLAYER_SEQUENCER, PLAYER_SEQUENCER_TEST_LIBRARY */

var PLAYER_TEST = (function () {
    "use strict";
    var publicAPI,
        myLogBook = PLAYER_SEQUENCER_TEST_LIBRARY.logBook,
        myScheduler = PLAYER_SEQUENCER.scheduler,
        mySequencer = PLAYER_SEQUENCER.sequencerPluginChain.getFirstSequencer(),
        myAdResolver = PLAYER_SEQUENCER.theAdResolver,
        myVideoPlayer = null,
        myCurrentSegment = null,
        myCurrentMaxSeekbarPosition = 0,
        myCurrentSeekbarPosition = 0,
        myPendingAdParams = {};

    function timeString(timeValue) {
        return (Math.round(1000 * timeValue)/1000).toString();
    }

    // VAST helper functions:

    function convertHMSToSeconds(hmsString) {
        var hmsArray = hmsString.split(':');
        if (hmsArray.length !== 3) {
            return 0;
        }
        return (Number(hmsArray[0]) * 60 + Number(hmsArray[1])) * 60 + Number(hmsArray[2]);
    }

    function canPlayMimeType(aMimeTypeString) {
        return myVideoPlayer.canPlayType(aMimeTypeString) !== "";
    }

    function getAdSelectionArrayFromVASTEntryId(vastEntryIdNumber) {
        // Iterate through the VAST entry for the given vastEntryIdNumber returning an ad selection array of objects: 
        //     { URI, minMediaTime, maxMediaTime, adPodSequenceNumber }
        var adSelectionArray = [],
            adList,
            adListIndex,
            creativesList,
            creativesListIndex,
            creativeElements,
            creativeElementsIndex,
            creativeDuration,
            creativeMinMediaTime,
            creativeMaxMediaTime,
            adSequenceNumber,
            mediaFileList,
            mediaFileListIndex;

        adList = myAdResolver.vast.getAdList( {entryId: vastEntryIdNumber} );

        for (adListIndex = 0; adListIndex < adList.length; adListIndex += 1) {
            // Get any ad pod sequence number
            adSequenceNumber = adList[adListIndex].parentAttrs.sequence;
            // Note: for ad buffet items (no sequence attribute) the largest positive value is assigned
            //       to make them sort after the end of the ad pod set. 
            adSequenceNumber = adSequenceNumber ? Number(adSequenceNumber) : Number.MAX_VALUE;

            switch (adList[adListIndex].type) {
            case 'InLine':
                creativesList = myAdResolver.vast.getCreativeList(
                    {
                        "entryId": vastEntryIdNumber,
                        "adOrdinal": adListIndex,
                        "adType": adList[adListIndex].type
                    });
                for (creativesListIndex = 0; creativesListIndex < creativesList.length; creativesListIndex += 1) {
                    // Only deal with Linear Creative
                    if (creativesList[creativesListIndex].type === 'Linear') {
                        mediaFileList = myAdResolver.vast.getMediaFileList(
                            {
                                "entryId": vastEntryIdNumber, 
                                "adOrdinal": adListIndex, 
                                "creativeOrdinal": creativesListIndex
                            });

                        // Get the Duration element value converted to seconds
                        creativeDuration = 0;
                        creativeElements = creativesList[creativesListIndex].elements;
                        if (creativeElements) {
                            for (creativeElementsIndex = 0; creativeElementsIndex < creativeElements.length; creativeElementsIndex += 1) {
                                if (creativeElements[creativeElementsIndex].name === 'Duration') {
                                    creativeDuration = convertHMSToSeconds(creativeElements[creativeElementsIndex].value);
                                    break;
                                }
                            }
                        }
                        if (creativeDuration === 0) {
                            myLogBook.log('VAST Linear creative without Duration element! Ad ' + adListIndex.toString() + ' Creative ' + creativesListIndex.toString());
                            break;
                        }

                        // Use the first MediaFile that can be played
                        for (mediaFileListIndex = 0; mediaFileListIndex < mediaFileList.length; mediaFileListIndex += 1) {
                            if (canPlayMimeType(mediaFileList[mediaFileListIndex].attrs.type)) {
                                // Note: psns:mediaTimeOffset is a custom attribute cooked up to enable using a segment of a media file
                                // TODO: "psns" is an arbitrary namespace token defined by the XML and therefore could be anything. 
                                //       How should we deal with this ???
                                creativeMinMediaTime = Number(mediaFileList[mediaFileListIndex].attrs["psns:mediaTimeOffset"] || 0);
                                creativeMaxMediaTime = creativeMinMediaTime + Number(creativeDuration);
                                adSelectionArray.push(
                                    {
                                        URI: mediaFileList[mediaFileListIndex].value,
                                        minMediaTime: creativeMinMediaTime,
                                        maxMediaTime: creativeMaxMediaTime,
                                        adPodSequenceNumber: adSequenceNumber
                                    });
                                break;
                            }
                        }
                        if (mediaFileListIndex === mediaFileList.length) {
                            myLogBook.log('VAST none of the Linear creatives can be played! Ad ' + adListIndex.toString() + ' Creative ' + creativesListIndex.toString());
                            myLogBook.log('MediaFileList: ' + JSON.stringify(mediaFileList));
                        }
                    }
                }
                break;

            case 'Wrapper':
                myLogBook.log("VAST Wrapper manifest is not implemented!");
                break;

            case 'Extensions':
                myLogBook.log("VAST Extensions ignored!");
                break;

            default:
                myLogBook.log("Unrecognized VAST manifest type: " + adList[adListIndex].type);
            }
        }
        return adSelectionArray;
    }

    function scheduleAdSelectionArray( adSelectionArray, timeOffset, optDeleteAfterPlay ) {
        // Schedule the adSelectionArray (all in a pod or first if only a buffet) at the given timeOffset (VMAP format), and optional deleteAfterPlayed flag
        var adSelectionArrayIndex,
            adSelectionPrevId,
            adSelectionNewId,
            adSelectionRollType,
            adSelectionStartTime;

        if (adSelectionArray.length > 0) {
            adSelectionArray.sort(
                function(a,b) {
                    return a.adPodSequenceNumber - b.adPodSequenceNumber;
                }
            );
            adSelectionPrevId = -1;
            adSelectionRollType = "Post";
            adSelectionStartTime = 0;
            if (timeOffset === 'start') {
                adSelectionRollType = "Pre";
            }
            else if (timeOffset === 'end') {
                adSelectionRollType = "Post";
            }
            else if (timeOffset.indexOf("#") === 0) {
                // TODO: how to convert a VMAP position into a start time?
                // For now, treat it as a playlist clip id
                adSelectionPrevId = Number(timeOffset.substring(1));
                // myLogBook.log("Ignoring VMAP position timeOffset value: " + timeOffset.toString());
            }
            else if (timeOffset.indexOf("%") > 0) {
                // TODO: how to convert a VMAP percentage into a start time?
                myLogBook.log("Ignoring VMAP percentage timeOffset value: " + timeOffset.toString());
            }
            else if (timeOffset.indexOf(":") > 0) {
                adSelectionRollType = "Mid"; 
                adSelectionStartTime = convertHMSToSeconds(timeOffset);
            }
            else {
                myLogBook.log("Ignoring unrecognized timeOffset value: " + timeOffset.toString());
            }

            for (adSelectionArrayIndex = 0; adSelectionArrayIndex < adSelectionArray.length; adSelectionArrayIndex += 1) {
                // If only ad buffet, use the first one
                if ((adSelectionArrayIndex > 0) && (adSelectionArray[adSelectionArrayIndex].adPodSequenceNumber === Number.MAX_VALUE)) {
                    break;
                }
                adSelectionNewId = publicAPI.scheduleAd(
                    {
                        URI: adSelectionArray[adSelectionArrayIndex].URI,
                        eRollType: (adSelectionPrevId < 0) ? adSelectionRollType : "Pod",
                        minMediaTime: adSelectionArray[adSelectionArrayIndex].minMediaTime,
                        maxMediaTime: adSelectionArray[adSelectionArrayIndex].maxMediaTime,
                        startTime: adSelectionStartTime,
                        appendTo: adSelectionPrevId,
                        deleteAfterPlayed: optDeleteAfterPlay
                    });
                adSelectionPrevId = adSelectionNewId;
            }
        }
    }

    function scheduleContentSelectionArray( contentSelectionArray ) {
        // Schedule the contentSelectionArray (all in a pod or first if only a buffet)
        var contentSelectionArrayIndex;

        if (contentSelectionArray.length > 0) {
            contentSelectionArray.sort(
                function(a,b) {
                    return a.adPodSequenceNumber - b.adPodSequenceNumber;
                }
            );
            for (contentSelectionArrayIndex = 0; contentSelectionArrayIndex < contentSelectionArray.length; contentSelectionArrayIndex += 1) {
                // If only ad buffet, use the first one
                if ((contentSelectionArrayIndex > 0) && (contentSelectionArray[contentSelectionArrayIndex].adPodSequenceNumber === Number.MAX_VALUE)) {
                    break;
                }
                publicAPI.scheduleContent(
                    {
                        URI: contentSelectionArray[contentSelectionArrayIndex].URI,
                        minMediaTime: contentSelectionArray[contentSelectionArrayIndex].minMediaTime,
                        maxMediaTime: contentSelectionArray[contentSelectionArrayIndex].maxMediaTime
                    });
            }
        }
    }

    // === Public API ===       
    publicAPI = {

        initialize: function(aVideoPlayer) {
            ///<summary> Initialize providing a videoPlayer object</summary>
            ///<param name="aVideoPlayer" type="Object">An object with methods canPlayMimeType(string), setPlaybackSegment(playbackSegment), and currentTime property getter/setter</param>
            myVideoPlayer = aVideoPlayer;
        },

        scheduleContent: function (params) {
            ///<summary>Schedule program content</summary>
            ///<param name="params" type="Object">An object with properties: URI, minMediaTime, maxMediaTime</param>
            var clipParams,
                mainEntry;

            clipParams = myScheduler.createContentClipParams();
            clipParams.clipURI = params.URI;
            clipParams.clipBeginMediaTime = params.minMediaTime;
            clipParams.clipEndMediaTime = params.maxMediaTime;

            mainEntry = myScheduler.appendContentClip(clipParams);

            myScheduler.setSeekToStart();
        },

        scheduleAd: function (params) {
            ///<summary>Schedule ad content</summary>
            ///<param name="params" type="Object">An object with properties: URI, eClipType, eRollType, minMediaTime, maxMediaTime, startTime (if eRollType === "Mid"), appendTo (if eRollType === "Pod")</param>
            ///<returns type="number">The new playlist entry id</returns>
            var entryIdResult,
                clipParams,
                adEntry;

            clipParams = myScheduler.createScheduleClipParams();
            clipParams.clipURI = params.URI;
            clipParams.eClipType = params.eClipType || "Media";
            clipParams.eRollType = params.eRollType || "Mid";
            clipParams.clipBeginMediaTime = params.minMediaTime || 0;
            clipParams.clipEndMediaTime = params.maxMediaTime;

            if (clipParams.eRollType === "Mid") {
                clipParams.startTime = params.startTime;
            } else if (clipParams.eRollType === "Pod") {
                clipParams.appendTo = params.appendTo;
            }

            if (params.deleteAfterPlayed) {
                clipParams.deleteAfterPlayed = true;
            }

            adEntry = myScheduler.scheduleClip(clipParams);

            entryIdResult = adEntry.id;

            return entryIdResult;
        },

        scheduleContentFromVAST: function (docVAST) { 
            ///<summary>Schedule content based on a VAST document (either XML string or parsed Document)</summary>
            ///<param name="docVAST" type="Object">An XML string or parsed Document</param>

            var vastEntryIdNumber, contentSelectionArray;

            vastEntryIdNumber = myAdResolver.vast.createEntry( docVAST );

            contentSelectionArray = getAdSelectionArrayFromVASTEntryId( vastEntryIdNumber );

            myAdResolver.releaseEntry( vastEntryIdNumber );

            scheduleContentSelectionArray( contentSelectionArray );
        },

        scheduleVAST: function (docVAST, vmapTimeOffset) { 
            ///<summary>Schedule ad content based on a VAST document (either XML string or parsed Document)</summary>
            ///<param name="docVAST" type="Object">An XML string or parsed Document</param>
            ///<param name="vmapTimeOffset" type="String">A time offset with one of the VMAP timeOffset attribute values</param>

            var vastEntryIdNumber, adSelectionArray;

            vastEntryIdNumber = myAdResolver.vast.createEntry( docVAST );

            adSelectionArray = getAdSelectionArrayFromVASTEntryId( vastEntryIdNumber );

            myAdResolver.releaseEntry( vastEntryIdNumber );

            scheduleAdSelectionArray( adSelectionArray, vmapTimeOffset );
        },

        scheduleVMAP: function (docVMAP, onGetURI) {
            ///<summary>Schedule ad content based on a VAST document (either XML string or parsed Document)</summary>
            ///<param name="docVMAP" type="String">XML string or parsed Document</param>
            ///<param name=onGetURI" type="function">callback function which given an URI returns an XML string or parsed Document</param>

            var vmapEntryIdNumber,
                adBreakList,
                adBreakListIndex, 
                eltList, 
                eltListIndex,
                adBreakTimeOffset,
                itemList;

            function myAdSourceHandler () {
                var params, itemList, vastEntryIdNumber, adSelectionArray; 

                params = { entryId:vmapEntryIdNumber, adBreakOrdinal:adBreakListIndex };

                itemList = myAdResolver.vmap.getAdSource(params);
                if (itemList.length !== 1) {
                    myLogBook.log('AdSource contains other than a single child element!');
                } else {
                    switch (itemList[0].type) {
                        case "VASTData":
                            vastEntryIdNumber = myAdResolver.vmap.createVASTEntryFromAdBreak( params );
                            adSelectionArray = getAdSelectionArrayFromVASTEntryId( vastEntryIdNumber );
                            myAdResolver.releaseEntry( vastEntryIdNumber );
                            scheduleAdSelectionArray( adSelectionArray, adBreakTimeOffset );
                            break;
                        case "CustomAdData":
                            myLogBook.log('AdSource CustomAdData ignored!');
                            break;
                        case "AdTagURI":
                            publicAPI.scheduleVAST( onGetURI(itemList[0].value), adBreakTimeOffset );
                            break;
                        default:
                            myLogBook.log('<b>Unexpected AdSource type: </b>' + itemList[0].type);
                    }
                }
            }

            vmapEntryIdNumber = myAdResolver.vmap.createEntry(docVMAP);

            adBreakList = myAdResolver.vmap.getAdBreakList( {entryId: vmapEntryIdNumber} );

            // Iterate through the adBreakList picking out various elements
            for (adBreakListIndex = 0; adBreakListIndex < adBreakList.length; adBreakListIndex += 1) {

                eltList = adBreakList[adBreakListIndex].elements;

                for (eltListIndex = 0; eltListIndex < eltList.length; eltListIndex += 1) {

                    adBreakTimeOffset = adBreakList[adBreakListIndex].attrs.timeOffset;

                    // switch on eltList[eltListIndex].name 
                    // note: since there can only be 0 or 1 of the following, we don't need the eltListIndex
                    // case "AdSource": getAdSource(adBreakIndex) // returns name, value, attrs
                    // case "TrackingEvents": getTrackingEvents(adBreakIndex)
                    // case "Extensions": getExtensionList(adBreakIndex) // the app must drill down into the embedded xml for each <Extension> element

                    switch (eltList[eltListIndex]) {
                        case "AdSource": 
                            myAdSourceHandler();
                            break;

                        case "TrackingEvents":
                            itemList = myAdResolver.vmap.getTrackingEventsList({ entryId:vmapEntryIdNumber, adBreakOrdinal:adBreakListIndex });
                            myLogBook.log('Ignoring TrackingEvents: ' + JSON.stringify(itemList));
                            break;

                        case "Extensions":
                            itemList = myAdResolver.vmap.getExtensionsList({ entryId:vmapEntryIdNumber, adBreakOrdinal:adBreakListIndex });
                            myLogBook.log('Ignoring Extensions: ' + JSON.stringify(itemList));
                            // TODO: For specifying deleteAfterPlayed, we could have a custom Extension with an attribute "deleteAfterPlayed"
                            // To use this, we would need to process Extensions before processing the AdSource element.
                            // It would be easier if there could be a custom attribute on AdSource but that isn't in the spirit of the VMAP spec.
                            break;

                        default:
                            myLogBook.log('unexpected AdBreak child element: ' + eltList[eltListIndex]);
                    }
                }
            }
        },

        setPendingAdVAST: function (docVAST) {
            var vastEntryIdNumber;

            myPendingAdParams = {};

            vastEntryIdNumber = myAdResolver.vast.createEntry( docVAST );

            myPendingAdParams.adSelectionArray = getAdSelectionArrayFromVASTEntryId( vastEntryIdNumber );

            myAdResolver.releaseEntry( vastEntryIdNumber );

            myPendingAdParams.deleteAfterPlayed = true;
        },

        schedulePendingAd: function (timeOffset) {
            var vmapTimeOffset, currentLinearTime;

            currentLinearTime = mySequencer.mediaToLinearTime(
                    { 
                        currentSegmentId: myCurrentSegment.segmentId, 
                        currentPlaybackPosition: myVideoPlayer.currentTime
                    }
                );

            if (!timeOffset && myCurrentSegment.clip.isAdvertisement) {
                vmapTimeOffset = '#' + myCurrentSegment.clip.id.toString();
            } else {
                vmapTimeOffset = "0:0:" + (currentLinearTime + (timeOffset || 0)).toString();
            }

            scheduleAdSelectionArray(myPendingAdParams.adSelectionArray, vmapTimeOffset, myPendingAdParams.deleteAfterPlayed);

            if (!timeOffset) {
                publicAPI.onEndOfSegment();
            }
        },

        onEndOfSegment: function () {
            var params = {},
                currentIdSplitFrom;

            params = {
                currentSegmentId: myCurrentSegment.segmentId,
                currentPlaybackRate: 1,
                currentPlaybackPosition: myVideoPlayer.currentTime
            };

            currentIdSplitFrom = myCurrentSegment.clip.idSplitFrom;
            myCurrentSegment = mySequencer.onEndOfMedia(params);
            if (myCurrentSegment !== null) {
                if (myCurrentSegment.clip.eClipType === 'SeekToStart') {
                    myLogBook.log('<b>SeekToStart EOS</b> CT:' + timeString(myVideoPlayer.currentTime));
                    // first end the SeekToStart segment so it will be deleted
                    params.currentSegmentId = myCurrentSegment.segmentId;
                    params.currentPlaybackRate = 1;
                    myCurrentSegment = mySequencer.onEndOfMedia(params);
                }
                // switch to new clip if changed
                if (currentIdSplitFrom !== myCurrentSegment.clip.idSplitFrom) {
                    myLogBook.log('<b>Switch Clip</b>: ' + myCurrentSegment.clip.clipURI);
                    myVideoPlayer.setPlaybackSegment(myCurrentSegment);
                } else {
                    // just seek to the new position
                    myLogBook.log('<b>Seek in clip</b>: ' + timeString(myCurrentSegment.initialPlaybackStartTime));
                    myVideoPlayer.currentTime = myCurrentSegment.initialPlaybackStartTime;
                }
            } else {
                // terminate playback
                myVideoPlayer.setPlaybackSegment(null);
            }
        },

        onCurrentTimeChanged: function (startingLinearTime) {
            ///<summary>Notify seekbar time change. Can change the current playback segment.</summary>
            ///<param name="startingLinearTime" type="number">Optional start time for starting playback</param>
            ///<returns type="Object">A result object with properties of sequencer mediaToSeekbarTime() plus currentClipId</returns>
            var params = {},
                result;

            try {
                if (startingLinearTime !== undefined) {
                    myCurrentSegment = PLAYER_SEQUENCER.sequencerPluginChain.getFirstSequencer().seekFromLinearPosition({ linearSeekPosition: startingLinearTime });
                }

                if (!myCurrentSegment || !myCurrentSegment.clip) {
                    return;
                }

                if (myCurrentSegment.clip.eClipType === 'SeekToStart') {
                    myLogBook.log('<b>SeekToStart</b>');
                    // first end the SeekToStart segment so it will be deleted
                    params.currentSegmentId = myCurrentSegment.segmentId;
                    params.currentPlaybackRate = 1;
                    myCurrentSegment = mySequencer.onEndOfMedia(params);
                }
                params = {
                    currentSegmentId: myCurrentSegment.segmentId,
                    playbackRate: 1,
                    currentPlaybackPosition: (startingLinearTime === undefined) ? myVideoPlayer.currentTime : startingLinearTime
                };
                result = mySequencer.mediaToSeekbarTime(params);
                        /*
                         * result = {
                         *   currentSeekbarPosition: number,
                         *   minSeekbarPosition: number,
                         *   maxSeekbarPosition: number,
                         *   playbackPolicy: PLAYER_SEQUENCER.playbackPolicy
                         *   playbackRangeExceeded: boolean
                         * }
                         */
                if (result.playbackRangeExceeded) {
                    myLogBook.log('playbackRangeExceeded for time: ' + timeString(params.currentPlaybackPosition) + 
                        ' min/max ' + timeString(myCurrentSegment.clip.clipBeginMediaTime) + 
                        ' / '+ timeString(myCurrentSegment.clip.clipEndMediaTime));
                    publicAPI.onEndOfSegment();
                } else if (startingLinearTime !== undefined) {
                    // switch to starting clip
                    myVideoPlayer.setPlaybackSegment(myCurrentSegment);
                }

                myCurrentMaxSeekbarPosition = result.maxSeekbarPosition;
                myCurrentSeekbarPosition = result.currentSeekbarPosition;

            } catch (ex) {
                myLogBook.logException(ex);
                result = null;
                myCurrentMaxSeekbarPosition = 0;
            }

            if (result) {
                result.currentClipId = myCurrentSegment ? myCurrentSegment.clip.id : -1;
            }
            return result;
        },

        seekFromCurrentPosition: function (skipDistance) {
            ///<summary>Perform a seekbar seek. Changes the current playback segment. Changes video element currentTime.</summary>
            ///<param name="skipDistance" type="number">Signed delta to change from the current video element currentTime.</param>
            var params = {
                    currentSegmentId: myCurrentSegment.segmentId,
                    playbackRate: 1,
                    seekbarSeekPosition: myCurrentSeekbarPosition + skipDistance
                },
                currentIdSplitFrom = myCurrentSegment.clip.idSplitFrom;
                
            try {
                myCurrentSegment = mySequencer.seekFromSeekbarPosition(params);

                // if clip changed then switch to it
                if (currentIdSplitFrom !== myCurrentSegment.clip.idSplitFrom) {
                    myVideoPlayer.setPlaybackSegment(myCurrentSegment);
                } else {
                    // just seek to the new position in the currently playing clip
                    myVideoPlayer.currentTime = myCurrentSegment.initialPlaybackStartTime;
                }
            } catch (ex) {
                if (ex.name === "PLAYER_SEQUENCER:SequencerError") {
                    publicAPI.onEndOfSegment();
                } else {
                    myLogBook.logException(ex);
                }
            }
        }
    };
    return publicAPI;
}());
