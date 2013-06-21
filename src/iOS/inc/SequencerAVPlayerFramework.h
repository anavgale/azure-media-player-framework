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
#import <UIKit/UIKit.h>
#import "PlaylistEntry.h"

#ifdef ENABLE_FRAMEWORK_TRACE
#define FRAMEWORK_LOG(format, ...) NSLog(format, ## __VA_ARGS__)
#else
#define FRAMEWORK_LOG(format, ...)
#endif

#define LIVE_END (NSTimeInterval)INT_MAX

@class AVPlayer;
@class Sequencer;
@class Scheduler;
@class AdResolver;
@class PlaybackSegment;
@class SeekbarTime;
@class MediaTime;
@class LinearTime;
@class AdInfo;
@class MediaFile;

@protocol VASTAdSelection <NSObject>

@optional
- (MediaFile *)selectMediaFile:(NSArray *)mediaFilesList;

@end

@interface SeekbarTimeUpdatedEventArgs : NSObject
{
@private
    SeekbarTime *seekbarTime;
}

@property (nonatomic, retain) SeekbarTime *seekbarTime;

@end;

@interface PlaylistEntryChangedEventArgs : NSObject
{
@private
    PlaylistEntry *currentEntry;
    PlaylistEntry *nextEntry;
    NSTimeInterval currentPlaybackTime;
}

@property (nonatomic, retain) PlaylistEntry *currentEntry;
@property (nonatomic, retain) PlaylistEntry *nextEntry;
@property (nonatomic, assign) NSTimeInterval currentPlaybackTime;

@end;

@interface SequencerAVPlayerFramework : NSObject
{
@private
    AVPlayer *player;
    AVPlayer *livePlayer;
    Sequencer *sequencer;
    PlaybackSegment *currentSegment;
    PlaybackSegment *nextSegment;
    NSMutableArray *avPlayerViews;
    float rate;
    NSTimer *seekbarTimer;
    NSTimer *loadingTimer;
    int32_t timerCount;
    BOOL isStopped;
    BOOL resetView;
    BOOL isLive;
    BOOL hasStarted;
    BOOL hasStartedAfterStop;
    BOOL isSeekingAVPlayer;
    NSTimeInterval leftDvrEdge;
    NSTimeInterval livePosition;
    NSTimeInterval livePositionDelta;
    NSTimeInterval currentPlaylistEntryPosition;
    NSTimeInterval initialPlaybackPosition;
    NSError *lastError;
    id appDelegate;
}

@property (nonatomic, retain) AVPlayer *player;
@property (nonatomic, readonly) AdResolver *adResolver;
@property (nonatomic, assign) float rate;
@property (nonatomic, readonly) NSTimeInterval currentPlaybackTime;
@property (nonatomic, readonly) NSTimeInterval currentLinearTime;
@property (nonatomic, retain) NSError *lastError;
@property (nonatomic, retain) id appDelegate;

- (id) initWithView:(UIView *)videoView;
- (BOOL) play;
- (BOOL) playAtTime:(NSTimeInterval)linearTime;
- (void) pause;
- (BOOL) stop;
- (BOOL) seekToTime:(NSTimeInterval)seekTime;
- (BOOL) skipCurrentPlaylistEntry;

- (BOOL) scheduleClip:(AdInfo *)ad atTime:(LinearTime *)linearTime forType:(PlaylistEntryType)type andGetClipId:(int32_t *)clipId;
- (BOOL) scheduleVASTClip:(AdInfo *)ad withManifest:(NSString *)vastManifest atTime:(LinearTime *)linearTime andGetClipId:(int32_t *)clipId;
- (BOOL) scheduleVMAPWithManifest:(NSString *)vmapManifest;
- (BOOL) appendContentClip:(NSURL *)clipURL withMediaTime:(MediaTime *)mediaTime andGetClipId:(int32_t *)clipId;
- (BOOL) cancelClip:(int32_t)clipContext;

@end

extern NSString * const SeekbarTimeUpdatedNotification;
extern NSString * const SeekbarTimeUpdatedArgsUserInfoKey;

extern NSString * const PlaylistEntryChangedNotification;
extern NSString * const PlaylistEntryChangedArgsUserInfoKey;

extern NSString * const PlayerSequencerErrorNotification;
extern NSString * const PlayerSequencerErrorArgsUserInfoKey;

extern NSString * const PlayerSequencerReadyNotification;
