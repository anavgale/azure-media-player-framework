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

// This file contains the empty implementation for a Sequencer plugin. The app developer can fill in the implemenation
// and add more sequencer plugins in this file.

//
// The namespace object
//
var PLAYER_SEQUENCER = PLAYER_SEQUENCER || {};

PLAYER_SEQUENCER.createLiveSequencerPlugin = function (livePlugin) {
    "use strict";

    var mySequentialPlaylist = PLAYER_SEQUENCER.sequentialPlaylist.change;

    livePlugin.mediaToSeekbarTime = function (params) {
        /* params:
        currentSegmentId,           // number: the unique Id for the playback segment
        playbackRate,               // number: the current playback rate
        currentPlaybackPosition,    // number: the current position in media time
        leftDvrEdge,                // number: the left edge of the DVR window in media time
        livePosition,               // number: the live position in media time
        liveEnded,                  // boolean: if the live presentation ended
        checkLoad,                  // boolean: true if just checking load of the JS file
        */

        var nextSequencer,
            result,
            currentSegment,
            entry,
            currentPosition;

        if (params.checkLoad) {
            result = 'Plugin loaded successfully';
        }
        else {
            nextSequencer = livePlugin.getNextSequencer(),
            result = nextSequencer.mediaToSeekbarTime(params),
            currentSegment = PLAYER_SEQUENCER.playbackSegmentPool.getPlaybackSegment(params.currentSegmentId),
            entry = currentSegment.clip,
            currentPosition = params.currentPlaybackPosition + entry.linearStartTime - entry.clipBeginMediaTime;
            
            if (params.liveEnded) {
                // Handle liveEnded to update the sequential playlist entry
                // Need to consider ads scheduled outside DVR window to remove entries appropriately
                if (params.leftDvrEdge !== undefined) {
                    PLAYER_SEQUENCER.sequentialPlaylist.change.removeEntriesBeforeTime(params.leftDvrEdge);
                }
                
                if (params.livePosition !== undefined) {
                    PLAYER_SEQUENCER.sequentialPlaylist.change.removeEntriesAfterTime(params.livePosition);
                }
            }
            else if (!(params.leftDvrEdge === undefined && params.livePosition === undefined || entry.isAdvertisement && currentSegment.clip.linearDuration === 0)) {
                // override the base sequencer seekbar range
                if (params.leftDvrEdge !== undefined) {
                    // throw exception for left DVR take-over
                    if (currentPosition < params.leftDvrEdge) {
                        throw new PLAYER_SEQUENCER.SequencerError(
                                                                  'mediaToSeekbarTime failed since current playback position ' + currentPosition.toString() + 'is taken over by left DVR edge ' + params.leftDvrEdge.toString());
                    }
                    
                    // override the seekbar range with left DVR edge
                    if (result.minSeekbarPosition < params.leftDvrEdge) {
                        result.minSeekbarPosition = params.leftDvrEdge;
                    }
                }
                
                if (params.livePosition !== undefined) {
                    // override the seekbar range with live position
                    if (result.maxSeekbarPosition > params.livePosition) {
                        result.maxSeekbarPosition = params.livePosition;
                    }
                }
            }
        }

        return result;
    };

    livePlugin.seekFromLinearPosition = function (params) {
        /* params:
        currentSegmentId,           // number: optional unique Id for the currrent playback segment; 0 or undefined for no current segment
        linearSeekPosition          // number: the linear position to seek to, used mainly for resuming from the previous session
        leftDvrEdge,                // number: the left edge of the DVR window in media time
        livePosition,               // number: the live position in media time
        */

        if (params.leftDvrEdge !== undefined && params.linearSeekPosition < params.leftDvrEdge) {
            params.linearSeekPosition = params.leftDvrEdge;
        }
        
        if (params.livePosition !== undefined && params.livePosition < params.linearSeekPosition) {
            params.linearSeekPosition = params.livePosition;
        }

        return livePlugin.getNextSequencer().seekFromLinearPosition(params);
    };
};

PLAYER_SEQUENCER.createCustomSequencerPlugin = function (customPlugin) {
    "use strict";
    
    // Replace the default pass-through methods
    
    // This is a sample code to throw exception in mediaToSeekbarTime to test
    // if the plugin is successfully created. Please remove this or replace this with real implementation
    // if you want to implement a custom sequencer plugin
//    customPlugin.mediaToSeekbarTime = function ( params ) {
//        throw new PLAYER_SEQUENCER.SequencerError('If you see this the plugin is correctly added to the project');
//    };
};

PLAYER_SEQUENCER.createLiveSequencerPlugin(PLAYER_SEQUENCER.sequencerPluginChain.createSequencerPlugin());

PLAYER_SEQUENCER.createCustomSequencerPlugin(PLAYER_SEQUENCER.sequencerPluginChain.createSequencerPlugin());



