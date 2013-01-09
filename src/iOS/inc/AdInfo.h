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

#import "PlaybackPolicy.h"
#import "PlaylistEntry.h"

typedef enum
{
    AdType_Preroll,     // preroll ad
    AdType_Midroll,     // midroll ad
    AdType_Postroll,    // postroll ad
    AdType_Pod          // Subsequent ad in an ad pod
} AdType;

@interface AdInfo : NSObject
{
@private
    NSURL* clipURL;
    MediaTime *mediaTime;
    PlaybackPolicy* policy;
    BOOL deleteAfterPlayed;
    AdType type;
    int32_t appendTo;
}

@property(nonatomic, retain) NSURL* clipURL;
@property(nonatomic, retain) MediaTime* mediaTime;
@property(nonatomic, retain) PlaybackPolicy* policy;
@property(nonatomic, assign) BOOL deleteAfterPlayed;
@property(nonatomic, assign) AdType type;
@property(nonatomic, assign) int32_t appendTo;

@end
