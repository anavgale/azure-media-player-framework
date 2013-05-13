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
    InLine,
    Wrapper
} VASTAdType;

@interface Ad : NSObject
{
@private
    VASTAdType type;
    NSString *idString;
    int32_t sequence;
    NSString *adSystem;
    NSString *adTitle;
    NSString *description;
    NSString *error;
    NSString *impression;
    CompositeElement *creatives;
    CompositeElement *extensions;
    NSString *advertiser;
    NSString *pricing;
    NSString *survey;
    NSString *adTagURI;
}

@property(nonatomic, assign) VASTAdType type;
@property(nonatomic, retain) NSString *idString;
@property(nonatomic, assign) int32_t sequence;
@property(nonatomic, retain) NSString *adSystem;
@property(nonatomic, retain) NSString *adTitle;
@property(nonatomic, retain) NSString *description;
@property(nonatomic, retain) NSString *error;
@property(nonatomic, retain) NSString *impression;
@property(nonatomic, retain) CompositeElement *creatives;
@property(nonatomic, retain) CompositeElement *extensions;
@property(nonatomic, retain) NSString *advertiser;
@property(nonatomic, retain) NSString *pricing;
@property(nonatomic, retain) NSString *survey;
@property(nonatomic, retain) NSString *adTagURI;

@end
