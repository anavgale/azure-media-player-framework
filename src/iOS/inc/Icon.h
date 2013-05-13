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

@interface Icon : NSObject
{
@private
    NSString *type;
    NSString *uriString;
    NSString *creativeType;
    NSString *program;
    int32_t width;
    int32_t height;
    int32_t xPosition;
    int32_t yPosition;
    NSTimeInterval duration;
    NSTimeInterval offset;
    NSString *apiFramework;
    CompositeElement *iconClicks;
}

@property(nonatomic, retain) NSString *type;
@property(nonatomic, retain) NSString *uriString;
@property(nonatomic, retain) NSString *creativeType;
@property(nonatomic, retain) NSString *program;
@property(nonatomic, assign) int32_t width;
@property(nonatomic, assign) int32_t height;
@property(nonatomic, assign) int32_t xPosition;
@property(nonatomic, assign) int32_t yPosition;
@property(nonatomic, assign) NSTimeInterval duration;
@property(nonatomic, assign) NSTimeInterval offset;
@property(nonatomic, retain) NSString *apiFramework;
@property(nonatomic, retain) CompositeElement *iconClicks;

@end
