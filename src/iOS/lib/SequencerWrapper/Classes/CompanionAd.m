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

#import "CompanionAd.h"
#import "Trace.h"

@implementation CompanionAd

#pragma mark -
#pragma mark Properties:

@synthesize type;
@synthesize uriString;
@synthesize idString;
@synthesize width;
@synthesize height;
@synthesize assetWidth;
@synthesize assetHeight;
@synthesize expandedWidth;
@synthesize expandedHeight;
@synthesize apiFramework;
@synthesize adSlotID;
@synthesize creativeType;
@synthesize xmlEncoded;
@synthesize clickTrackingId;
@synthesize tracking;

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    SEQUENCER_LOG(@"CompanionAd dealloc called.");
    
    [type release];
    [uriString release];
    [idString release];
    [apiFramework release];
    [adSlotID release];
    [creativeType release];
    [clickTrackingId release];
    [tracking release];
    
    [super dealloc];
}

@end
