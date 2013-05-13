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

@interface NonlinearAd : NSObject
{
@private
    NSString *type;
    NSString *uriString;
    NSString *idString;
    int32_t width;
    int32_t height;
    int32_t expandedWidth;
    int32_t expandedHeight;
    BOOL scalable;
    BOOL maintainAspectRatio;
    NSTimeInterval minSuggestedDuration;
    NSString *apiFramework;
    NSString *trackingId;
    BOOL xmlEncoded;
    NSString *event;
    NSString *creativeType;
}

@property(nonatomic, retain) NSString *type;
@property(nonatomic, retain) NSString *uriString;
@property(nonatomic, retain) NSString *idString;
@property(nonatomic, assign) int32_t width;
@property(nonatomic, assign) int32_t height;
@property(nonatomic, assign) int32_t expandedWidth;
@property(nonatomic, assign) int32_t expandedHeight;
@property(nonatomic, assign) BOOL scalable;
@property(nonatomic, assign) BOOL maintainAspectRatio;
@property(nonatomic, assign) NSTimeInterval minSuggestedDuration;
@property(nonatomic, retain) NSString *apiFramework;
@property(nonatomic, retain) NSString *trackingId;
@property(nonatomic, assign) BOOL xmlEncoded;
@property(nonatomic, retain) NSString *event;
@property(nonatomic, retain) NSString *creativeType;

@end
