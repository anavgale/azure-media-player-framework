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
    VASTData,
    CustomAdData,
    AdTagURI
} VMAPAdSourceType;

@interface AdSource : NSObject
{
@private
    VMAPAdSourceType type;
    NSString *idString;
    BOOL allowMultipleAds;
    BOOL followRedirects;
    NSString *templateType;
    NSString *value;
    CompositeElement *element;
}

@property(nonatomic, assign) VMAPAdSourceType type;
@property(nonatomic, retain) NSString *idString;
@property(nonatomic, assign) BOOL allowMultipleAds;
@property(nonatomic, assign) BOOL followRedirects;
@property(nonatomic, retain) NSString *templateType;
@property(nonatomic, retain) NSString *value;
@property(nonatomic, retain) CompositeElement *element;

@end
