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

@interface CompositeElement : NSObject
{
@private
    NSString *name;
    BOOL expanded;
    int32_t elementCount;
    NSArray *elementList;
    NSDictionary *attrs;
}

@property(nonatomic, retain) NSString *name;
@property(nonatomic, assign) BOOL expanded;
@property(nonatomic, assign) int32_t elementCount;
@property(nonatomic, retain) NSArray *elementList;
@property(nonatomic, retain) NSDictionary *attrs;

@end
