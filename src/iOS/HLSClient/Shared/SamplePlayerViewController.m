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

#import "SamplePlayerViewController.h"
#import "SamplePlayerAppDelegate.h"
#import <SequencerAVPlayerFramework.h>
#import <MediaTime.h>
#import <SeekbarTime.h>
#import <Scheduler.h>
#import <AdResolver.h>
#import <MediaFile.h>

#define SKIP_FORWARD_SECONDS 60
#define SKIP_BACKWARD_SECONDS 60

NSString * const MIME_TYPE_HLS1 = @"application/x-mpegURL";
NSString * const MIME_TYPE_HLS2 = @"application/vnd.apple.mpegURL";
NSString * const MIME_TYPE_MP4 = @"video/mp4";

@implementation SamplePlayerViewController

#pragma mark -
#pragma mark Properties:

@synthesize urlText;
@synthesize playerView;
@synthesize urlList;
@synthesize stateText;
@synthesize currentPlaybackRate;
@synthesize framework;

#pragma mark -
#pragma mark private methods:

- (void)logFrameworkError
{
    if (nil != framework)
    {
        NSError *error = framework.lastError;
        NSLog(@"Error with domain name:%@, description:%@ and reason:%@", error.domain, error.localizedDescription, error.localizedFailureReason);
    }

    if (nil != currentEntry && currentEntry.isAdvertisement)
    {
        [framework skipCurrentPlaylistEntry];
    }
    else
    {
        [self onStopButtonPressed];
    }
}

#pragma mark -
#pragma mark Instance methods:

- (void)setUrlList:(NSMutableArray*)newValue;
{
    [urlList release];
    
    urlList = [[NSMutableArray alloc] initWithArray:newValue];
    
    currURL = 0;
    
    if(urlList.count > 0)
    {
        urlText.text = [urlList objectAtIndex:currURL];
    }
}

//
// Format a time value (in seconds) to a string.
//
// Arguments:
// [value]  The time value to be formatted.
//
// Returns:
// A string containing the time value with the right format.
//
- (NSString *) stringFromNSTimeInterval:(NSTimeInterval)value
{
    int hours = (int)value / 3600;
    int minutes = ((int)value % 3600) / 60;
    int seconds = (int)value % 60;
    
    if (hours > 0)
    {
        return [NSString stringWithFormat:@"%02d:%02d:%02d", hours, minutes, seconds];
    }
    else
    {
        return [NSString stringWithFormat:@"%02d:%02d", minutes, seconds];
    }               
}

//
// Play the content for a given Url.
//
// Arguments:
// [url]    Url of the content to be played.
//
// Returns: none.
//
- (void) playURL:(NSString *)url
{
    if (!hasStarted)
    {
        // Clear download cache to get the latest content
        [[NSURLCache sharedURLCache] removeAllCachedResponses];

        // Schedule the main content
        MediaTime *mediaTime = [[[MediaTime alloc] init] autorelease];
        mediaTime.currentPlaybackPosition = 0;
        mediaTime.clipBeginMediaTime = 0;
        mediaTime.clipEndMediaTime = 90;
        
        int clipId = 0;
        if (![framework appendContentClip:[NSURL URLWithString:url] withMediaTime:mediaTime andGetClipId:&clipId])
        {
            [self logFrameworkError];
        }
        
        //
        //Uncomment following section(s) to try Ad scheduling examples.
        //
        
        /*
        //Example:1 How to use RCE.
        NSString *secondContent=@"http://wamsblureg001orig-hs.cloudapp.net/6651424c-a9d1-419b-895c-6993f0f48a26/The%20making%20of%20Microsoft%20Surface-m3u8-aapl.ism/Manifest(format=m3u8-aapl)";
        mediaTime.currentPlaybackPosition = 0;
        mediaTime.clipBeginMediaTime = 0;
        mediaTime.clipEndMediaTime = 80;
        if (![framework appendContentClip:[NSURL URLWithString:secondContent] withMediaTime:mediaTime andGetClipId:&clipId])
        {
            [self logFrameworkError];
        }*/

        NSString *manifest = nil;
        
        /* 
        //Example:2 How to schedule an Ad using VMAP.
        //
        //First download the VMAP manifest
        
        if (![framework.adResolver downloadManifest:&manifest withURL:[NSURL URLWithString:@"http://portalvhdsq3m25bf47d15c.blob.core.windows.net/vast/PlayerTestVMAP.xml"]])
        {
            [self logFrameworkError];
        }
        else
        {
            // Schedule a list of ads using the downloaded VMAP manifest
            if (![framework scheduleVMAPWithManifest:manifest])
            {
                [self logFrameworkError];
            }
            
        }*/
        
        LinearTime *adLinearTime = [[[LinearTime alloc] init] autorelease];
        int32_t adIndex;
        
        /*
        //Example:3 How to schedule a late binding VAST ad.
        
        adLinearTime.startTime = 13;
        adLinearTime.duration = 0;
        
        NSString *vastAd1=@"http://portalvhdsq3m25bf47d15c.blob.core.windows.net/vast/PlayerTestVAST.xml";
        AdInfo *vastAdInfo1 = [[[AdInfo alloc] init] autorelease];
        vastAdInfo1.clipURL = [NSURL URLWithString:vastAd1];
        vastAdInfo1.mediaTime = [[[MediaTime alloc] init] autorelease];
        vastAdInfo1.mediaTime.clipBeginMediaTime = 0;
        vastAdInfo1.mediaTime.clipEndMediaTime = 10;
        vastAdInfo1.policy = [[[PlaybackPolicy alloc] init] autorelease];
        vastAdInfo1.type = AdType_Midroll;
        vastAdInfo1.appendTo=-1;
        adIndex = 0;
        if (![framework scheduleClip:vastAdInfo1 atTime:adLinearTime forType:PlaylistEntryType_VAST andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        */
       
        /*
        //Example:4 Schedule an early binding VAST ad
        //Download the manifest first
        if (![framework.adResolver downloadManifest:&manifest withURL:[NSURL URLWithString:@"http://portalvhdsq3m25bf47d15c.blob.core.windows.net/vast/PlayerTestVAST.xml"]])
        {
            [self logFrameworkError];
        }
        else
        {
            adLinearTime.startTime = 7;
            adLinearTime.duration = 0;
            
            AdInfo *vastAdInfo2 = [[[AdInfo alloc] init] autorelease];
            vastAdInfo2.mediaTime = [[[MediaTime alloc] init] autorelease];
            vastAdInfo2.policy = [[[PlaybackPolicy alloc] init] autorelease];
            vastAdInfo2.type = AdType_Midroll;
            vastAdInfo2.appendTo=-1;
            if (![framework scheduleVASTClip:vastAdInfo2 withManifest:manifest atTime:adLinearTime andGetClipId:&adIndex])
            {
                [self logFrameworkError];
            }
        }
        */
       
        /*
        //Example:5 Schedule an ad Pod.
        adLinearTime.startTime = 23;
        adLinearTime.duration = 0;
        
        NSString *adpodSt1=@"https://portalvhdsq3m25bf47d15c.blob.core.windows.net/asset-e47b43fd-05dc-4587-ac87-5916439ad07f/Windows%208_%20Cliffjumpers.mp4?st=2012-11-28T16%3A31%3A57Z&se=2014-11-28T16%3A31%3A57Z&sr=c&si=2a6dbb1e-f906-4187-a3d3-7e517192cbd0&sig=qrXYZBekqlbbYKqwovxzaVZNLv9cgyINgMazSCbdrfU%3D";
        AdInfo *adpodInfo1 = [[[AdInfo alloc] init] autorelease];
        adpodInfo1.clipURL = [NSURL URLWithString:adpodSt1];
        adpodInfo1.mediaTime = [[[MediaTime alloc] init] autorelease];
        adpodInfo1.mediaTime.clipBeginMediaTime = 0;
        adpodInfo1.mediaTime.clipEndMediaTime = 17;
        adpodInfo1.policy = [[[PlaybackPolicy alloc] init] autorelease];
        adpodInfo1.type = AdType_Midroll;
        adpodInfo1.appendTo=-1;
        adIndex = 0;
        if (![framework scheduleClip:adpodInfo1 atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        
        NSString *adpodSt2=@"https://portalvhdsq3m25bf47d15c.blob.core.windows.net/asset-532531b8-fca4-4c15-86f6-45f9f45ec980/Windows%208_%20Sign%20in%20with%20a%20Smile.mp4?st=2012-11-28T16%3A35%3A26Z&se=2014-11-28T16%3A35%3A26Z&sr=c&si=c6ede35c-f212-4ccd-84da-805c4ebf64be&sig=zcWsj1JOHJB6TsiQL5ZbRmCSsEIsOJOcPDRvFVI0zwA%3D";
        AdInfo *adpodInfo2 = [[[AdInfo alloc] init] autorelease];
        adpodInfo2.clipURL = [NSURL URLWithString:adpodSt2];
        adpodInfo2.mediaTime = [[[MediaTime alloc] init] autorelease];
        adpodInfo2.mediaTime.clipBeginMediaTime = 0;
        adpodInfo2.mediaTime.clipEndMediaTime = 17;
        adpodInfo2.policy = [[[PlaybackPolicy alloc] init] autorelease];
        adpodInfo2.type = AdType_Pod;
        adpodInfo2.appendTo = adIndex;
        if (![framework scheduleClip:adpodInfo2 atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        */
        
        //Example:6 Schedule a single non sticky mid roll Ad 
        NSString *oneTimeAd=@"http://wamsblureg001orig-hs.cloudapp.net/5389c0c5-340f-48d7-90bc-0aab664e5f02/Windows%208_%20You%20and%20Me%20Together-m3u8-aapl.ism/Manifest(format=m3u8-aapl)";
        AdInfo *oneTimeInfo = [[[AdInfo alloc] init] autorelease];
        oneTimeInfo.clipURL = [NSURL URLWithString:oneTimeAd];
        oneTimeInfo.mediaTime = [[[MediaTime alloc] init] autorelease];
        oneTimeInfo.mediaTime.clipBeginMediaTime = 0;
        oneTimeInfo.mediaTime.clipEndMediaTime = 25;
        oneTimeInfo.policy = [[[PlaybackPolicy alloc] init] autorelease];
        adLinearTime.startTime = 43;
        adLinearTime.duration = 0;
        oneTimeInfo.type = AdType_Midroll;
        oneTimeInfo.deleteAfterPlayed = YES;
        if (![framework scheduleClip:oneTimeInfo atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        
        //Example:7 Schedule a single sticky mid roll Ad
        NSString *stickyAd=@"http://wamsblureg001orig-hs.cloudapp.net/2e4e7d1f-b72a-4994-a406-810c796fc4fc/The%20Surface%20Movement-m3u8-aapl.ism/Manifest(format=m3u8-aapl)";
        AdInfo *stickyAdInfo = [[[AdInfo alloc] init] autorelease];
        stickyAdInfo.clipURL = [NSURL URLWithString:stickyAd];
        stickyAdInfo.mediaTime = [[[MediaTime alloc] init] autorelease];
        stickyAdInfo.mediaTime.clipBeginMediaTime = 0;
        stickyAdInfo.mediaTime.clipEndMediaTime = 15;
        stickyAdInfo.policy = [[[PlaybackPolicy alloc] init] autorelease];
        adLinearTime.startTime = 64;
        adLinearTime.duration = 0;
        stickyAdInfo.type = AdType_Midroll;
        stickyAdInfo.deleteAfterPlayed = NO;
        
        if (![framework scheduleClip:stickyAdInfo atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        
        //Example:8 Schedule Post Roll Ad
        NSString *postAdURLString=@"http://wamsblureg001orig-hs.cloudapp.net/aa152d7f-3c54-487b-ba07-a58e0e33280b/wp-m3u8-aapl.ism/Manifest(format=m3u8-aapl)";
        AdInfo *postAdInfo = [[[AdInfo alloc] init] autorelease];
        postAdInfo.clipURL = [NSURL URLWithString:postAdURLString];
        postAdInfo.mediaTime = [[[MediaTime alloc] init] autorelease];
        postAdInfo.mediaTime.clipBeginMediaTime = 0;
        postAdInfo.mediaTime.clipEndMediaTime = 45;
        postAdInfo.policy = [[[PlaybackPolicy alloc] init] autorelease];
        postAdInfo.type = AdType_Postroll;
        adLinearTime.duration = 0;
        if (![framework scheduleClip:postAdInfo atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        
        //Example:9 Schedule Pre Roll Ad
        NSString *adURLString = @"https://htmlsamples.blob.core.windows.net/asset-197e2747-49e7-49d2-b7fa-26b5dbc781aa/Switch%20to%20the%20Nokia%20Lumia%20920%20Windows%20Phone%20-%20Engadget%20Reader's%20Choice%20Smartphone%20of%20the%20Year..mp4?sv=2012-02-12&st=2013-05-10T19%3A38%3A53Z&se=2015-05-10T19%3A38%3A53Z&sr=c&si=83083fbf-0989-40e9-929e-5da76adddc20&sig=pVtzTXvIyh1DKcJ63c6y%2FPpEDp8dQbVQZvpfIL8I0%2Bs%3D";
        AdInfo *adInfo = [[[AdInfo alloc] init] autorelease];
        adInfo.clipURL = [NSURL URLWithString:adURLString];
        adInfo.mediaTime = [[[MediaTime alloc] init] autorelease];
        adInfo.mediaTime.currentPlaybackPosition = 0;
        adInfo.mediaTime.clipBeginMediaTime = 40; //You could play a portion of an Ad. Yeh!
        adInfo.mediaTime.clipEndMediaTime = 59;
        adInfo.policy = [[[PlaybackPolicy alloc] init] autorelease];
        adInfo.appendTo = -1;
        adInfo.type = AdType_Preroll;
        adLinearTime.duration = 0;
        if (![framework scheduleClip:adInfo atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
        {
            [self logFrameworkError];
        }
        
        hasStarted = YES;
    }
    
    // Register for seekbar notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(seekbarUpdatedNotification:) name:SeekbarTimeUpdatedNotification object:framework];
    
    // Register for playlist entry changed notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playlistEntryChangedNotification:) name:PlaylistEntryChangedNotification object:framework];
    
    // Register for error notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerSequencerErrorNotification:) name:PlayerSequencerErrorNotification object:framework];
    
    if (![framework play])
    {
        [self logFrameworkError];
    }
}

//
// Event handler when the "Prev" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Prev" button).
//
// Returns: none.
//
- (IBAction) buttonPrevPressed:(id) sender
{
    if (currURL > 0)
    {
        currURL--;
    }
    else
    {
        currURL = [urlList count] - 1;
    }
    
    urlText.text = [urlList objectAtIndex:currURL];

    if (isPlaying)
    {
        isPlaying = false;
        [self onPlayPauseButtonPressed];
    }
}

//
// Event handler when the "Next" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Next" button).
//
// Returns: none.
//
- (IBAction) buttonNextPressed:(id) sender
{
    if (currURL < [urlList count] - 1)
    {
        currURL++;
    }
    else
    {
        currURL = 0;
    }
    
    urlText.text = [urlList objectAtIndex:currURL];

    if (isPlaying)
    {
        isPlaying = false;
        [self onPlayPauseButtonPressed];
    }
}

//
// Event handler when the "Magic" button is moved.
// The magic button is designed for some special purposes.
//
// Arguments:
// [sender]     Sender of the event (the "Magic" button).
//
// Returns: none.
//
- (IBAction) buttonMagicPressed:(id) sender
{
}

//
// Event handler when the "Play" or "Pause" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Play" or "Pause" button).
//
// Returns: none.
//
- (void) onPlayPauseButtonPressed
{
    if (!isReady)
    {
        NSLog(@"sequencer framework is not ready yet.");
        return;
    }

    if (!isPlaying)
    {
        [self playURL:[urlText text]];

        [spinner startAnimating];
        
        isPlaying = YES;
        isPaused = NO;
        [seekbarViewController setPlayPauseButtonIcon:@"pause.png"];
        [seekbarViewController setSliderMaxValue:0];
        [seekbarViewController setSliderMinValue:0];
    }
    else 
    {
        if (isPaused)
        {
            if (![framework play])
            {
                [self logFrameworkError];
            }
            [seekbarViewController setPlayPauseButtonIcon:@"pause.png"];
        }
        else
        {
            [framework pause];
            [seekbarViewController setPlayPauseButtonIcon:@"playmain.png"];
        }
        isPaused = !isPaused;
    }
}

//
// Event handler when the "Stop" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Stop" button).
//
// Returns: none.
//
- (void) onStopButtonPressed
{    
    // Stop the framework    
    if (nil != framework)
    {        
        // Unregister for error notification
        [[NSNotificationCenter defaultCenter] removeObserver:self name:PlayerSequencerErrorNotification object:framework];

        // Unregister for playlist entry changed notification
        [[NSNotificationCenter defaultCenter] removeObserver:self name:PlaylistEntryChangedNotification object:framework];
        
        // Unregister for seekbar notification
        [[NSNotificationCenter defaultCenter] removeObserver:self name:SeekbarTimeUpdatedNotification object:framework];
        
        isPlaying = NO;
        isPaused = NO;
        [seekbarViewController setPlayPauseButtonIcon:@"playmain.png"];
        
        [seekbarViewController updateTime:@""];
        
        [seekbarViewController setBufferingValue:0];
        [seekbarViewController setSliderValue:0];
        [seekbarViewController setSliderMaxValue:0];
        [seekbarViewController setSliderMinValue:0];

        [currentEntry release];
        currentEntry = nil;
        [framework stop];
        [spinner stopAnimating];        
    }
}

//
// Event handler when the "Seek Minus" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Seek Minus" button).
//
// Returns: none.
//
- (void) onSeekMinusButtonPressed
{
    if (framework.player)
    {
        NSTimeInterval newTime = (SKIP_BACKWARD_SECONDS <= currentSeekbarPosition) ? (currentSeekbarPosition - SKIP_BACKWARD_SECONDS) : 0;
        
        if(![framework seekToTime:newTime])
        {
            [self logFrameworkError];
        }

        NSLog(@"Seek - pressed (%.2f)...", newTime);
    }
}

//
// Event handler when the "Seek Plus" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Seek Plus" button).
//
// Returns: none.
//
- (void) onSeekPlusButtonPressed
{
    if (framework.player)
    {
        NSTimeInterval newTime = currentSeekbarPosition + SKIP_FORWARD_SECONDS;
        
        if(![framework seekToTime:newTime])
        {
            [self logFrameworkError];
        }
        
        NSLog(@"Seek + pressed (%.2f)...", newTime);
    }
}

//
// Event handler when the "Schedule Now" button is pressed.
//
// Arguments:
// [sender]     Sender of the event (the "Schedule Now" button).
//
// Returns: none.
//
- (void) onScheduleNowButtonPressed
{
    if (!isReady)
    {
        NSLog(@"sequencer framework is not ready yet.");
        return;
    }
    
    NSString *adURLString = @"https://portalvhdsq3m25bf47d15c.blob.core.windows.net/asset-42ff4d13-3cbc-45c4-b8ff-913da9fccef2/IntroToMediaServices.mp4?st=2013-01-21T23%3A16%3A26Z&se=2015-01-21T23%3A16%3A26Z&sr=c&si=bb17ebff-d6eb-4098-a320-0336b83989ba&sig=pwgT%2FUl34hwEDIMWd%2FNxLcRNQ8RUEDORSQVbQiCLSyI%3D";
    AdInfo *adInfo = [[[AdInfo alloc] init] autorelease];
    adInfo.clipURL = [NSURL URLWithString:adURLString];
    adInfo.mediaTime = [[[MediaTime alloc] init] autorelease];
    adInfo.mediaTime.currentPlaybackPosition = 0;
    adInfo.mediaTime.clipBeginMediaTime = 0;
    adInfo.mediaTime.clipEndMediaTime = 5;
    adInfo.policy = [[[PlaybackPolicy alloc] init] autorelease];
    adInfo.appendTo = -1;
    
    LinearTime *adLinearTime = [[[LinearTime alloc] init] autorelease];
    adLinearTime.startTime = framework.currentLinearTime;
    adLinearTime.duration = 0;
    adInfo.type = AdType_Midroll;
    if (nil != currentEntry && currentEntry.isAdvertisement)
    {
        adInfo.type = AdType_Pod;
        adInfo.appendTo = currentEntry.entryId;
    }
    
    int32_t adIndex = 0;
    if (![framework scheduleClip:adInfo atTime:adLinearTime forType:PlaylistEntryType_Media andGetClipId:&adIndex])
    {
        [self logFrameworkError];
    }
    else if (![framework skipCurrentPlaylistEntry])
    {
        [self logFrameworkError];
    }    
}

//
// Event handler when the seek slider is moved.
//
// Arguments:
// [sender]     Sender of the event (the seek slider).
//
// Returns: none.
//
- (void) onSliderChanged:(UISlider *) slider
{
    if (slider.maximumValue > 0.0)
    {
        if (![framework seekToTime:slider.value])
        {
            [self logFrameworkError];
        }
    }
}

//
// Event handler when the text editing of the Url textbox is completed.
//
// Arguments:
// [sender]     Sender of the event (the Url textbox).
//
// Returns: none.
//
- (IBAction) textfieldDoneEditing:(id) sender
{
    [sender resignFirstResponder];
}

//
// Notification callback when the playback of each playlist entry is finished.
//
// Arguments:
// [notification]  An NSNotification object.
//
// Returns: none.
//
- (void) playlistEntryChangedNotification:(NSNotification *)notification
{
    NSLog(@"Inside playlistEntryChangedNotification callback ...");
    
    NSDictionary *userInfo = [notification userInfo];
    PlaylistEntryChangedEventArgs *args = (PlaylistEntryChangedEventArgs *)[userInfo objectForKey:PlaylistEntryChangedArgsUserInfoKey];

    if (nil == args.nextEntry)
    {
        // Playback finished for the entire playlist
        NSLog(@"The playback finished and the last playlist entry is for url %@ and the current playback time is %f",
              nil != args.currentEntry ? args.currentEntry.clipURI : @"nil",
              args.currentPlaybackTime);
        [self onStopButtonPressed];
    }
    else
    {
        // end of one playlist entry
        // but the playlist is not finished yet
        NSLog(@"The playlist entry for %@ finished at time %f and the next entry has url of %@",
              nil != args.currentEntry ? args.currentEntry.clipURI : @"nil",
              args.currentPlaybackTime,
              nil != args.nextEntry ? args.nextEntry.clipURI : @"nil");
    }
    [currentEntry release];
    currentEntry = [args.nextEntry retain];
}

//
// Notification callback when the seekbar is updated.
//
// Arguments:
// [notification]  An NSNotification object that wraps the seekbar time update.
//
// Returns: none.
//
- (void) seekbarUpdatedNotification:(NSNotification *)notification
{
    NSLog(@"Inside seekbar updated notification callback ...");
    
    NSDictionary *userInfo = [notification userInfo];
    SeekbarTimeUpdatedEventArgs *args = (SeekbarTimeUpdatedEventArgs *)[userInfo objectForKey:SeekbarTimeUpdatedArgsUserInfoKey];
    if (nil == args.seekbarTime)
    {
        NSLog(@"There is an error in the seekbar time callback.");
    }
    else
    {
        [seekbarViewController setSliderMinValue:args.seekbarTime.minSeekbarPosition];
        if (args.seekbarTime.minSeekbarPosition < args.seekbarTime.maxSeekbarPosition)
        {
            [seekbarViewController setSliderMaxValue:(args.seekbarTime.maxSeekbarPosition)];
        }
            
        [seekbarViewController setSliderValue:args.seekbarTime.currentSeekbarPosition];
    }

    currentSeekbarPosition = args.seekbarTime.currentSeekbarPosition;
    
    NSString *time = [NSString stringWithFormat:@"%@ / %@", 
                      [self stringFromNSTimeInterval:args.seekbarTime.currentSeekbarPosition],
                      [self stringFromNSTimeInterval:args.seekbarTime.maxSeekbarPosition]];
    
    [seekbarViewController updateTime:time];
    [seekbarViewController updateStatus:[NSString stringWithFormat:@"%@", stateText]];
    
    // Work around a known Apple issue where playback can pause if the bandwidth drops below
    // the initial bandwidth
    if (isPlaying && !isPaused)
    {
        [framework play];
    }
    else if (isPlaying && isPaused)
    {
        [framework pause];
    }        
}

//
// Notification callback when error happened.
//
// Arguments:
// [notification]  An NSNotification object.
//
// Returns: none.
//
- (void) playerSequencerErrorNotification:(NSNotification *)notification
{
    NSLog(@"Inside playerSequencerErrorNotification callback ...");
    
    NSDictionary *userInfo = [notification userInfo];
    NSError *error = (NSError *)[userInfo objectForKey:PlayerSequencerErrorArgsUserInfoKey];
    NSLog(@"Error with domain name:%@, description:%@ and reason:%@", error.domain, error.localizedDescription, error.localizedFailureReason);
    
    if (nil != currentEntry && currentEntry.isAdvertisement)
    {
        [framework skipCurrentPlaylistEntry];
    }
    else
    {
        [self onStopButtonPressed];
    }
}

//
// Notification callback when the framework is ready.
//
// Arguments:
// [notification]  An NSNotification object.
//
// Returns: none.
//
- (void) playerSequencerReadyNotification:(NSNotification *)notification
{
    NSLog(@"Inside playerSequencerReadyNotification callback ...");
    isReady = YES;
}

//
// Notification callback when a VAST/VMAP manifest is downloaded
//
// Arguments:
// [notification]  An NSNotification object.
//
// Returns: none.
//
- (void) manifestDownloadedNotification:(NSNotification *)notification
{
    NSLog(@"Inside manifestDownloadedNotification callback ...");
    
    NSDictionary *userInfo = [notification userInfo];
    ManifestDownloadedEventArgs *args = (ManifestDownloadedEventArgs *)[userInfo objectForKey:ManifestDownloadedArgsUserInfoKey];
    if (nil == args.error)
    {
        NSLog(@"Successfully downloaded the following xml manifest: %@", args.manifest);
    }
    else
    {
        NSLog(@"Error with domain name:%@, description:%@ and reason:%@", args.error.domain, args.error.localizedDescription, args.error.localizedFailureReason);
    }    
}

//
// Do additional setup after a view is loaded from a nib resource.
//
// Arguments:   none.
//
// Returns: none.
//
- (void) viewDidLoad
{
    [super viewDidLoad];

    spinner = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    spinner.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);    
    //spinner.center = self.playerView.center;
    
    CGRect rect = self.playerView.bounds;
    spinner.center = CGPointMake(rect.size.width / 2.0, rect.size.height / 2.0);    

    stateText = @"Stopped";

    urlList = [[NSMutableArray alloc] init];
    
    [urlList addObject:@"http://wamsblureg001orig-hs.cloudapp.net/53bd66eb-8cba-43a8-99d2-1a2a47289fb4/The%20Making%20of%20Touch%20Cover%20for%20Surface-m3u8-aapl.ism/Manifest(format=m3u8-aapl)"];
    [urlList addObject:@"http://devimages.apple.com/iphone/samples/bipbop/bipbopall.m3u8"];
    
    currURL = 0;
    
    urlText.text = [urlList objectAtIndex:currURL];
   
    // Define the size of the seekbar based on whether the code is running on an iPad or an iPhone.
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone)
    {
        seekbarViewController = [[SeekbarViewController alloc] initWithNibName:@"SeekbarViewController_iPhone" bundle:nil];
        seekbarViewController.view.bounds = CGRectMake(0, 5, 440, 65);
        // Since we are using landscape orientation here, the height is actually [UIScreen mainScreen].bounds.size.width
        seekbarViewController.view.frame = CGRectMake(0, [UIScreen mainScreen].bounds.size.width - 65, 480, 65);
    }
    else
    {
        seekbarViewController = [[SeekbarViewController alloc] initWithNibName:@"SeekbarViewController_iPad" bundle:nil];
        seekbarViewController.view.bounds = CGRectMake(0, 10, 1024, 60);
        seekbarViewController.view.frame = CGRectMake(10, [UIScreen mainScreen].bounds.size.width - 85, 984, 50);
    }
    
    seekbarViewController.owner = self;

    [self.view addSubview:seekbarViewController.view];
    
    framework = [[SequencerAVPlayerFramework alloc] initWithView:playerView];
    framework.appDelegate = self;
    isReady = NO;

    // Register for framework ready notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(playerSequencerReadyNotification:) name:PlayerSequencerReadyNotification object:framework];

    // Register for manifest download notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(manifestDownloadedNotification:) name:ManifestDownloadedNotification object:framework.adResolver];

    currentPlaybackRate = 1.0;
    currentEntry = nil;    
}

//
// Determine which layout (landscape or portrait) the app can run. Only
// the landscape mode is supported.
//
// Arguments:
// [interfaceOrientation]   The layout orientation to be checked.
//
// Returns:
// YES if the layout orientation is allowed, NO otherwise.
//
- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return interfaceOrientation == UIInterfaceOrientationLandscapeLeft ||
           interfaceOrientation == UIInterfaceOrientationLandscapeRight;
}

//
// Select one media file to play based on a list alternative media files
//
// Arguments:
// [mediaFilesList] The list of alternative media files to select from.
//
// Returns:
// The media file that is selected. nil return indicates failure to select a file to play.
//
- (MediaFile *) selectMediaFile:(NSArray *)mediaFilesList
{
    MediaFile *mediaFile = nil;
    
    // pick the first HLS type media file. If there is no HLS content then pick the first MP4 file.
    for (MediaFile *file in mediaFilesList)
    {
        if ([file.type isEqualToString:MIME_TYPE_HLS1] || [file.type isEqualToString:MIME_TYPE_HLS2])
        {
            mediaFile = file;
            break;
        }
        
        if (nil == mediaFile && [file.type isEqualToString:MIME_TYPE_MP4])
        {
            mediaFile = file;
        }
    }
    
    if (nil != mediaFile)
    {
        NSLog(@"In the app delegate choosing the media file to play with url:%@", mediaFile.uriString);
    }
    else
    {
        NSLog(@"In the app delegate there is no playable file found in the media file list");        
    }
    
    return mediaFile;
}

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    if (nil != framework)
    {
        // Unregister for manifest downloaded notification
        [[NSNotificationCenter defaultCenter] removeObserver:self name:ManifestDownloadedNotification object:framework.adResolver];
        
        // Unregister for ready notification
        [[NSNotificationCenter defaultCenter] removeObserver:self name:PlayerSequencerReadyNotification object:framework];
    }
    
    [stateText release];

    [urlText release];
    [playerView release];
    [spinner release];
    [framework release];

    [urlList release];
    
    [seekbarViewController release];
    
    [super dealloc];
}

@end
