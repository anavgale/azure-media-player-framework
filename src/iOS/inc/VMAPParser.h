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

@class AdSource;

@interface VMAPParser : NSObject
{
@private
    UIWebView *webView;    
    NSError *lastError;
}

@property(nonatomic, retain) NSError *lastError;

- (BOOL) createEntry:(int32_t *)entryId withManifest:(NSString *)aManifest;
- (BOOL) getAdBreakList:(NSArray **)adBreakList withEntryId:(int32_t)entryId;
- (BOOL) getAdSource:(AdSource **)adSource withEntryId:(int32_t)entryId adBreakOrdinal:(int32_t)ordinal;
- (BOOL) createVASTEntryFromAdBreak:(int32_t *)vastId withEntryId:(int32_t)entryId adBreakOrdinal:(int32_t)ordinal;
- (BOOL) getTrackingEventsList:(NSArray **)eventsList withEntryId:(int32_t)entryId adBreakOrdinal:(int32_t)ordinal;
- (BOOL) getExtensionsList:(NSArray **)extensionsList withEntryId:(int32_t)entryId adBreakOrdinal:(int32_t)ordinal;

@end
