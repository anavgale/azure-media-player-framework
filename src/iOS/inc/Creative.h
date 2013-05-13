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

#import "CompositeElement.h"

typedef enum
{
    CreativeExtensions,
    Linear,
    CompanionAds,
    NonlinearAds
} VASTCreativeType;

typedef enum
{
    All,
    Any,
    None
} VASTRequiredType;

@interface Creative : NSObject
{
@private
    VASTCreativeType type;
    NSString *idString;
    NSString *adID;    
    int32_t sequence;
    NSString *apiFramework;
    NSTimeInterval skipoffset;
    BOOL xmlEncoded;
    VASTRequiredType required;
    NSString *creativeExtension;
    NSString *adParameters;
    NSTimeInterval duration;
    CompositeElement *mediaFiles;
    CompositeElement *trackingEvents;
    CompositeElement *videoClicks;
    CompositeElement *icons;
    CompositeElement *companion;
    CompositeElement *nonlinear;
}

@property(nonatomic, assign) VASTCreativeType type;
@property(nonatomic, retain) NSString *idString;
@property(nonatomic, retain) NSString *adID;
@property(nonatomic, assign) int32_t sequence;
@property(nonatomic, retain) NSString *apiFramework;
@property(nonatomic, assign) NSTimeInterval skipoffset;
@property(nonatomic, assign) BOOL xmlEncoded;
@property(nonatomic, assign) VASTRequiredType required;
@property(nonatomic, retain) NSString *creativeExtension;
@property(nonatomic, retain) NSString *adParameters;
@property(nonatomic, assign) NSTimeInterval duration;
@property(nonatomic, retain) CompositeElement *mediaFiles;
@property(nonatomic, retain) CompositeElement *trackingEvents;
@property(nonatomic, retain) CompositeElement *videoClicks;
@property(nonatomic, retain) CompositeElement *icons;
@property(nonatomic, retain) CompositeElement *companion;
@property(nonatomic, retain) CompositeElement *nonlinear;

@end

