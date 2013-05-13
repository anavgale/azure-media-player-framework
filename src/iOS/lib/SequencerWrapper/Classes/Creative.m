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

#import "Creative.h"
#import "Trace.h"

@implementation Creative

#pragma mark -
#pragma mark Properties:

@synthesize type;
@synthesize idString;
@synthesize adID;
@synthesize sequence;
@synthesize apiFramework;
@synthesize skipoffset;
@synthesize xmlEncoded;
@synthesize required;
@synthesize creativeExtension;
@synthesize adParameters;
@synthesize duration;
@synthesize mediaFiles;
@synthesize trackingEvents;
@synthesize videoClicks;
@synthesize icons;
@synthesize companion;
@synthesize nonlinear;

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    SEQUENCER_LOG(@"Creative dealloc called.");
    
    [idString release];
    [adID release];
    [apiFramework release];
    [creativeExtension release];
    [adParameters release];
    [mediaFiles release];
    [trackingEvents release];
    [videoClicks release];
    [icons release];
    [companion release];
    [nonlinear release];
    
    [super dealloc];
}

@end
