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

@class VASTParser;
@class VMAPParser;

@interface ManifestDownloadedEventArgs : NSObject
{
@private
    NSString *manifest;
    NSError *error;
}

@property(nonatomic, retain) NSString *manifest;
@property(nonatomic, retain) NSError *error;

@end;

@interface AdResolver : NSObject
{
@private
    NSError *lastError;
    UIWebView *webView;
    VASTParser *vastParser;
    VMAPParser *vmapParser;
    NSMutableData *downloadData;
    NSURLConnection *downloadConnection;
}

@property(nonatomic, retain) NSError *lastError;
@property(nonatomic, readonly) VASTParser *vastParser;
@property(nonatomic, readonly) VMAPParser *vmapParser;
@property(nonatomic, readonly) BOOL isReady;

- (BOOL) downloadManifestAsyncWithURL:(NSURL *)aUrl;
- (BOOL) downloadManifest:(NSString **)manifest withURL:(NSURL *)aUrl;
- (BOOL) releaseEntry:(int32_t)entryId;
- (BOOL) getElementList:(NSArray **)elementList withPath:(NSArray *)xmlPath;

@end

extern NSString * const ManifestDownloadedNotification;
extern NSString * const ManifestDownloadedArgsUserInfoKey;
