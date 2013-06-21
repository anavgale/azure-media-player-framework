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

#import <AVFoundation/AVFoundation.h>
#import "SequencerAVPlayerFramework_Internal.h"
#import "Sequencer.h"
#import "Scheduler.h"
#import "AdResolver.h"
#import "VASTParser.h"
#import "VMAPParser.h"
#import "SeekbarTime.h"
#import "PlaybackSegment_Internal.h"
#import "AVPlayerLayerView.h"
#import "Creative.h"
#import "MediaFile.h"
#import "AdBreak.h"
#import "TrackingEvent.h"
#import "VMAPExtension.h"
#import "AdSource.h"

#define SEEKBAR_TIMER_INTERVAL 0.2
#define TIMER_INTERVALS_PER_NOTIFICATION 5
#define NUM_OF_VIEWS 3
#define JAVASCRIPT_LOADING_POLLING_INTERVAL 0.05
#define LIVE_POSITION_ERROR_MARGIN_IN_SEC 0.1

NSString * const FrameworkErrorDomain = @"PLAYER_FRAMEWORK";
NSString * const FrameworkUnexpectedError = @"PLAYER_FRAMEWORK:UnexpectedError";

NSString * const SeekbarTimeUpdatedNotification = @"SeekbarTimeUpdatedNotification";
NSString * const SeekbarTimeUpdatedArgsUserInfoKey = @"SeekbarTimeUpdatedArgs";

NSString * const PlaylistEntryChangedNotification = @"PlaylistEntryChangedNotification";
NSString * const PlaylistEntryChangedArgsUserInfoKey = @"PlaylistEntryChangedArgs";

NSString * const PlayerSequencerErrorNotification = @"PlayerSequencerErrorNotification";
NSString * const PlayerSequencerErrorArgsUserInfoKey = @"PlayerSequencerErrorArgs";

NSString * const PlayerSequencerReadyNotification = @"PlayerSequencerReadyNotification";

@implementation SeekbarTimeUpdatedEventArgs

#pragma mark -
#pragma mark Properties:

@synthesize seekbarTime;

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    [seekbarTime release];
    
    [super dealloc];
}

@end

@implementation PlaylistEntryChangedEventArgs

#pragma mark -
#pragma mark Properties:

@synthesize currentEntry;
@synthesize nextEntry;
@synthesize currentPlaybackTime;

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    [currentEntry release];
    [nextEntry release];
    
    [super dealloc];
}

@end

@implementation SequencerAVPlayerFramework

NSString *kStatusKey = @"status";

#pragma mark -
#pragma mark Properties:

@synthesize player;
@synthesize rate;
@synthesize lastError;
@synthesize appDelegate;

#pragma mark -
#pragma mark Private instance methods:

- (void) unregisterPlayer:(AVPlayer *) aPlayer
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:AVPlayerItemDidPlayToEndTimeNotification
                                                  object:aPlayer.currentItem];

    [aPlayer.currentItem removeObserver:self forKeyPath:kStatusKey context:nil];
}

- (void) sendPlaylistEntryChangedNotificationForCurrentEntry:(PlaylistEntry *)currentEntry nextEntry:(PlaylistEntry *)nextEntry atTime:(NSTimeInterval)currentTime
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    PlaylistEntryChangedEventArgs *eventArgs = [[PlaylistEntryChangedEventArgs alloc] init];
    eventArgs.currentEntry = currentEntry;
    eventArgs.nextEntry = nextEntry;
    eventArgs.currentPlaybackTime = currentTime;
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:eventArgs forKey:PlaylistEntryChangedArgsUserInfoKey];
    
    [eventArgs release];
    
    NSNotification *notification = [NSNotification notificationWithName:PlaylistEntryChangedNotification object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
    
    [userInfo release];
    
    [pool release];
}

- (void) sendErrorNotification
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:self.lastError forKey:PlayerSequencerErrorArgsUserInfoKey];
    
    NSNotification *notification = [NSNotification notificationWithName:PlayerSequencerErrorNotification object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
    
    [userInfo release];
    
    [pool release];
}

- (void) sendReadyNotification
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
        
    NSNotification *notification = [NSNotification notificationWithName:PlayerSequencerReadyNotification object:self userInfo:nil];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];

    [pool release];
}

- (void) setNULLSequencerSchedulerError
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:@"PLAYER_SEQUENCER:UnexpectedError" forKey:NSLocalizedDescriptionKey];
    [userInfo setObject:@"Sequencer or scheduler does not exist" forKey:NSLocalizedFailureReasonErrorKey];
    self.lastError = [NSError errorWithDomain:@"PLAYER_SEQUENCER" code:0 userInfo:userInfo];
    [userInfo release];
    
    [pool release];
}


- (void) reset:(AVPlayer *)moviePlayer
{    
    [self unregisterPlayer:moviePlayer];
    
    if (seekbarTimer)
    {
        [seekbarTimer invalidate];
        [seekbarTimer release];
        seekbarTimer = nil;
    }
    
    if (loadingTimer)
    {
        if (loadingTimer.isValid)
        {
            [loadingTimer invalidate];
        }
        [loadingTimer release];
        loadingTimer = nil;
    }
    
    self.currentSegment = nil;
    self.nextSegment = nil;
    
    for (AVPlayerLayerView *playerLayerView in avPlayerViews)
    {
        playerLayerView.player = nil;
        playerLayerView.status = ViewStatus_Idle;
    }
    self.player = nil;
}

- (BOOL) getAdInfos:(NSMutableArray **)adInfos fromVASTEntry:(int32_t)vastEntryId
{
    BOOL success = NO;
    AdInfo *adBuffetAd = nil;
    
    do
    {
        if (nil == sequencer || nil == sequencer.scheduler || nil == sequencer.adResolver)
        {
            [self setNULLSequencerSchedulerError];
            break;
        }

        NSMutableArray *adList = nil;
        success = [self.adResolver.vastParser getAdList:&adList withEntryId:vastEntryId];
        if (!success)
        {
            FRAMEWORK_LOG(@"Failed to retrieve the Ad list from the VAST manifest");
            self.lastError = self.adResolver.vastParser.lastError;
            break;
        }
        
        *adInfos = [[NSMutableArray alloc] initWithCapacity:[adList count]];
        adBuffetAd = nil;
        
        for (int32_t adIndex = 0; adIndex < [adList count]; ++adIndex)
        {
            Ad *ad = [adList objectAtIndex:adIndex];
            NSMutableArray *creativesList = nil;
            NSMutableArray *mediaFileList = nil;
            switch (ad.type)
            {
                case InLine:
                    if (![self.adResolver.vastParser getCreativeList:&creativesList withEntryId:vastEntryId adOrdinal:adIndex adType:ad.type])
                    {
                        FRAMEWORK_LOG(@"Failed to retrieve the creative list for ad %d", adIndex);
                        self.lastError = self.adResolver.vastParser.lastError;
                        [self sendErrorNotification];
                        continue;
                    }
                    
                    for (int32_t creativeIndex = 0; creativeIndex < [creativesList count]; ++creativeIndex)
                    {
                        // Only deal with Linear Creative
                        Creative *creative = [creativesList objectAtIndex:creativeIndex];
                        if (Linear == creative.type)
                        {
                            if (![self.adResolver.vastParser getMediaFileList:&mediaFileList withEntryId:vastEntryId adOrdinal:adIndex creativeOrdinal:creativeIndex])
                            {
                                FRAMEWORK_LOG(@"Failed to retrieve the media file list for ad %d and creative %d", adIndex, creativeIndex);
                                self.lastError = self.adResolver.vastParser.lastError;
                                [self sendErrorNotification];
                                continue;
                            }
                        }
                        if (0 == creative.duration)
                        {
                            FRAMEWORK_LOG(@"VAST Linear creative without Duration element! Ad %d Creative %d", adIndex, creativeIndex);
                            self.lastError = self.adResolver.vastParser.lastError;
                            [self sendErrorNotification];
                            continue;
                        }
                        
                        // Ask the delegate for media file selection
                        MediaFile *mediaFile = nil;
                        if (nil != appDelegate && [appDelegate respondsToSelector:@selector(selectMediaFile:)])
                        {
                            mediaFile = [appDelegate selectMediaFile:mediaFileList];
                        }
                        
                        // If there is no delegate or the delegate didn't make a selection, the default selection is the first ad
                        if (nil == mediaFile)
                        {
                            mediaFile = [mediaFileList objectAtIndex:0];
                        }
                        
                        AdInfo *adInfo = [[AdInfo alloc] init];
                        adInfo.clipURL = [NSURL URLWithString:mediaFile.uriString];
                        adInfo.mediaTime = [[[MediaTime alloc] init] autorelease];
                        adInfo.mediaTime.clipBeginMediaTime = 0;
                        adInfo.mediaTime.clipEndMediaTime = creative.duration;
                        adInfo.appendTo = ad.sequence;
                        
                        if (-1 == ad.sequence)
                        {
                            // This is a buffet ad
                            if (nil == adBuffetAd)
                            {
                                adBuffetAd = [adInfo retain];
                            }
                        }
                        else
                        {
                            // This ad belongs to an ad pod
                            [*adInfos addObject:adInfo];
                        }
                        
                        [adInfo release];
                    }
                    
                    break;
                    
                case Wrapper:
                    FRAMEWORK_LOG(@"VAST Wrapper manifest is not implemented!");
                    break;
                    
                default:
                    FRAMEWORK_LOG(@"Unrecognized VAST manifest type:%u ", ad.type);
                    break;
            }
        }
        
        if (0 == [*adInfos count])
        {
            if (nil != adBuffetAd)
            {
                [*adInfos addObject:adBuffetAd];
                [adBuffetAd release];
            }
        }
        
        if (0 == [*adInfos count])
        {
            [self setNULLSequencerSchedulerError];
            break;
        }

        success = YES;
    }
    while (NO);
    
    return success;
}

- (BOOL) getAdInfos:(NSMutableArray **)adInfos fromVAST:(NSString *)vastManifest
{
    BOOL success = NO;
    
    do
    {
        if (nil == sequencer || nil == sequencer.scheduler || nil == sequencer.adResolver)
        {
            [self setNULLSequencerSchedulerError];
            break;
        }
        
        int32_t vastEntryId = 0;
        success = [self.adResolver.vastParser createEntry:&vastEntryId withManifest:vastManifest];
        if (!success)
        {
            FRAMEWORK_LOG(@"Failed to create the VAST entry");
            self.lastError = self.adResolver.vastParser.lastError;
            break;
        }
        
        success = [self getAdInfos:adInfos fromVASTEntry:vastEntryId];
        if (!success)
        {
            FRAMEWORK_LOG(@"Failed to get the ad info from the VAST entry");
        }
                
        // Ignore error when release the entry
        [self.adResolver releaseEntry:vastEntryId];        
    }
    while (NO);
        
    return success;    
}

- (BOOL) scheduleAds:(NSMutableArray *)adInfos withTotalDuration:(NSTimeInterval)totalDuration atTime:(LinearTime *)linearTime basedOnAd:(AdInfo *)baseAd andGetClipId:(int32_t *)clipId
{
    BOOL success = NO;
    
    do
    {
        NSArray *sortedArray = [adInfos sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
            AdInfo *firstAd = (AdInfo *)a;
            AdInfo *secondAd = (AdInfo *)b;
            if (firstAd.appendTo < secondAd.appendTo)
            {
                return NSOrderedAscending;
            }
            else if (firstAd.appendTo > secondAd.appendTo)
            {
                return NSOrderedDescending;
            }
            else
            {
                return NSOrderedSame;
            }
        }];
        
        int32_t entryId;
        AdInfo *ad = nil;
        LinearTime *adLinearTime = [[[LinearTime alloc] init] autorelease];
        adLinearTime.startTime = linearTime.startTime;
        NSTimeInterval totalLinearDuration = linearTime.duration;

        // Schedule all the ads in the pod
        for (int32_t adIndex = 0; adIndex < [sortedArray count] && 0 < totalDuration; ++adIndex)
        {
            ad = (AdInfo *)[sortedArray objectAtIndex:adIndex];
            NSTimeInterval adDuration = ad.mediaTime.clipEndMediaTime - ad.mediaTime.clipBeginMediaTime;
            
            if (totalDuration < adDuration)
            {
                ad.mediaTime.clipEndMediaTime = ad.mediaTime.clipBeginMediaTime + totalDuration;
                adDuration = totalDuration;
            }
            
            totalDuration -= adDuration;
            
            if (linearTime.duration > 0 && adDuration > totalLinearDuration)
            {
                adDuration -= (adDuration - totalLinearDuration);
                totalDuration = 0;
            }
            if (linearTime.duration > 0)
            {
                adLinearTime.duration = adDuration;
            }
            
            if (0 == adIndex)
            {
                ad.type = baseAd.type;
                ad.appendTo = baseAd.appendTo;                
            }
            else
            {
                ad.type = AdType_Pod;
                ad.appendTo = entryId;
            }
            
            ad.policy = baseAd.policy;
            ad.deleteAfterPlayed = baseAd.deleteAfterPlayed;
            
            success = [sequencer.scheduler scheduleClip:ad atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&entryId];
            if (!success)
            {
                self.lastError = sequencer.scheduler.lastError;
                break;
            }
            
            adLinearTime.startTime += adDuration;
            
            if (nil != clipId && 0 == adIndex)
            {
                *clipId = entryId;
            }
        }
    }
    while (NO);
    
    return success;
}
 
- (void) updateLiveInfo
{
    if (!isLive)
    {
        return;
    }
    
    AVPlayer *avPlayer = self.player;
    if (currentSegment != nil && currentSegment.clip.isAdvertisement)
    {
        avPlayer = livePlayer;
    }
    else
    {
        livePlayer = self.player;
    }

    if (nil != avPlayer)
    {
        AVPlayerItem *currentItem = avPlayer.currentItem;
        NSArray *loadedRanges = currentItem.seekableTimeRanges;
        if (loadedRanges.count > 0)
        {
            CMTimeRange range = [[loadedRanges objectAtIndex:0] CMTimeRangeValue];
            leftDvrEdge = CMTimeGetSeconds(range.start);
            livePosition = leftDvrEdge + CMTimeGetSeconds(range.duration);
        }
    }
    
    NSTimeInterval timeNow = [self getCurrentTimeInSeconds];
    
    if (!hasStarted && currentSegment != nil && !currentSegment.clip.isAdvertisement)
    {
        // This is the first call the updateLive Info
        // We will remember the delta between the system time and the live position
        livePositionDelta = livePosition - timeNow;
    }
    else
    {
        NSTimeInterval calculatedLivePosition = livePositionDelta + timeNow;
        if (fabs(calculatedLivePosition - livePosition) >= LIVE_POSITION_ERROR_MARGIN_IN_SEC)
        {
            // There could be a discontinuity in the playback session (such as stop the player)
            // Or it could be just live position is not updated yet. In any case the calculated time
            // is more accurate
            leftDvrEdge += calculatedLivePosition - livePosition;
            livePosition = calculatedLivePosition;
        }
        else
        {
            // The live position from AVPlayer is accurate
            // We should update the live position delta to avoid clock drift
            livePositionDelta = livePosition - timeNow;
        }
    }
}

- (NSTimeInterval) getCurrentTimeInSeconds
{
    // returns the time interval between now and Jan 1, 2001, GMT.
    return [NSDate timeIntervalSinceReferenceDate];
}

- (BOOL) getHLSContentDuration:(NSTimeInterval *)duration andIsLiveStream:(BOOL *)isLiveStream fromURL:(NSURL *)clipURL
{
    NSMutableString *manifest = nil;
    BOOL success = NO;
    *duration = 0;
    *isLiveStream = NO;

    do
    {
        if (![self.adResolver downloadManifest:&manifest withURL:clipURL])
        {
            self.lastError = self.adResolver.lastError;
            break;
        }
        
        manifest = [NSMutableString stringWithString:[manifest stringByTrimmingCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@"\r\n "]]];
        NSArray *components = [manifest componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \r\n/"]];
        if (0 == components.count || ![[components objectAtIndex:0] isEqualToString:@"#EXTM3U"])
        {
            NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
            [userInfo setObject:FrameworkUnexpectedError forKey:NSLocalizedDescriptionKey];
            [userInfo setObject:@"The manifest is not a valid m3u8 playlist" forKey:NSLocalizedFailureReasonErrorKey];
            self.lastError = [NSError errorWithDomain:FrameworkErrorDomain code:0 userInfo:userInfo];
            [userInfo release];
            break;
        }
        
        NSString *qualityLevels = nil;
        for (NSString *element in components)
        {
            NSRange range = [element rangeOfString:@"QualityLevels("];
            if (range.location == 0 && range.length == 14)
            {
                qualityLevels = element;
                break;
            }
        }
        
        if (nil != qualityLevels)
        {
            // This is a top level playlist, we need to download the individual playlist
            NSString *lastComponent = [clipURL lastPathComponent];
            NSURL *playlistURL = [[[clipURL URLByDeletingLastPathComponent] URLByAppendingPathComponent:qualityLevels] URLByAppendingPathComponent:lastComponent];
            if (![self.adResolver downloadManifest:&manifest withURL:playlistURL])
            {
                self.lastError = self.adResolver.lastError;
                break;
            }
            
            components = [manifest componentsSeparatedByCharactersInSet:[NSCharacterSet characterSetWithCharactersInString:@" \r\n/"]];
        }

        // Adding all the durations of the segments in the playlist
        // which has the form #EXTINF:<duration>
        *isLiveStream = YES;
        for (NSString *element in components)
        {
            NSRange range = [element rangeOfString:@"#EXTINF:"];
            if (range.location != NSNotFound && range.length == 8)
            {
                NSTimeInterval segmentDuration = 0;
                if ([[NSScanner scannerWithString:[element substringFromIndex:8]] scanDouble:&segmentDuration])
                {
                    *duration += segmentDuration;
                }
            }
            else
            {
                range = [element rangeOfString:@"EXT-X-ENDLIST"];
                if (range.location != NSNotFound && range.length == 13)
                {
                    *isLiveStream = NO;
                }
            }
        }
        
        success = YES;
    } while (NO);
    
    return success;
}


#pragma mark -
#pragma mark Instance methods:

//
// Constructor for the framework
//
// Arguments:
// [videoView]    UIView for the video playback.
//
// Returns: The framework instance.
//
- (id) initWithView:(UIView *)videoView
{
    if (self = [super init])
    {
        self.currentSegment = nil;
        self.nextSegment = nil;
        self.avPlayerViews = [NSMutableArray arrayWithCapacity:NUM_OF_VIEWS];
        rate = 1.0;
        
        for (int i = 0; i < NUM_OF_VIEWS; ++i)
        {
            AVPlayerLayerView *playerLayerView = [[AVPlayerLayerView alloc] initWithFrame:videoView.bounds];
            [videoView addSubview:playerLayerView];
            
            playerLayerView.playerLayer.hidden = YES;
            playerLayerView.player = nil;
            playerLayerView.status = ViewStatus_Idle;
            
            [avPlayerViews addObject:playerLayerView];
            
            [playerLayerView release];
        }
        
        AVPlayerLayerView *avPlayerView = [avPlayerViews objectAtIndex:0];
        avPlayerView.playerLayer.hidden = NO;
        
        // Create the sequencer chain and get the head of the chain
        sequencer = [[Sequencer alloc] init];

        isStopped = YES;
        resetView = NO;
        isLive = NO;
        hasStarted = NO;
        hasStartedAfterStop = NO;
        isSeekingAVPlayer = NO;
        initialPlaybackPosition = 0;
        livePlayer = nil;
        loadingTimer = [[NSTimer scheduledTimerWithTimeInterval:JAVASCRIPT_LOADING_POLLING_INTERVAL target:self selector:@selector(loadTimer:) userInfo:NULL repeats:NO] retain];
    }
    
    return self;
}

//
// play the contents in the playlist using the framework.
//
// Arguments: none
//
// Returns: YES for success and NO for failure.
//
- (BOOL) play
{
    BOOL success = NO;
    
    do {
        if (nil == currentSegment)
        {
            // This is the first play
            seekbarTimer = [[NSTimer scheduledTimerWithTimeInterval:SEEKBAR_TIMER_INTERVAL target:self selector:@selector(timer:) userInfo:NULL repeats:YES] retain];
            timerCount = 0;
            
            // Set the seek to start entry
            if (![sequencer.scheduler setSeekToStart])
            {
                self.lastError = sequencer.scheduler.lastError;
                break;
            }
            
            // Seek to 0 to trigger any preroll ad
            // Check for SeekToStart segment
            self.nextSegment = nil;
            if ([sequencer getSegmentAfterSeek:&nextSegment withLinearPosition:0] && nil != nextSegment)
            {                
                if (![self checkSeekToStart])
                {
                    break;
                }

                if (PlaylistEntryType_VAST == nextSegment.clip.type)
                {
                    if (![self getSegmentFromVASTSegment:&nextSegment whileBuffering:NO])
                    {
                        break;
                    }
                }
                
                // Need to check SeekToStart again since the VAST ad could be an invalid preroll ad
                // and the last call would result in skipping to the next segment
                if (![self checkSeekToStart])
                {
                    break;
                }

                rate = nextSegment.initialPlaybackRate;
                
                nextSegment.viewIndex = 0;
                nextSegment.status = PlayerStatus_Stopped;
                AVPlayerLayerView *playerLayerView = (AVPlayerLayerView *)[avPlayerViews objectAtIndex:0];
                playerLayerView.status = ViewStatus_Idle;
                
                NSString *nextURL = [nextSegment.clip.clipURI absoluteString];
                [self playMovie:nextURL];
            }
            else
            {
                self.lastError = sequencer.lastError;
                break;
            }
        }
        else
        {
            // This is a play after pause
            [self.player play];
        }
        
        isStopped = NO;
        success = YES;
    } while (NO);
    
    return success;
}

//
// play the contents in the playlist using the framework.
//
// Arguments:
// [linearTime]    The position to start the playback at the linear timeline.
//
// Returns: YES for success and NO for failure.
//
- (BOOL) playAtTime:(NSTimeInterval)linearTime
{    
    initialPlaybackPosition = linearTime;
    
    return [self play];    
}

//
// pause the framework
//
// Arguments: none
//
// Returns: none
//
- (void) pause
{
    if (nil != self.player && !isStopped)
    {
        [self.player pause];
    }
}

//
// stop the framework
//
// Arguments: none
//
// Returns: YES for success and NO for failure
//
- (BOOL) stop
{
    BOOL success = YES;
    
    if (!isStopped)
    {
        isStopped = YES;
        hasStartedAfterStop = NO;
        initialPlaybackPosition = 0;
        livePlayer = nil;
        resetView = NO;
        PlaybackSegment *segmentToRemove = nil;
        if (PlayerStatus_Playing != currentSegment.status)
        {
            segmentToRemove = nextSegment;
        }
        else
        {
            segmentToRemove = currentSegment;
        }
        AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:segmentToRemove.viewIndex];
        AVPlayer *moviePlayer = playerLayerView.player;
        
        // call onEndOfMedia to release the segment from the segment list
        PlaybackSegment *segment = nil;
        success = [sequencer getSegmentOnEndOfMedia:&segment withCurrentSegment:segmentToRemove mediaTime:currentSegment.clip.mediaTime.clipEndMediaTime currentPlaybackRate:1.0 isNotPlayed:YES isEndOfSequence:YES];
        [segment release];
        
        if (!success)
        {
            self.lastError = sequencer.lastError;
        }
        
        [self reset:moviePlayer];
    }
    
    return success;
}

//
// seek to a specific time in the linear timeline
//
// Arguments:
// [seekTime]: the time to seek to
//
// Returns: YES for success and NO for failure
//
- (BOOL) seekToTime:(NSTimeInterval)seekTime
{
    BOOL success = NO;
    SeekbarTime *seekbarPosition = nil;
    
    do {
        if (!isStopped)
        {
            // save the originalId
            int32_t currentId = currentSegment.clip.originalId;
            
            // do the actual seek
            PlaybackSegment *segment = nil;
            seekbarPosition = [[SeekbarTime alloc] init];
            seekbarPosition.currentSeekbarPosition = seekTime;
            if ([sequencer getSegmentAfterSeek:&segment withSeekbarPosition:seekbarPosition currentSegment:currentSegment] && nil != segment)
            {
                if (segment.clip.originalId == currentId)
                {
                    // Seek is within the same entry.
                    // Update the segment info and do the seek in the current player
                    segment.status = PlayerStatus_Waiting;
                    segment.viewIndex = currentSegment.viewIndex;
                    self.currentSegment = segment;
                    [self.player seekToTime:CMTimeMakeWithSeconds(segment.initialPlaybackTime, NSEC_PER_SEC) completionHandler:^(BOOL finished) {
                        if (finished)
                        {
                            self.currentSegment.status = PlayerStatus_Playing;
                        }
                        else
                        {
                            FRAMEWORK_LOG(@"There is an error when seeking into seekTime %f", seekTime);
                        }
                    }
                     ];
                    
                    // Seek should invalidate any buffering of the next content since the content may change
                    nextSegment = nil;
                }
                else
                {
                    // Seek is into another entry
                    // We need to load and play another content in a separate player
                    if (PlaylistEntryType_VAST == segment.clip.type)
                    {
                        success = [self getSegmentFromVASTSegment:&segment whileBuffering:NO];
                        if (!success)
                        {
                            break;
                        }
                    }
                    segment.status = PlayerStatus_Stopped;
                    // always reset the current view unless it is live content transition from main to ad.
                    resetView = !(isLive && !(currentSegment.clip.isAdvertisement) && segment.clip.isAdvertisement);
                    self.nextSegment = segment;
                    if (![self contentFinished:YES])
                    {
                        break;
                    }
                    
                    if(nil == currentSegment || PlayerStatus_Playing != currentSegment.status)
                    {
                        // The playback hasn't started yet
                        // Start it if possible
                        [self playMovie:[nextSegment.clip.clipURI absoluteString]];
                    }
                }
                
                [segment release];
            }
            else
            {
                self.lastError = sequencer.lastError;
                break;
            }
        }
        success = YES;
    } while (NO);

    [seekbarPosition release];

    return success;
}

//
// end the current playlist entry and skip to the next entry
//
// Arguments: none
//
// Returns: YES for success and NO for failure.
//
- (BOOL) skipCurrentPlaylistEntry
{
    return [self contentFinished:NO];
}

//
// schedule an ad clip in the framework
//
// Arguments:
// [ad]: The ad clip to be scheduled
// [linearTime]: The time when the ad should be played in the linear timeline. Note that this is an upper bound if content duration is not specified.
// [type]: The type of the ad
// [clipId]: The output clipId for the scheduled clip
//
// Returns: YES for success and NO for failure
//
- (BOOL) scheduleClip:(AdInfo *)ad atTime:(LinearTime *)linearTime forType:(PlaylistEntryType)type andGetClipId:(int32_t *)clipId
{
    BOOL success = NO;
    
    if (nil == sequencer || nil == sequencer.scheduler)
    {
        [self setNULLSequencerSchedulerError];
    }
    else
    {        
        do
        {
            if (ad.mediaTime.clipEndMediaTime < 0)
            {
                // The duration of the content is unknown. Need to download the playlist to figure out duration.
                NSTimeInterval duration = 0;
                BOOL isLiveStream = NO;
                
                if (![self getHLSContentDuration:&duration andIsLiveStream:&isLiveStream fromURL:ad.clipURL])
                {
                    break;
                }
                
                if (isLiveStream)
                {
                    // Live stream can't be used as an ad clip
                    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
                    [userInfo setObject:FrameworkUnexpectedError forKey:NSLocalizedDescriptionKey];
                    [userInfo setObject:@"Live stream cannot be used as a clip source" forKey:NSLocalizedFailureReasonErrorKey];
                    self.lastError = [NSError errorWithDomain:FrameworkErrorDomain code:0 userInfo:userInfo];
                    [userInfo release];
                    break;
                }
                
                ad.mediaTime.clipEndMediaTime = duration;
                
                if (0 != linearTime.duration)
                {
                    NSTimeInterval contentDuration = ad.mediaTime.clipEndMediaTime - ad.mediaTime.clipBeginMediaTime;
                    if (contentDuration < linearTime.duration)
                    {
                        // The app specified linear duration is too long for the clip
                        // correct the linear duration
                        linearTime.duration = contentDuration;                        
                    }
                    else
                    {
                        // The content length exceeds the linear duration specified by the app. Clip the content.
                        ad.mediaTime.clipEndMediaTime = ad.mediaTime.clipBeginMediaTime + linearTime.duration;
                    }
                }
            }
            
            success = [sequencer.scheduler scheduleClip:ad atTime:linearTime forType:type andGetClipId:clipId];
            if (!success)
            {
                self.lastError = sequencer.scheduler.lastError;
            }
        } while (NO);
    }
    
    return success;
}

//
// schedule ad or ad pod based on the VAST manifest provided
//
// Arguments:
// [ad] The ad clip to be scheduled (with URL and media time missing and to be filled from the VAST manifest)
// [vastManifest]: The VAST manifest
// [linearTime]: The time when the ad should be played in the linear timeline
// [clipId]: The output clipId for the scheduled clip. In case of an ad pod, this is the entryId for the first clip.
//
// Returns: YES for success and NO for failure
//
- (BOOL) scheduleVASTClip:(AdInfo *)ad withManifest:(NSString *)vastManifest atTime:(LinearTime *)linearTime andGetClipId:(int32_t *)clipId
{
    BOOL success = NO;
    NSMutableArray *adPodArray = nil;
    
    do
    {
        if (nil == sequencer || nil == sequencer.scheduler || nil == sequencer.adResolver)
        {
            [self setNULLSequencerSchedulerError];
            break;
        }
        
        success = [self getAdInfos:&adPodArray fromVAST:vastManifest];
        if (!success)
        {
            FRAMEWORK_LOG(@"Failed to get ad list from the VAST manifest");
            break;
        }

        NSTimeInterval totalDuration = 0;
        for (AdInfo *ad in adPodArray)
        {
            totalDuration += (ad.mediaTime.clipEndMediaTime - ad.mediaTime.clipBeginMediaTime);
        }
        success = [self scheduleAds:adPodArray withTotalDuration:totalDuration atTime:linearTime basedOnAd:ad andGetClipId:clipId];
        if (!success)
        {
            FRAMEWORK_LOG(@"Failed to schedule the ad list from the VAST manifest");
            break;
        }

        success = YES;
    }
    while (NO);

    [adPodArray removeAllObjects];
    [adPodArray release];

    return success;
}

//
// schedule ad list based on VMAP manifest
//
// Arguments:
// [vmapManifest]: The VMAP manifest
//
// Returns: YES for success and NO for failure
//
- (BOOL) scheduleVMAPWithManifest:(NSString *)vmapManifest
{
    BOOL success = NO;
    
    do
    {
        if (nil == sequencer || nil == sequencer.scheduler || nil == sequencer.adResolver)
        {
            [self setNULLSequencerSchedulerError];
            break;
        }
        
        int32_t vmapEntryId = 0;
        success = [self.adResolver.vmapParser createEntry:&vmapEntryId withManifest:vmapManifest];
        if (!success)
        {
            FRAMEWORK_LOG(@"Failed to create the VMAP entry");
            self.lastError = self.adResolver.vmapParser.lastError;
            break;
        }
        
        NSMutableArray *adBreakList = nil;
        success = [self.adResolver.vmapParser getAdBreakList:&adBreakList withEntryId:vmapEntryId];
        if (!success)
        {
            FRAMEWORK_LOG(@"Failed to obtain the ad break list from the VMAP manifest");
            break;
        }
        
        // if any ad scheduling failed we should return failure but should finish scheduling the rest of the ads.
        BOOL hasFailure = NO;
        for (int32_t adBreakId = 0; adBreakId < [adBreakList count]; ++adBreakId)
        {
            AdBreak *adBreak = [adBreakList objectAtIndex:adBreakId];
            
            for (NSString *element in adBreak.elementList)
            {
                if ([element isEqualToString:@"AdSource"])
                {
                    AdSource *adSource = nil;
                    success = [self.adResolver.vmapParser getAdSource:&adSource withEntryId:vmapEntryId adBreakOrdinal:adBreakId];
                    if (!success)
                    {
                        FRAMEWORK_LOG(@"Failed to get the AdSource from the VMAP entry");
                        self.lastError = self.adResolver.vmapParser.lastError;
                        break;
                    }
                    
                    NSString *manifest = nil;
                    NSMutableArray *adPodArray = nil;
                    int32_t vastEntryId = 0;
                    LinearTime *adBreakTime = nil;
                    AdInfo *baseAd = nil;
                    NSTimeInterval totalDuration = 0;
                    switch (adSource.type)
                    {
                        case VASTAdData:
                            success = [self.adResolver.vmapParser createVASTEntryFromAdBreak:&vastEntryId withEntryId:vmapEntryId adBreakOrdinal:adBreakId];
                            if (!success)
                            {
                                FRAMEWORK_LOG(@"Failed to create VAST entry for AdBreak %d", adBreakId);
                                self.lastError = self.adResolver.vmapParser.lastError;
                                break;
                            }
                            
                            success = [self getAdInfos:&adPodArray fromVASTEntry:vastEntryId];
                            if (!success || nil == adPodArray || 0 == [adPodArray count])
                            {
                                FRAMEWORK_LOG(@"Failed to parse the VAST manifest");
                                break;
                            }
                            
                            adBreakTime = [[[LinearTime alloc] init] autorelease];
                            adBreakTime.startTime = adBreak.timeOffset;
                            baseAd = [[[AdInfo alloc] init] autorelease];
                            if (0 == adBreak.timeOffset)
                            {
                                baseAd.type = AdType_Preroll;
                            }
                            else if (adBreak.timeOffset < 0)
                            {
                                baseAd.type = AdType_Postroll;
                            }
                            else
                            {
                                baseAd.type = AdType_Midroll;
                            }
                            totalDuration = 0;
                            for (AdInfo *ad in adPodArray)
                            {
                                totalDuration += (ad.mediaTime.clipEndMediaTime - ad.mediaTime.clipBeginMediaTime);
                            }
                            success = [self scheduleAds:adPodArray withTotalDuration:totalDuration atTime:adBreakTime basedOnAd:baseAd andGetClipId:nil];
                            if (!success)
                            {
                                FRAMEWORK_LOG(@"Failed to schedule the rest of the ad pod specified in the VAST manifest");
                                break;
                            }
                            
                            break;
                            
                        case CustomAdData:
                            FRAMEWORK_LOG(@"AdSource CustomAdData ignored!");
                            break;
                            
                        case AdTagURI:
                            // Download the vast manifest, has to be a blocking call
                            success = [self.adResolver downloadManifest:&manifest withURL:[NSURL URLWithString:adSource.value]];
                            if (!success)
                            {
                                FRAMEWORK_LOG(@"Failed to download the manifest with url:%@", adSource.value);
                                self.lastError = self.adResolver.lastError;
                                break;
                            }
                            
                            success = [self getAdInfos:&adPodArray fromVAST:manifest];
                            if (!success || nil == adPodArray || 0 == [adPodArray count])
                            {
                                FRAMEWORK_LOG(@"Failed to parse the VAST manifest in the adBreak with url %@", adSource.value);
                                break;
                            }
                            
                            adBreakTime = [[[LinearTime alloc] init] autorelease];
                            adBreakTime.startTime = adBreak.timeOffset;
                            baseAd = [[[AdInfo alloc] init] autorelease];
                            if (0 == adBreak.timeOffset)
                            {
                                baseAd.type = AdType_Preroll;
                            }
                            else if (adBreak.timeOffset < 0)
                            {
                                baseAd.type = AdType_Postroll;
                            }
                            else
                            {
                                baseAd.type = AdType_Midroll;
                            }
                            totalDuration = 0;
                            for (AdInfo *ad in adPodArray)
                            {
                                totalDuration += (ad.mediaTime.clipEndMediaTime - ad.mediaTime.clipBeginMediaTime);
                            }
                            success = [self scheduleAds:adPodArray withTotalDuration:totalDuration atTime:adBreakTime basedOnAd:baseAd andGetClipId:nil];
                            if (!success)
                            {
                                FRAMEWORK_LOG(@"Failed to schedule the ad pod specified in the VAST manifest with url %@", adSource.value);
                                break;
                            }
                            
                            break;
                            
                        default:
                            FRAMEWORK_LOG(@"Unexpected AdSource type: %d", adSource.type);
                            break;
                    }
                    
                    if (!success)
                    {
                        hasFailure = YES;
                        [self sendErrorNotification];
                        break;
                    }
                }
                else if ([element isEqualToString:@"TrackingEvents"])
                {
                    // Don't handle tracking event yet
                    // Don't fail even when having error
                    NSMutableArray *trackingEventList = nil;
                    [self.adResolver.vmapParser getTrackingEventsList:&trackingEventList withEntryId:vmapEntryId adBreakOrdinal:adBreakId];
                    
                    FRAMEWORK_LOG(@"Ignoring Tracking events:");
                    for (TrackingEvent *event in trackingEventList)
                    {
                        FRAMEWORK_LOG(@"%@\n", event);
                    }                    
                }
                else if ([element isEqualToString:@"Extensions"])
                {
                    // Don't handle extensions yet
                    // Don't fail even when having error
                    NSMutableArray *extensionList = nil;
                    [self.adResolver.vmapParser getExtensionsList:&extensionList withEntryId:vmapEntryId adBreakOrdinal:adBreakId];
                    
                    FRAMEWORK_LOG(@"Ignoring extensions");
                    for (VMAPExtension *extension in extensionList)
                    {
                        FRAMEWORK_LOG(@"%@\n", extension);
                    }                    
                }
                else
                {
                    FRAMEWORK_LOG(@"Unexpected AdBreak child element in AdBreak %d", adBreakId);
                }
            }            
        }
        
        if (hasFailure)
        {
            success = NO;
        }

        // Ignore error when release the entry
        [self.adResolver releaseEntry:vmapEntryId];
    }
    while (NO);

    return success;
}

//
// cancel a specific ad in the framework
//
// Arguments:
// [clipId] the clipId of the ad to be cancelled
//
// Returns: YES for success and NO for failure
//
- (BOOL) cancelClip:(int32_t)clipId
{
    BOOL success = NO;
    
    if (nil == sequencer || nil == sequencer.scheduler)
    {
        [self setNULLSequencerSchedulerError];
    }
    else
    {
        if (clipId == currentSegment.clip.originalId)
        {
            success = [self skipCurrentPlaylistEntry];
        }
        
        if (success)
        {
            success = [sequencer.scheduler cancelClip:clipId];
            if (!success)
            {
                self.lastError = sequencer.scheduler.lastError;
            }
        }
        else
        {
            self.lastError = sequencer.lastError;
        }
    }
    
    return success;
}

//
// append main content to the playlist in the framework
//
// Arguments:
// [clipURL]: The URL of the clip to be appended
// [mediaTime]: The minimum and maximum rendering time in the media time. Set mediaTime.clipEndMediaTime to negative if the clip duration is unknown.
// [clipId]: The output clipId for the content that is appended
//
// Returns: YES for success and NO for failure
//
- (BOOL) appendContentClip:(NSURL *)clipURL withMediaTime:(MediaTime *)mediaTime andGetClipId:(int32_t *)clipId
{
    BOOL success = NO;
    
    if (nil == sequencer || nil == sequencer.scheduler)
    {
        [self setNULLSequencerSchedulerError];
    }
    else
    {
        do
        {
            if (mediaTime.clipEndMediaTime < 0)
            {
                // The duration of the content is unknown. Need to download the playlist to figure out duration.
                NSTimeInterval duration = 0;
                BOOL isLiveStream = NO;
                
                if (![self getHLSContentDuration:&duration andIsLiveStream:&isLiveStream fromURL:clipURL])
                {
                    break;
                }
                
                isLive = isLiveStream;
                
                if (isLive)
                {
                    mediaTime.clipEndMediaTime = LIVE_END;
                }
                else
                {
                    mediaTime.clipEndMediaTime = duration;
                }
            }
            
            success = [sequencer.scheduler appendContentClip:clipURL withMediaTime:mediaTime andGetClipId:clipId];
            if (!success)
            {
                self.lastError = sequencer.scheduler.lastError;
            }
        } while (NO);
    }
    
    return success;
}

//
// Initialize the moviePlayer instance with a Url to be played.
//
// Arguments:
// [url]    Url to be played by the moviePlayer.
//
// Returns: none.
//
- (void) initPlayer:(NSString *)url
{
    NSURL* theUrl = [NSURL URLWithString:url];
    
    BOOL isAd = nextSegment.clip.isAdvertisement;
    BOOL isPlayingAd = (nil == currentSegment) ? NO : currentSegment.clip.isAdvertisement;
    if (isAd)
    {
        if (nil == currentSegment)
        {
            // This is the first preroll ad. Just initiate the player with content URL
            AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
            playerLayerView.status = ViewStatus_Idle;
            nextSegment.status = PlayerStatus_Waiting;
            playerLayerView.player = [AVPlayer playerWithURL:theUrl];
        }
        else
        {
            // This is either an ad pod or transition from main to ad.
            // We need to start a new ad player.
            // Pick an idle view from the list, but avoid the main view that has been paused
            BOOL foundIdleView = NO;
            for (AVPlayerLayerView *playerLayerView in avPlayerViews)
            {
                if (ViewStatus_Idle == playerLayerView.status)
                {
                    nextSegment.viewIndex = [avPlayerViews indexOfObject:playerLayerView];
                    playerLayerView.player = [AVPlayer playerWithURL:theUrl];
                    
                    if (PlayerStatus_Stopped == nextSegment.status)
                    {
                        nextSegment.status = PlayerStatus_Loading;
                    }
                    else
                    {
                        nextSegment.status = PlayerStatus_Waiting;
                    }
                    
                    foundIdleView = YES;
                    break;
                }
            }
            
            assert(foundIdleView);
        }
    }
    else
    {
        if (isPlayingAd)
        {
            // Switch from ad to main content. All we need to do is to resume.
            // Delay the resumption until the view switches
            // One exception is for preroll ad we need to create the player for the main content
            // Also pauseTimeLine false ad requires a seek
            BOOL foundMainView = NO;
            AVPlayerLayerView *mainView = nil;
            for (AVPlayerLayerView *playerLayerView in avPlayerViews)
            {
                if (ViewStatus_Paused == playerLayerView.status)
                {
                    mainView = playerLayerView;
                    foundMainView = YES;
                    break;
                }
                else if (ViewStatus_Idle == playerLayerView.status)
                {
                    mainView = playerLayerView;
                }
            }
            
            nextSegment.viewIndex = [avPlayerViews indexOfObject:mainView];
            if (!foundMainView)
            {
                // either preroll ad ends, or seeking into a different main clip. In either case
                // we need to create the main player. Note that the player may not be preloaded.
                mainView.status = ViewStatus_Idle;
                mainView.player = [AVPlayer playerWithURL:theUrl];
                if (PlayerStatus_Stopped == nextSegment.status)
                {
                    nextSegment.status = PlayerStatus_Loading;
                }
            }
            else
            {
                // for pause timeline false ad we need to do a seek here
                if (currentSegment.clip.linearTime.duration > 0)
                {
                    AVPlayerLayerView *nextView = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
                    AVPlayer *moviePlayer = nextView.player;

                    NSTimeInterval resumeTime = nextSegment.initialPlaybackTime;
                    CMTime targetTime = CMTimeMakeWithSeconds(resumeTime, NSEC_PER_SEC);
                    [moviePlayer seekToTime:targetTime];
                    isSeekingAVPlayer = YES;
                }
                // otherwise only need to resume the main content and no need to load
                nextSegment.status = PlayerStatus_Ready;
            }
        }
        else
        {
            // This is either the first start of the main content or start of another RCE clip
            if (nil == currentSegment)
            {
                // This is the first playback
                AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
                playerLayerView.player =[AVPlayer playerWithURL:theUrl];
                playerLayerView.status = ViewStatus_Idle;
                nextSegment.status = PlayerStatus_Waiting;
            }
            else
            {
                // This is an RCE. Start another main content.
                // We need to switch between the two players.
                // Pick an idle view from the list
                BOOL foundIdleView = NO;
                for (AVPlayerLayerView *playerLayerView in avPlayerViews)
                {
                    if (ViewStatus_Idle == playerLayerView.status)
                    {
                        nextSegment.viewIndex = [avPlayerViews indexOfObject:playerLayerView];
                        playerLayerView.player = [AVPlayer playerWithURL:theUrl];
                        if (PlayerStatus_Stopped == nextSegment.status)
                        {
                            nextSegment.status = PlayerStatus_Loading;
                        }
                        else
                        {
                            nextSegment.status = PlayerStatus_Waiting;
                        }
                        
                        foundIdleView = YES;
                        break;
                    }
                }
                
                assert(foundIdleView);
            }
        }
    }
}

//
// Playback a Url.
//
// Arguments:
// [url]    Url to be played.
//
// Returns: none.
//
- (void) playMovie:(NSString *)url
{
    NSURL* theUrl = [NSURL URLWithString:url];
    FRAMEWORK_LOG(@"Playing URL: %@", theUrl);
    
    switch (nextSegment.status)
    {
        case PlayerStatus_Stopped:
            nextSegment.status = PlayerStatus_Waiting;
            [self loadMovie:url];
            break;
        case PlayerStatus_Loading:
            nextSegment.status = PlayerStatus_Waiting;
            break;
        case PlayerStatus_Waiting:
            // do nothing and wait for the content to be loaded
            break;
        default:
            break;
    }
    
    // We need this check separated from the switch statement since the status
    // could change to ready when loadMovie is called.
    if (PlayerStatus_Ready == nextSegment.status)
    {
        [self startPlayback];
    }
}

//
// preload a movie from a Url.
//
// Arguments:
// [url]    Url to be played.
//
// Returns: none.
//
- (void) loadMovie:(NSString *)url
{
    NSURL* theUrl = [NSURL URLWithString:url];
    FRAMEWORK_LOG(@"loading URL: %@", theUrl);
    
    [self initPlayer:url];
    
    AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
    AVPlayer *moviePlayer = playerLayerView.player;
    
    /* Observe the player item "status" key to determine when it is ready to play. */
    [moviePlayer.currentItem addObserver:self
                  forKeyPath:kStatusKey
                     options:0
                     context:nil];
}

//
// start playback for the current loaded movie.
//
// Arguments: none.
//
// Returns: none.
//
- (void) startPlayback
{
    FRAMEWORK_LOG(@"start playback");
    
    AVPlayerLayerView *viewToShow = nil;
    AVPlayerLayerView *viewToHide = nil;
    BOOL currentlyPlaying = (nil != currentSegment);
    BOOL shouldPausePlayer = currentlyPlaying ? (!currentSegment.clip.isAdvertisement && nextSegment.clip.isAdvertisement) : NO;
    BOOL playbackShouldStart = (nil == nextSegment.error);
    
    if (resetView)
    {
        shouldPausePlayer = NO;
        resetView = NO;
    }
    
    viewToShow = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
    if (currentlyPlaying)
    {
        viewToHide = [avPlayerViews objectAtIndex:currentSegment.viewIndex];
    }
    
    AVPlayer *moviePlayer = viewToShow.player;
    
    // Register to the play-to-end notifiation for the content to be played.
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(playerItemDidReachEnd:)
                                                 name:AVPlayerItemDidPlayToEndTimeNotification
                                               object:moviePlayer.currentItem];

    // Send the playlist entry changed notification
    [self sendPlaylistEntryChangedNotificationForCurrentEntry:((nil == currentSegment) ? nil : currentSegment.clip) nextEntry:nextSegment.clip atTime:currentPlaylistEntryPosition];
    
    // Update the current segment
    self.currentSegment = nextSegment;
    self.nextSegment = nil;
    self.player = moviePlayer;
    
    if (playbackShouldStart)
    {
        [moviePlayer play];

        FRAMEWORK_LOG(@"Clip change: Start playback for url: %@\n", currentSegment.clip.clipURI);
    }

    // We need to pause or delete the previous player
    // and set the flags appropriately
    if (currentlyPlaying)
    {
        if (shouldPausePlayer)
        {
            // From main content to ad, we just need to pause the main content
            [viewToHide.player pause];            
            viewToHide.status = ViewStatus_Paused;
        }
        else
        {
            viewToHide.player = nil;
            viewToHide.status = ViewStatus_Idle;
        }
    }
    
    // Show the current player view and hide the previous player view
    [self hideView:viewToHide];
    [self showView:viewToShow];

    viewToShow.status = ViewStatus_Active;    
    currentSegment.status = PlayerStatus_Playing;
    
    if (!playbackShouldStart)
    {
        [self contentFinished:NO];
    }
}

//
// Notification callback when the content playback finishes.
//
// Arguments:
// [notification]   An NSNotification object that wraps information of the
//                  playback result.
//
// Returns: none.
//
- (void) playerItemDidReachEnd:(NSNotification *)notification
{
    FRAMEWORK_LOG(@"Inside playback finished notification callback...");
    
    [self contentFinished:NO];
}

/* ---------------------------------------------------------
 **  Called when the value at the specified key path relative
 **  to the given object has changed.
 **  NOTE: this method is invoked on the main queue.
 ** ------------------------------------------------------- */
- (void)observeValueForKeyPath:(NSString*) path
                      ofObject:(id)object
                        change:(NSDictionary*)change
                       context:(void*)context
{
	/* AVPlayer "status" property value observer. */
    AVPlayerLayerView *playerLayerView = (nil != nextSegment) ? [avPlayerViews objectAtIndex:nextSegment.viewIndex] : nil;
    AVPlayer *moviePlayer = (nil != playerLayerView) ? playerLayerView.player : nil;
    AVPlayerItem *nextItem = (nil != moviePlayer) ? moviePlayer.currentItem : nil;
    AVPlayerLayerView *currentPlayerLayerView = (nil != currentSegment) ? [avPlayerViews objectAtIndex:currentSegment.viewIndex] : nil;
    AVPlayer *currentMoviePlayer = (nil != currentPlayerLayerView) ? currentPlayerLayerView.player : nil;
    AVPlayerItem *currentItem = (nil != currentMoviePlayer) ? currentMoviePlayer.currentItem : nil;
    
    if (object == nextItem && [path isEqualToString:kStatusKey]) {
        switch (nextItem.status)
        {
            // Indicates that the status of the player is not yet known because
            // it has not tried to load new media resources for playback 
            case AVPlayerItemStatusUnknown:
                {
                    FRAMEWORK_LOG(@"Status update: AVPlayerItemStatusUnknown");
                }
                break;
                
            case AVPlayerItemStatusReadyToPlay:
                {
                    FRAMEWORK_LOG(@"Status update: AVPlayerItemStatusReadyToPlay");
                    FRAMEWORK_LOG(@"Clip change rebuffering: clip url: %@\n is ready to play", nextSegment.clip.clipURI);

                    // Seek the player to the correct start position
                    AVPlayerLayerView *nextView = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
                    AVPlayer *moviePlayer = nextView.player;
                    
                    NSTimeInterval seconds = nextSegment.initialPlaybackTime;
                    if (0 != seconds)
                    {
                        if (isSeekingAVPlayer)
                        {
                            isSeekingAVPlayer = NO;
                        }
                        else
                        {
                            CMTime targetTime = CMTimeMakeWithSeconds(seconds, NSEC_PER_SEC);
                            [moviePlayer seekToTime:targetTime];
                            isSeekingAVPlayer = YES;
                        }
                    }

                    if (PlayerStatus_Loading == nextSegment.status || PlayerStatus_Ready == nextSegment.status)
                    {
                        // The content is loaded but playback start time is still in the future
                        nextSegment.status = PlayerStatus_Ready;
                    }
                    else
                    {
                        // The content is loaded and playback should start right away
                        [self startPlayback];
                    }
                }
                break;
                
            case AVPlayerItemStatusFailed:
                {
                    FRAMEWORK_LOG(@"Status update: AVPlayerItemStatusFailed");
                    
                    self.lastError = nextItem.error;
                    [self sendErrorNotification];
                    nextSegment.error = (nil != nextItem.error.localizedFailureReason) ? nextItem.error.localizedFailureReason : nextItem.error.localizedDescription;
                    
                    if (PlayerStatus_Waiting == nextSegment.status)
                    {
                        // The failed content is due for playback
                        [self startPlayback];
                    }
                    else
                    {
                        // The failed content failed during preload
                        // we can igore the failure here and wait for the playback time
                        // But we need to set the state back
                        nextSegment.status = PlayerStatus_Ready;
                    }                    
                }
                break;
        }
    }
    else if (object == currentItem && [path isEqualToString:kStatusKey]) {
        switch (currentItem.status)
        {
                // Indicates that the status of the player is not yet known because
                // it has not tried to load new media resources for playback
            case AVPlayerItemStatusUnknown:
                {
                    FRAMEWORK_LOG(@"Status update: AVPlayerItemStatusUnknown");
                }
                break;
                
            case AVPlayerItemStatusReadyToPlay:
                {
                    // This can happen during a seek where the seek finishes after startPlayback is called
                    FRAMEWORK_LOG(@"Status update: AVPlayerItemStatusReadyToPlay");
                    FRAMEWORK_LOG(@"Clip change rebuffering: clip url: %@\n is ready to play", currentSegment.clip.clipURI);
                    if (isSeekingAVPlayer)
                    {
                        isSeekingAVPlayer = NO;
                    }
                }
                break;
                
            case AVPlayerItemStatusFailed:
                {
                    FRAMEWORK_LOG(@"Status update: AVPlayerItemStatusFailed");

                    self.lastError = currentItem.error;
                    [self sendErrorNotification];
                    currentSegment.error = (nil != currentItem.error.localizedFailureReason) ? currentItem.error.localizedFailureReason : currentItem.error.localizedDescription;
                    [self contentFinished:NO];
                    
                }
                break;
        }
    }
    
    return;
}

//
// Indicates the current content finished playback.
//
// Arguments:
// [isSeeking]: if the playback ends as a result of seeking
//
// Returns: YES for success and NO for failure
//
- (BOOL) contentFinished:(BOOL)isSeeking
{
    NSString *nextURL = nil;
    AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:currentSegment.viewIndex];
    AVPlayer *moviePlayer = playerLayerView.player;
    CMTime cmCurrTime = moviePlayer.currentTime;
    BOOL success = NO;
    currentPlaylistEntryPosition = (0 != cmCurrTime.timescale) ? (double)cmCurrTime.value / cmCurrTime.timescale : 0;
    
    if (PlayerStatus_Playing != currentSegment.status)
    {
        // There are cases that contentFinished could be called multiple times. For example when an error happens normally
        // we get the error from the KVO binding. But occasionally we could also get a playbackItemFinished notifcaiton which
        // triggers another call to contentFinished. In that case we need to ignore the redundant calls.
        return YES;
    }
    
    do {
        if (!isSeeking)
        {
            PlaybackSegment *segment = nil;
            if (nil != currentSegment.error)
            {
                success = [sequencer getSegmentOnError:&segment withCurrentSegment:currentSegment mediaTime:currentPlaylistEntryPosition currentPlaybackRate:rate error:currentSegment.error isNotPlayed:NO isEndOfSequence:NO];
            }
            else
            {
                success = [sequencer getSegmentOnEndOfMedia:&segment withCurrentSegment:currentSegment mediaTime:currentPlaylistEntryPosition currentPlaybackRate:rate isNotPlayed:NO isEndOfSequence:NO];
            }
            if (!success)
            {
                self.lastError = sequencer.lastError;
                break;
            }
            if (nil == nextSegment ||
                (nextSegment.clip.entryId != segment.clip.entryId && PlaylistEntryType_VAST != segment.clip.type))
            {
                // Before releasing the preloaded segment
                // we need to make sure that we remove observations and clear the state
                if (nil != nextSegment && PlayerStatus_Stopped != nextSegment.status)
                {
                    AVPlayerLayerView *nextPlayerLayerView = [avPlayerViews objectAtIndex:nextSegment.viewIndex];
                    AVPlayer *nextPlayer = nextPlayerLayerView.player;
                    [self unregisterPlayer:nextPlayer];
                    nextSegment.status = PlayerStatus_Stopped;
                }
                
                if (PlaylistEntryType_VAST == segment.clip.type)
                {
                    success = [self getSegmentFromVASTSegment:&segment whileBuffering:NO];
                    if (!success)
                    {
                        break;
                    }
                }
                self.nextSegment = segment;
            }
            [segment release];
           
            success = [self checkSeekToStart];
            if (!success)
            {
                break;
            }
        }
        
        if (nil != nextSegment)
        {            
            rate = nextSegment.initialPlaybackRate;
            
            nextURL = [nextSegment.clip.clipURI absoluteString];
        }
        
        if (nil == nextURL)
        {
            FRAMEWORK_LOG(@"Playback ended");
            
            [self sendPlaylistEntryChangedNotificationForCurrentEntry:currentSegment.clip nextEntry:nil atTime:currentPlaylistEntryPosition];
            [self reset:moviePlayer];
            isStopped = YES;
        }
        else
        {
            [self unregisterPlayer:moviePlayer];
            currentSegment.status = PlayerStatus_Stopped;
            [self playMovie:nextURL];
        }
        
        success = YES;
    } while (NO);
    
    return success;
}

//
// Indicates the current content finished downloading so that we can start to load the next content.
//
// Arguments: none
//
// Returns: none
//
- (void) preloadContent
{
    NSString *nextURL = nil;
    PlaybackSegment *segment = nil;
    AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:currentSegment.viewIndex];
    AVPlayer *moviePlayer = playerLayerView.player;
    
    CMTime cmCurrTime = moviePlayer.currentTime;
    NSTimeInterval currTime = (double)cmCurrTime.value / cmCurrTime.timescale;
    
    do
    {
        if (![sequencer getSegmentOnEndOfBuffering:&segment withCurrentSegment:currentSegment mediaTime:currTime currentPlaybackRate:rate])
        {
            self.lastError = sequencer.lastError;
            [self sendErrorNotification];
            break;
        }
        
        if (PlaylistEntryType_SeekToStart == segment.clip.type)
        {
            FRAMEWORK_LOG(@"Clip change prebuffering: SeekToStart detected");
            
            // Try to get the next segment
            PlaybackSegment *newSegment = nil;
            if (![sequencer getSegmentOnEndOfBuffering:&newSegment withCurrentSegment:segment mediaTime:currTime currentPlaybackRate:rate])
            {
                self.lastError = sequencer.lastError;
                [self sendErrorNotification];
                break;
            }
            [segment release];
            segment = newSegment;
        }
        
        if (PlaylistEntryType_VAST == segment.clip.type)
        {
            FRAMEWORK_LOG(@"Clip change prebuffering: VAST entry detected");
            
            if (![self getSegmentFromVASTSegment:&segment whileBuffering:YES])
            {
                [self sendErrorNotification];
                break;
            }
        }

        self.nextSegment = segment;
        [segment release];
        
        if (nil != nextSegment && nil != nextSegment.clip.clipURI)
        {
            nextURL = [nextSegment.clip.clipURI absoluteString];
            
            if (nil != nextURL)
            {
                [self loadMovie:nextURL];
            }
        }

    } while (NO);        
}

//
// Show the view and attach the seekbar view
//
// Arguments:
// viewToShow: the view to show.
//
// Returns: none
//
- (void) showView:(AVPlayerLayerView *)viewToShow
{
    viewToShow.playerLayer.hidden = NO;
    
    /* Specifies that the player should preserve the video?s aspect ratio and
     fit the video within the layer?s bounds. */
    [viewToShow setVideoFillMode:AVLayerVideoGravityResizeAspect];
}

//
// Hide the view and detach the seekbar view
//
// Arguments:
// viewToHide: the view to hide.
//
// Returns: none
//
- (void) hideView:(AVPlayerLayerView *)viewToHide
{
    if (nil != viewToHide && nil != viewToHide.playerLayer)
    {
        viewToHide.playerLayer.hidden = YES;
    }
}

//
// Handle the SeekToStart entry
//
// Arguments:
// none.
//
// Returns: YES for success and NO for failure
//
- (BOOL) checkSeekToStart
{
    BOOL success = YES;
    
    if (PlaylistEntryType_SeekToStart == nextSegment.clip.type)
    {
        FRAMEWORK_LOG(@"Clip change: SeekToStart detected");
        
        // Try to get the next segment
        PlaybackSegment *segment = nil;
        success = [sequencer getSegmentOnEndOfMedia:&segment withCurrentSegment:nextSegment mediaTime:0 currentPlaybackRate:rate isNotPlayed:NO isEndOfSequence:NO];
        if (!success)
        {
            self.lastError = sequencer.lastError;
        }
        
        if (nil == segment)
        {
            // nothing to play
            FRAMEWORK_LOG(@"End of playback");
        }
        else
        {
            self.nextSegment = segment;
            [segment release];
        }
    }
    
    return success;
}

//
// Resolve the VAST entry to entries with content URL
//
// Arguments:
// [segment]  This is an input/output parameter. For input it is the VAST segment, for output it is the first resolved segment with content URL.
// [isBuffering]  YES if this is called during pre-buffer, NO if this is called at the content switching time.
//
// Returns: YES for success and NO for failure
//
- (BOOL) getSegmentFromVASTSegment:(PlaybackSegment **)segment whileBuffering:(BOOL)isBuffering
{
    BOOL success = YES;
    NSMutableArray *adPodArray = nil;
    NSString *vastURL = [(*segment).clip.clipURI absoluteString];
    NSTimeInterval totalDuration = (*segment).clip.mediaTime.clipEndMediaTime - (*segment).clip.mediaTime.clipBeginMediaTime;

    do {
        // Download the vast manifest, has to be a blocking call
        NSString *manifest = nil;
        success = [self.adResolver downloadManifest:&manifest withURL:[NSURL URLWithString:vastURL]];
        if (!success)
        {
            FRAMEWORK_LOG(@"Failed to download the manifest with url:%@", vastURL);
            self.lastError = self.adResolver.lastError;
            break;
        }
        
        success = [self getAdInfos:&adPodArray fromVAST:manifest];
        if (!success || nil == adPodArray || 0 == [adPodArray count])
        {
            FRAMEWORK_LOG(@"Failed to parse the VAST manifest");
            break;
        }
        
        AdInfo *baseAd = [[[AdInfo alloc] init] autorelease];
        baseAd.type = AdType_Pod;
        baseAd.appendTo = (*segment).clip.entryId;
        baseAd.mediaTime = (*segment).clip.mediaTime;
        baseAd.policy = (*segment).clip.playbackPolicy;
        baseAd.clipURL = (*segment).clip.clipURI;
        baseAd.deleteAfterPlayed = YES;
        
        success = [self scheduleAds:adPodArray withTotalDuration:(NSTimeInterval)totalDuration atTime:(*segment).clip.linearTime basedOnAd:baseAd andGetClipId:nil];
        if (!success)
        {
            FRAMEWORK_LOG(@"Failed to schedule all the ads in ad pod specified in the VAST manifest");
            break;
        }
    } while (NO);
    [adPodArray removeAllObjects];
    [adPodArray release];
    
    // if there is error scheduling the VAST ad, send error notification but moves on to the next segment anyway
    if (!success)
    {
        [self sendErrorNotification];
    }

    // Try to get the next segment
    PlaybackSegment *newSegment = nil;
    if (isBuffering)
    {
        success = [sequencer getSegmentOnEndOfBuffering:&newSegment withCurrentSegment:(*segment) mediaTime:0 currentPlaybackRate:rate];
    }
    else
    {
        success = [sequencer getSegmentOnEndOfMedia:&newSegment withCurrentSegment:(*segment) mediaTime:0 currentPlaybackRate:rate isNotPlayed:NO isEndOfSequence:NO];
    }
      
    if (!success)
    {
        self.lastError = sequencer.lastError;
    }
    else
    {
        *segment = newSegment;
    }
    
    return success;
}

#pragma mark -
#pragma mark public properties:

- (NSTimeInterval) currentPlaybackTime
{
    NSTimeInterval currentTime = 0;
    
    if (nil != player)
    {
        CMTime cmCurrentPlaybackTime = player.currentTime;
        currentTime = (0 == cmCurrentPlaybackTime.timescale) ? 0 : (double)cmCurrentPlaybackTime.value / cmCurrentPlaybackTime.timescale;
    }
    
    return currentTime;
}

- (NSTimeInterval) currentLinearTime
{
    NSTimeInterval currentTime = 0;
    MediaTime *mediaTime = [[MediaTime alloc] init];
    mediaTime.currentPlaybackPosition = self.currentPlaybackTime;
    if (nil != sequencer)
    {
        [sequencer getLinearTime:&currentTime withMediaTime:(MediaTime *)mediaTime currentSegment:currentSegment];
    }
    [mediaTime release];
    
    return currentTime;
}

- (AdResolver *) adResolver
{
    return sequencer.adResolver;
}

#pragma mark -
#pragma mark internal properties:

- (PlaybackSegment *) currentSegment
{
    return currentSegment;
}

- (void) setCurrentSegment:(PlaybackSegment *)value
{
    [value retain];
    [currentSegment release];
    currentSegment = value;
}

- (PlaybackSegment *) nextSegment
{
    return nextSegment;
}

- (void) setNextSegment:(PlaybackSegment *)value
{
    [value retain];
    [nextSegment release];
    nextSegment = value;
}

- (NSMutableArray *) avPlayerViews
{
    return avPlayerViews;
}

- (void) setAvPlayerViews:(NSMutableArray *)value
{
    [value retain];
    [avPlayerViews release];
    avPlayerViews = value;
}

//
// Timer method that monitors the state of the playback and generate
// notifications for UI update correspondingly.
//
// Arguments:
// [timer]  NSTimer object.
//
// Returns: none.
//
- (void) timer:(NSTimer *)timer
{
    if (nil != currentSegment && PlayerStatus_Playing == currentSegment.status)
    {
        SeekbarTime * seekbarTime = nil;
        AVPlayerLayerView *playerLayerView = [avPlayerViews objectAtIndex:currentSegment.viewIndex];
        AVPlayer *moviePlayer = playerLayerView.player;
        CMTime cmCurrPlaybackTime = moviePlayer.currentTime;
        
        NSTimeInterval currPlaybackTime = (0 == cmCurrPlaybackTime.timescale) ? 0 : (double)cmCurrPlaybackTime.value / cmCurrPlaybackTime.timescale;
        
        // Get seekbar time from the sequencer
        NSString *playbackPolicy = nil;
        MediaTime *currentMediaTime = [[MediaTime alloc] init];
        currentMediaTime.currentPlaybackPosition = currPlaybackTime;
        currentMediaTime.clipBeginMediaTime = currentSegment.clip.mediaTime.clipBeginMediaTime;
        currentMediaTime.clipEndMediaTime = currentSegment.clip.mediaTime.clipEndMediaTime;
        BOOL segmentEnded = NO;
        
        [self updateLiveInfo];
        if (!hasStartedAfterStop && !(currentSegment.clip.isAdvertisement && currentSegment.clip.linearTime.duration == 0))
        {
            hasStarted = YES;
            hasStartedAfterStop = YES;
            if (0 != initialPlaybackPosition)
            {
                currentMediaTime.currentPlaybackPosition = initialPlaybackPosition;
            }
            if (0 != currentMediaTime.currentPlaybackPosition)
            {
                [self seekToTime:currentMediaTime.currentPlaybackPosition];
            }
        }
        if (isLive && !(currentSegment.clip.isAdvertisement && currentSegment.clip.linearTime.duration == 0))
        {
            // The main content is live, we need to call again with live parameters
            [seekbarTime release]; 
            if (![sequencer getSeekbarTime:&seekbarTime andPlaybackPolicy:&playbackPolicy withMediaTime:currentMediaTime playbackRate:rate currentSegment:self.currentSegment playbackRangeExceeded:&segmentEnded leftDvrEdge:leftDvrEdge livePosition:livePosition liveEnded:NO])
            {
                if ([[sequencer.lastError.userInfo valueForKey:NSLocalizedFailureReasonErrorKey] rangeOfString:@"taken over by left DVR edge"].location != NSNotFound)
                {
                    // left DVR edge take over the current position
                    // In this case the playback position will be automatically snapped to the left edge by AVPlayer
                    // We need to notify the app to start playback if it is paused. And we need to call mediaToSeekbarTime
                    // again to get the correct seek bar range.
                    self.lastError = sequencer.lastError;
                    [self sendErrorNotification];
                    currentMediaTime.currentPlaybackPosition = leftDvrEdge - (currentSegment.clip.linearTime.startTime - currentSegment.clip.mediaTime.clipBeginMediaTime);
                    if (![sequencer getSeekbarTime:&seekbarTime andPlaybackPolicy:&playbackPolicy withMediaTime:currentMediaTime playbackRate:rate currentSegment:self.currentSegment playbackRangeExceeded:&segmentEnded leftDvrEdge:leftDvrEdge livePosition:livePosition liveEnded:NO])
                    {
                        self.lastError = sequencer.lastError;
                        [self sendErrorNotification];
                        [currentMediaTime release];
                        return;                        
                    }
                }
                else
                {
                    self.lastError = sequencer.lastError;
                    [self sendErrorNotification];
                    [currentMediaTime release];
                    return;
                }
            }
        }
        else if (![sequencer getSeekbarTime:&seekbarTime andPlaybackPolicy:&playbackPolicy withMediaTime:currentMediaTime playbackRate:rate currentSegment:self.currentSegment playbackRangeExceeded:&segmentEnded])
        {
            self.lastError = sequencer.lastError;
            [self sendErrorNotification];
            [currentMediaTime release];
            return;
        }
        
        if (0 == timerCount || segmentEnded)
        {
            // Send notification for seek bar time update
            SeekbarTimeUpdatedEventArgs *eventArgs = [[SeekbarTimeUpdatedEventArgs alloc] init];
            eventArgs.seekbarTime = seekbarTime;
            
            NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
            [userInfo setObject:eventArgs forKey:SeekbarTimeUpdatedArgsUserInfoKey];
            
            [eventArgs release];
            
            NSNotification *notification = [NSNotification notificationWithName:SeekbarTimeUpdatedNotification object:self userInfo:userInfo];
            [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
            
            [userInfo release];
        }
        [seekbarTime release];

        // Reset the timerCount to 0 when segment is ended so there is no delay in notification for the new segment
        timerCount = segmentEnded ? 0 : (timerCount + 1) % TIMER_INTERVALS_PER_NOTIFICATION;

        if (segmentEnded)
        {
            // Playback should end
            if(![self contentFinished:NO])
            {
                [self sendErrorNotification];
            }
        }
        else if ((currentSegment.clip.mediaTime.clipEndMediaTime - currentMediaTime.currentPlaybackPosition < BUFFERING_COMPLETE_BEFORE_EOS_SEC) &&
                 (nil == nextSegment))
        {
            // Should start to pre-load the next content
            [self preloadContent];
        }
        else
        {
            // the framework won't enforce playback policy
        }
        
        [currentMediaTime release];
    }
}

//
// Timer method that monitors when the loading of the JavaScript files finishes.
//
// Arguments:
// [timer]  NSTimer object.
//
// Returns: none.
//
- (void) loadTimer:(NSTimer *)timer
{
    if (nil != sequencer && nil != sequencer.scheduler)
    {
        if (sequencer.isReady)
        {
            [self sendReadyNotification];
        }
        else
        {
            [loadingTimer invalidate];
            [loadingTimer release];
            loadingTimer = [[NSTimer scheduledTimerWithTimeInterval:JAVASCRIPT_LOADING_POLLING_INTERVAL target:self selector:@selector(loadTimer:) userInfo:NULL repeats:NO] retain];
        }
    }
}

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    [player release];
    [sequencer release];
    [currentSegment release];
    [nextSegment release];
    [lastError release];
    [appDelegate release];

    for (AVPlayerLayerView *playerView in avPlayerViews)
    {
        [playerView removeFromSuperview];
    }
    [avPlayerViews removeAllObjects];
    [avPlayerViews release];
    
    if (seekbarTimer)
    {
        [seekbarTimer invalidate];
        [seekbarTimer release];
        seekbarTimer = nil;
    }
    
    if (loadingTimer)
    {
        if (loadingTimer.isValid)
        {
            [loadingTimer invalidate];
        }
        [loadingTimer release];
        loadingTimer = nil;
    }
    
    [super dealloc];
}

@end
