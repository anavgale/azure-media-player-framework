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

#import "MediaTime.h"
#import "LinearTime.h"
#import "PlaybackPolicy.h"

typedef enum
{
    PlaylistEntryType_Media,        // URI points to single-segment Smooth/HLS/DASH/Progressive media
    PlaylistEntryType_Static,       // URI points to static page
    PlaylistEntryType_VAST,         // URI points to VAST manifest - client is responsible for resolving to media URI
    PlaylistEntryType_SeekToStart   // URI points to single-segment Smooth/HLS/DASH/Progressive media for live or null if on-demand.
} PlaylistEntryType;

@interface PlaylistEntry : NSObject
{
@private
    PlaylistEntryType type;
    int32_t entryId;
    int32_t originalId;
    LinearTime *linearTime;
    NSURL *clipURI;
    MediaTime *mediaTime;
    BOOL isAdvertisement;
    BOOL deleteAfterPlayed;
    PlaybackPolicy *playbackPolicy;
}

@property(nonatomic, assign) PlaylistEntryType type;
@property(nonatomic, assign) int32_t entryId;
@property(nonatomic, assign) int32_t originalId;
@property(nonatomic, retain) LinearTime *linearTime;
@property(nonatomic, retain) NSURL *clipURI;
@property(nonatomic, retain) MediaTime *mediaTime;
@property(nonatomic, assign) BOOL isAdvertisement;
@property(nonatomic, assign) BOOL deleteAfterPlayed;
@property(nonatomic, retain) PlaybackPolicy *playbackPolicy;

@end
