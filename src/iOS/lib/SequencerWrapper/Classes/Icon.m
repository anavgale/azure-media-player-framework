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

#import "Icon.h"
#import "Trace.h"

@implementation Icon

#pragma mark -
#pragma mark Properties:

@synthesize type;
@synthesize uriString;
@synthesize creativeType;
@synthesize program;
@synthesize width;
@synthesize height;
@synthesize xPosition;
@synthesize yPosition;
@synthesize duration;
@synthesize offset;
@synthesize apiFramework;
@synthesize iconClicks;

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    SEQUENCER_LOG(@"Icon dealloc called.");
    
    [type release];
    [uriString release];
    [creativeType release];
    [program release];
    [apiFramework release];
    [iconClicks release];
    
    [super dealloc];
}

@end
