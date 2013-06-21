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

#import <Foundation/Foundation.h>
#import <UIKit/UIkit.h>

#import "SeekbarTime.h"
#import "AdResolver.h"
#import "Scheduler.h"

@class PlaybackSegment;

@interface Sequencer : NSObject
{
@private
    UIWebView *webView;
    AdResolver *adResolver;
    Scheduler *scheduler;
    NSError *lastError;
}

@property(nonatomic, retain) AdResolver *adResolver;
@property(nonatomic, retain) Scheduler *scheduler;
@property(nonatomic, retain) NSError *lastError;
@property(nonatomic, readonly) BOOL isReady;

- (id)init;
- (BOOL) getSeekbarTime:(SeekbarTime **)seekTime andPlaybackPolicy:(NSString **)policy withMediaTime:(MediaTime *)aMediaTime playbackRate:(double)aRate currentSegment:(PlaybackSegment *)aSegment playbackRangeExceeded:(BOOL *)rangeExceeded;
- (BOOL) getSeekbarTime:(SeekbarTime **)seekTime andPlaybackPolicy:(NSString **)policy withMediaTime:(MediaTime *)aMediaTime playbackRate:(double)aRate currentSegment:(PlaybackSegment *)aSegment playbackRangeExceeded:(BOOL *)rangeExceeded leftDvrEdge:(NSTimeInterval)leftDvrEdge livePosition:(NSTimeInterval)livePosition liveEnded:(BOOL)liveEnded;
- (BOOL) getLinearTime:(NSTimeInterval *)linearTime withMediaTime:(MediaTime *)aMediaTime currentSegment:(PlaybackSegment *)aSegment;
- (BOOL) getSegmentAfterSeek:(PlaybackSegment **)seekSegment withLinearPosition:(NSTimeInterval)linearSeekPosition;
- (BOOL) getSegmentAfterSeek:(PlaybackSegment **)seekSegment withLinearPosition:(NSTimeInterval)linearSeekPosition leftDvrEdge:(NSTimeInterval)leftDvrEdge livePosition:(NSTimeInterval)livePosition;
- (BOOL) getSegmentAfterSeek:(PlaybackSegment **)seekSegment withSeekbarPosition:(SeekbarTime *)seekbarPosition currentSegment:(PlaybackSegment *)aSegment;
- (BOOL) getSegmentOnEndOfMedia:(PlaybackSegment **)nextSegment withCurrentSegment:(PlaybackSegment *)currentSegment mediaTime:(NSTimeInterval)playbackPosition currentPlaybackRate:(double)playbackRate isNotPlayed:(BOOL)isNotPlayed isEndOfSequence:(BOOL)isEndOfSequence;
- (BOOL) getSegmentOnEndOfBuffering:(PlaybackSegment **)nextSegment withCurrentSegment:(PlaybackSegment *)currentSegment mediaTime:(NSTimeInterval)playbackPosition currentPlaybackRate:(double)playbackRate;
- (BOOL) getSegmentOnError:(PlaybackSegment **)nextSegment withCurrentSegment:(PlaybackSegment *)currentSegment mediaTime:(NSTimeInterval)playbackPosition currentPlaybackRate:(double)playbackRate error:(NSString *)error isNotPlayed:(BOOL)isNotPlayed isEndOfSequence:(BOOL)isEndOfSequence;

@end

extern NSString * const PlayerSequencerErrorNotification;
extern NSString * const PlayerSequencerErrorArgsUserInfoKey;

