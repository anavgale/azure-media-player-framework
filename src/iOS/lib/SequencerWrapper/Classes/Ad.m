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

#import "Ad.h"
#import "Trace.h"

@implementation Ad

#pragma mark -
#pragma mark Properties:

@synthesize type;
@synthesize idString;
@synthesize sequence;
@synthesize adSystem;
@synthesize adTitle;
@synthesize description;
@synthesize error;
@synthesize impression;
@synthesize creatives;
@synthesize extensions;
@synthesize advertiser;
@synthesize pricing;
@synthesize survey;
@synthesize adTagURI;

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    SEQUENCER_LOG(@"Ad dealloc called.");
    
    [idString release];
    [adSystem release];
    [adTitle release];
    [description release];
    [error release];
    [impression release];
    [creatives release];
    [extensions release];
    [advertiser release];
    [pricing release];
    [survey release];
    [adTagURI release];
    
    [super dealloc];
}

@end
