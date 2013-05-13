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
#import <UIKit/UIkit.h>
#import "Ad.h"

@interface VASTParser : NSObject
{
@private
    UIWebView *webView;    
    NSError *lastError;
}

@property(nonatomic, retain) NSError *lastError;

- (BOOL) createEntry:(int32_t *)entryId withManifest:(NSString *)aManifest;
- (BOOL) getAdList:(NSArray **)adList withEntryId:(int32_t)entryId;
- (BOOL) getCreativeList:(NSArray **)creativeList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal adType:(VASTAdType)type;
- (BOOL) getLinearTrackingEventsList:(NSArray **)eventList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal;
- (BOOL) getVideoClicksList:(NSArray **)videoClicksList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal;
- (BOOL) getIconsList:(NSArray **)iconsList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal;
- (BOOL) getMediaFileList:(NSArray **)mediaFileList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal;
- (BOOL) getCompanionAdsList:(NSArray **)adList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal;
- (BOOL) getNonLinearAdsList:(NSArray **)adList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal;

@end
