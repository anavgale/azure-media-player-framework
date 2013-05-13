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

@interface MediaFile : NSObject
{
@private
    NSString *uriString;
    NSString *idString;
    NSString *delivery;
    NSString *type;
    int32_t bitrate;
    int32_t minBitrate;
    int32_t maxBitrate;
    int32_t width;
    int32_t height;
    BOOL scalable;
    BOOL maintainAspectRatio;
    NSString *codec;
    NSString *apiFramework;
}

@property(nonatomic, retain) NSString *uriString;
@property(nonatomic, retain) NSString *idString;
@property(nonatomic, retain) NSString *delivery;
@property(nonatomic, retain) NSString *type;
@property(nonatomic, assign) int32_t bitrate;
@property(nonatomic, assign) int32_t minBitrate;
@property(nonatomic, assign) int32_t maxBitrate;
@property(nonatomic, assign) int32_t width;
@property(nonatomic, assign) int32_t height;
@property(nonatomic, assign) BOOL scalable;
@property(nonatomic, assign) BOOL maintainAspectRatio;
@property(nonatomic, retain) NSString *codec;
@property(nonatomic, retain) NSString *apiFramework;

@end
