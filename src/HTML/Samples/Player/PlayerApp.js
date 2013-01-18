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

// This file contains test HTML player application code

// PLAYER_SEQUENCER namespace must already be defined. Let linters know about it:
/*global document, setTimeout, PLAYER_TEST, PLAYER_SEQUENCER, PLAYER_SEQUENCER_TEST_LIBRARY */

var PLAYER_APP = (function() {
	"use strict";

	var publicAPI,
		myLogBook = PLAYER_SEQUENCER_TEST_LIBRARY.logBook,
		isJustLoaded = true,
		isPlaying = false,
		progressCount = 0,
		statusString = "",
		myPrevStatusGetTime = (new Date()).getTime(),
		myVideoPlayer,
		myCurrentTimeMsgElement,
		mySeekbarCurrentElement,
		mySeekbarMaxClipElement;
		
	function updateTransport(isPlayingParam) {
		isPlaying = isPlayingParam;
		document.getElementById("playPauseButton").value = isPlaying ? "Pause" : "Play";
		document.getElementById("skipFwd30Button").disabled = !isPlaying;
		document.getElementById("skipBack7Button").disabled = !isPlaying;
		document.getElementById("playAdNowButton").disabled = !isPlaying;
		document.getElementById("playAdSoonButton").disabled = !isPlaying;
		document.getElementById("restartButton").disabled = isPlaying;
	}

	function showErrorMsg(message) {
		document.getElementById("errorMsg").innerHTML = message;
		if (message !== '') {
			myLogBook.log('<b>media error:</b> ' + message);
		}
	}

	function videoError(e) {
		// video playback failed so indicated paused in the UI
		updateTransport(false);
		// show a message saying why
		switch (e.target.error.code) {
			case e.target.error.MEDIA_ERR_ABORTED:
				showErrorMsg('You aborted the video playback.');
				break;
			case e.target.error.MEDIA_ERR_NETWORK:
				showErrorMsg('A network error caused the video download to fail.');
				break;
			case e.target.error.MEDIA_ERR_DECODE:
				showErrorMsg('The video playback was aborted due to a decoder error.');
				break;
			case e.target.error.MEDIA_ERR_SRC_NOT_SUPPORTED:
				showErrorMsg('The video could not be loaded because either the server or network failed or the format is not supported.');
				break;
			default:
				showErrorMsg('An unknown video error occurred:' + e.target.error.code.toString());
				break;
		}
	}

	function timeString(timeValue) {
		return (Math.round(1000 * timeValue)/1000).toString();
	}

	function showStatus(messageString, isReset) {
		var showGetTime = new Date().getTime(),
			timeDelta = showGetTime - myPrevStatusGetTime,
			timedMessage;

		myPrevStatusGetTime = showGetTime;

		if (timeDelta > 999) {
			timedMessage = '{' + (Math.round(timeDelta / 100) / 10).toString() + 's}<b>' + messageString + '</b>';
		} else {
			timedMessage = '{' + timeDelta.toString() + '}<b>' + messageString + '</b>';
		}

		if (isReset) { 
			statusString = ""; 
		} else {
			statusString += " ";
		}
		statusString += timedMessage;
		document.getElementById("statusMsg").innerHTML = statusString;
		myLogBook.log(timedMessage);
	}

	function showProgress(bufferedMsg, isReset) {
		showStatus('dl');

		if (isReset) {
			progressCount = 0;
		} else {
			progressCount += 1;
		}
		document.getElementById("bufferedMsg").innerHTML = progressCount.toString() + ': ' + bufferedMsg;
	}

	// === videoPlayer wrapper for the stacked video media element ===
	//
	// This abstraction is all that PLAYER_TEST understands

	function createVideoPlayer(mainVideoElement, adVideoElement) {
		var newVideoPlayer,
			myVideoElementMain = mainVideoElement,
			myVideoElementAd = adVideoElement,
			myVideoElementActive = null,
			myVideoElementMainClipIdSplitFrom = -1,
			myPlaybackSegment,
			asyncSeekPollCount;

        function getPlaybackStartTime() {
            ///<summary>Get the initial playback start time</summary>
            ///<returns type="number">The initial playback start time; -1 if no current segment</returns>
            return myPlaybackSegment ? myPlaybackSegment.initialPlaybackStartTime : -1;
        }

		function showSeekable() {
			var seekableProp = myVideoElementActive.seekable,
				seekableMsg = "",
				ix;

			if (seekableProp.length > 0) {
				for (ix = 0; ix < seekableProp.length; ix += 1) {
					seekableMsg += "[" + timeString(seekableProp.start(ix)) + " > " + timeString(seekableProp.end(ix)) + "] ";
				}
			}
			document.getElementById("seekableMsg").innerHTML = seekableMsg;

			return seekableMsg;
		}

		function showEventStatus(evt, messageString, isReset) {
			var isActiveElementEvent = evt.currentTarget.id === myVideoElementActive.id;

			if (!isActiveElementEvent) {
				messageString += (evt.currentTarget.id === myVideoElementAd.id) ? "(ad IGNORED)" : "(main IGNORED)";
			}
			showStatus(messageString, isReset);

			return isActiveElementEvent;
		}

		// The asyncSeekWhenSeekable is required for iOS which ignores setting currentTime if it is not seekable.
			// For user agents which have set a seekable range before asyncSeekWhenSeekable is called, then currentTime
			// is set immediately. Otherwise, since there is no media element event to work from, the seekable property 
			// is polled asynchronously and currentTime is set once it is seekable. The rate of polling is a tradeoff 
			// between compute overhead and the length of time the video will begin playing at the start of the media 
			// file before it switches to the correct starting position.
		function asyncSeekWhenSeekable() {
			var seekableProp = myVideoElementActive.seekable,
				playbackStartTime = getPlaybackStartTime(),
				ix;

			if (playbackStartTime <= 0) {
				// quit if no playback start time
				return;
			}

			if (seekableProp.length > 0) {
				myLogBook.log('seekable: ' + showSeekable());
				for (ix = 0; ix < seekableProp.length; ix += 1) {
					if (seekableProp.start(ix) <= playbackStartTime && playbackStartTime <= seekableProp.end(ix)) {
						showStatus('asyncSeek to ' + timeString(getPlaybackStartTime()));
						myVideoElementActive.currentTime = getPlaybackStartTime();
						return true;                        
					}
				}
			}

			if (isPlaying) {
				// as long as continuing to play, poll for seekable 
				if (seekableProp.length > 0) {
					showStatus('asyncSeekPollRange');
				}
				else
				// limit the number of status messages when nothing seekable
				if (asyncSeekPollCount < 10) {
					asyncSeekPollCount += 1;
					showStatus((asyncSeekPollCount===10) ? 'asyncSeekPoll ...' : 'asyncSeekPoll');
				}
				setTimeout(asyncSeekWhenSeekable, 50);
			}
		}

		// ====================================
		// === video element event handlers ===

		function loadStart(evt) {
			var currentClipId = -1,
				clipMessage = "** no current clip **",
				currentClip = myPlaybackSegment ? myPlaybackSegment.clip : null,
				isActiveElementEvent = evt.currentTarget.id === myVideoElementActive.id;

			if (isActiveElementEvent) {
				isPlaying = false;

				if (currentClip) {
					clipMessage = "<b>Loading clip " + currentClip.id.toString() + "</b> " + currentClip.clipURI + 
						" at " + timeString(getPlaybackStartTime()) + ' secs';
					currentClipId = currentClip.id;
				}
				myLogBook.log(clipMessage);

				showEventStatus(evt, 'loadStart(' + currentClipId.toString() + ')', true);

				showErrorMsg('');
				showProgress('none', 'reset');
				showSeekable();
				isJustLoaded = true;
			}
		}

		function loadedMetadata(evt) {
			if (showEventStatus(evt, 'loadedMeta')) {
				showSeekable();
			}
		}

		function loadedData(evt) {
			if (showEventStatus(evt, 'loadedData')) {
				showSeekable();
			}
		}

		function progress(evt) {
			var bufferedProp = myVideoElementActive.buffered,
				bufferedMsg = "",
				ix,
				isActiveElementEvent = evt.currentTarget.id === myVideoElementActive.id;

			if (isActiveElementEvent) {
				if (bufferedProp.length > 0) {
					for (ix = 0; ix < bufferedProp.length; ix += 1) {
						bufferedMsg += "[" + timeString(bufferedProp.start(ix)) + " > " + timeString(bufferedProp.end(ix)) + "] ";
					}
				} else {
					bufferedMsg = "none";
				}

				showProgress(bufferedMsg);
				showSeekable();
			}
		}

		function canPlay(evt) {
			if (showEventStatus(evt, 'canPlay')) {
				showSeekable();
				// comment out the following when using <video>@autoplay (which doesn't seem to work on iOS or Android): 
				myVideoElementActive.play();
			}
		}

		function durationChanged(evt) {
			var isActiveElementEvent = evt.currentTarget.id === myVideoElementActive.id;

			if (isActiveElementEvent) {
				document.getElementById("durationMsg").innerHTML = timeString(myVideoElementActive.duration);
			}
		}

		function currentTimeChanged(evt) {
			var posResult,
				isSeekable = myVideoElementActive.seekable.length > 0,
				currentTimeString = timeString(myVideoElementActive.currentTime),
				isActiveElementEvent = evt.currentTarget.id === myVideoElementActive.id;

			if (isActiveElementEvent) {				
				myCurrentTimeMsgElement.innerHTML = currentTimeString;

				myLogBook.log('timeupdate ' 
					+ currentTimeString 
					+ (isSeekable ? showSeekable() : ' not seekable;') 
					+ (isPlaying ? ' playing' : ' not playing'));

				// Filter out spurious timeupdate events produced by some user agents while seeking
				if (isPlaying && myVideoElementActive.currentTime > 0) 
				{
					posResult = PLAYER_TEST.onCurrentTimeChanged();
					if (posResult) {
						if (posResult.playbackRangeExceeded) {
							myPrevStatusGetTime = new Date().getTime();
							isPlaying = false;
						}
						mySeekbarCurrentElement.innerHTML = timeString(posResult.currentSeekbarPosition);
						mySeekbarMaxClipElement.innerHTML = timeString(posResult.maxSeekbarPosition) +
							" / clipId: " + posResult.currentClipId.toString();
					}
				}
			}
		}

		function ended(evt) {
			if (showEventStatus(evt, 'ended')) {
				PLAYER_TEST.onEndOfSegment();
				myPrevStatusGetTime = new Date().getTime();
			}
		}

		function play(evt) {
			if (showEventStatus(evt, 'play')) {
				isPlaying = true;
				updateTransport(true);
				showSeekable();
			}
		}

		function pause(evt) {
			if (showEventStatus(evt, 'pause')) {
				showSeekable();
				isPlaying = false;
				updateTransport(false);
			}
		}

		function playing(evt) {
			var playbackStartTime = getPlaybackStartTime(),
				startTimeDelta,
				isActiveElementEvent = evt.currentTarget.id === myVideoElementActive.id;

			if (isActiveElementEvent) {
				startTimeDelta = playbackStartTime - myVideoElementActive.currentTime;
				// To accommodate progress event granularity, avoid seek if 
				//    playbackStartTime is within 0.5 sec of current video element position.
				if (isJustLoaded && (playbackStartTime > 0) && (Math.abs(startTimeDelta) > 0.5)) {
					showEventStatus(evt, 'playing(' + timeString(playbackStartTime) + ')');
					asyncSeekPollCount = 0;
					asyncSeekWhenSeekable();
				} else {
					showEventStatus(evt, 'playing[' + timeString(playbackStartTime) + '/' + timeString(startTimeDelta) + ']');
				}
				showSeekable();
			} else {
				showEventStatus(evt, 'playing');
			}
		}

		function seeked(evt) {
			var isActiveElementEvent = evt.currentTarget.id === myVideoElementActive.id;

			if (isActiveElementEvent) {
				if (isJustLoaded) {
					showEventStatus(evt, 'seeked(loaded)');
					showSeekable();
					isJustLoaded = false;
					// if media element hasn't started playing, try to start play now
					if (!isPlaying) {
						myVideoElementActive.play();
					}
				} else {
					showEventStatus(evt, 'seeked');
					// TODO: Handle spontaneous seeks from video element controls.
					// Note: The native controls are supposed to be hidden but are not on iPhone/iPod
					//       which show the entire media timeline. So on those devices this seek can go 
					//       outside min/clipEndMediaTime on the clip.
					// PLAYER_TEST.onCurrentTimeChanged();
					// PLAYER_TEST.seekFromCurrentPosition(0);
				}
			}
		}

		function seeking(evt) {
			showEventStatus(evt, 'seeking');
		}

		function stalled(evt) {
			showEventStatus(evt, 'stalled');
		}

		function waiting(evt) {
			showEventStatus(evt, 'waiting');
		}

		// === end of video element event handlers ===
		// ===========================================

		newVideoPlayer = {

			// === DEFINITION of the videoPlayer interface ===
			canPlayType: function(aMimeTypeString) {
				return myVideoElementMain.canPlayType(aMimeTypeString);
			},

			setPlaybackSegment: function(aPlaybackSegment) {
				var prevIdSplitFrom;

				myPlaybackSegment = aPlaybackSegment;

				if (aPlaybackSegment) {

					if (myVideoElementActive) {
						myVideoElementActive.pause();
					}

					if (myPlaybackSegment.clip.isAdvertisement) {
						myVideoElementActive = myVideoElementAd;
					}
					else {
						myVideoElementActive = myVideoElementMain;
						prevIdSplitFrom = myVideoElementMainClipIdSplitFrom;
						myVideoElementMainClipIdSplitFrom = myPlaybackSegment.clip.idSplitFrom;
					}
					myVideoElementAd.style.visibility = (myPlaybackSegment.clip.isAdvertisement) ? "visible" : "hidden";
					myVideoElementMain.style.visibility = (!myPlaybackSegment.clip.isAdvertisement) ? "visible" : "hidden";

					if (myPlaybackSegment.clip.isAdvertisement 
						|| (myVideoElementActive.src !== myPlaybackSegment.clip.clipURI)
						|| (prevIdSplitFrom !== myPlaybackSegment.clip.idSplitFrom)) {
						myVideoElementActive.src = myPlaybackSegment.clip.clipURI;
					}
					else {
						myVideoElementActive.play();
					}
				}
				else {
					myVideoElementMain.src = null;
					myVideoElementAd.src = null;
					myVideoElementMainClipIdSplitFrom = -1;
				}
			},

			isFromBeginning: function() {
				return (getPlaybackStartTime() < 0);
			},

			playPause: function (isPlaying) {
				if (isPlaying) {
					myVideoElementActive.pause();
				} else {
					myVideoElementActive.play();
				}
			},

			get currentTime () { 
				return myVideoElementActive.currentTime; 
			},
			set currentTime (value) { 
				myVideoElementActive.currentTime = value; 
			}
			// =================================================
		};
					
		myVideoElementMain.addEventListener("error",videoError); 
		myVideoElementMain.addEventListener("durationchange",durationChanged);
		myVideoElementMain.addEventListener("timeupdate",currentTimeChanged);
		myVideoElementMain.addEventListener("loadstart",loadStart);
		myVideoElementMain.addEventListener("loadedmetadata",loadedMetadata);
		myVideoElementMain.addEventListener("loadeddata",loadedData);
		myVideoElementMain.addEventListener("progress",progress);
		myVideoElementMain.addEventListener("canplay",canPlay);
		myVideoElementMain.addEventListener("play",play);
		myVideoElementMain.addEventListener("pause",pause);
		myVideoElementMain.addEventListener("playing",playing);
		myVideoElementMain.addEventListener("seeking",seeking);
		myVideoElementMain.addEventListener("seeked",seeked);
		myVideoElementMain.addEventListener("stalled",stalled);
		myVideoElementMain.addEventListener("waiting",waiting);
		myVideoElementMain.addEventListener("ended",ended);

		myVideoElementAd.addEventListener("error",videoError); 
		myVideoElementAd.addEventListener("durationchange",durationChanged);
		myVideoElementAd.addEventListener("timeupdate",currentTimeChanged);
		myVideoElementAd.addEventListener("loadstart",loadStart);
		myVideoElementAd.addEventListener("loadedmetadata",loadedMetadata);
		myVideoElementAd.addEventListener("loadeddata",loadedData);
		myVideoElementAd.addEventListener("progress",progress);
		myVideoElementAd.addEventListener("canplay",canPlay);
		myVideoElementAd.addEventListener("play",play);
		myVideoElementAd.addEventListener("pause",pause);
		myVideoElementAd.addEventListener("playing",playing);
		myVideoElementAd.addEventListener("seeking",seeking);
		myVideoElementAd.addEventListener("seeked",seeked);
		myVideoElementAd.addEventListener("stalled",stalled);
		myVideoElementAd.addEventListener("waiting",waiting);
		myVideoElementAd.addEventListener("ended",ended);

		return newVideoPlayer;
	}

    // === Public API ===		
	publicAPI = {

		initialize: function(mainVideoElement, adVideoElement) {

			myVideoPlayer = createVideoPlayer(mainVideoElement, adVideoElement);
            PLAYER_TEST.initialize(myVideoPlayer);

			myCurrentTimeMsgElement = document.getElementById("currentTimeMsg");
			mySeekbarCurrentElement = document.getElementById("seekbarCurrent");
			mySeekbarMaxClipElement = document.getElementById("seekbarMaxClip");
		},
		
		startFromBeginning: function () {
			var posResult;
			// start at the beginning of the content by supplying the starting time parameter of zero:
			posResult = PLAYER_TEST.onCurrentTimeChanged(0);
			if (posResult) {
				mySeekbarCurrentElement.innerHTML = timeString(posResult.currentSeekbarPosition);
				mySeekbarMaxClipElement.innerHTML = timeString(posResult.maxSeekbarPosition) +
					" / clipId: " + posResult.currentClipId.toString();
			}
		},

		// === button event handlers ===

		skipButton: function (distance) {
			myPrevStatusGetTime = new Date().getTime();
			showStatus('skipButton', true);
			isJustLoaded = true;
			PLAYER_TEST.seekFromCurrentPosition(distance);
		},

		playPauseButton: function () {
			myPrevStatusGetTime = new Date().getTime();
			if (isPlaying) {
				showStatus('pauseButton');
				myVideoPlayer.playPause(isPlaying);
			} else {
				showStatus('playButton', true);
				if (myVideoPlayer.isFromBeginning()) {
					showStatus('startFromBeginning');
					publicAPI.startFromBeginning();
				} else {
					myVideoPlayer.playPause(isPlaying);
				}
			}
		},

		playAdButton: function (distance) {
			myPrevStatusGetTime = new Date().getTime();
			showStatus('adButton', true);
			isJustLoaded = true;
			PLAYER_TEST.schedulePendingAd(distance);
		},

		restartButton: function () {
			myPrevStatusGetTime = new Date().getTime();
			showStatus('restartButton', true);
			document.getElementById("seekableMsg").innerHTML = "none";
			isJustLoaded = true;
			publicAPI.startFromBeginning();
		},

		stopButton: function () {
			if (isPlaying) {
				myVideoPlayer.playPause(isPlaying);
			}
			myVideoPlayer.setPlaybackSegment(null);
		},

		dumpLogButton: function () {
			document.getElementById("logDisplay").innerHTML = PLAYER_SEQUENCER_TEST_LIBRARY.logBook.dumpHTML();
			PLAYER_SEQUENCER_TEST_LIBRARY.logBook.onFinished();
		}
	};
    return publicAPI;
}());

