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

#import "MediaFile.h"
#import "Trace.h"

@implementation MediaFile

#pragma mark -
#pragma mark Properties:

@synthesize uriString;
@synthesize idString;
@synthesize delivery;
@synthesize type;
@synthesize bitrate;
@synthesize minBitrate;
@synthesize maxBitrate;
@synthesize width;
@synthesize height;
@synthesize scalable;
@synthesize maintainAspectRatio;
@synthesize codec;
@synthesize apiFramework;


#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    SEQUENCER_LOG(@"VideoClick dealloc called.");
    
    [uriString release];
    [idString release];
    [delivery release];
    [type release];
    [codec release];
    [apiFramework release];
    
    [super dealloc];
}

@end
