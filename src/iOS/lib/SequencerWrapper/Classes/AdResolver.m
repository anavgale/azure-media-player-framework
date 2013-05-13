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

#import "AdResolver_Internal.h"
#import "VASTParser_Internal.h"
#import "VMAPParser_Internal.h"
#import "Sequencer_Internal.h"
#import "Creative.h"
#import "TrackingEvent.h"
#import "VideoClick.h"
#import "Icon.h"
#import "MediaFile.h"
#import "CompanionAd.h"
#import "NonlinearAd.h"
#import "Trace.h"

// Define constant like: NSString * const NotImplementedException = @"NotImplementedException";

NSString * const ManifestDownloadedNotification = @"ManifestDownloadedNotification";
NSString * const ManifestDownloadedArgsUserInfoKey = @"ManifestDownloadedArgs";

@implementation ManifestDownloadedEventArgs

#pragma mark -
#pragma mark Properties:

@synthesize manifest;
@synthesize error;

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    [manifest release];
    [error release];
    [super dealloc];
}

@end

@implementation AdResolver

@synthesize lastError;
@synthesize vastParser;
@synthesize vmapParser;

#pragma mark -
#pragma mark Internal class methods:

#pragma mark -
#pragma mark Private instance methods:

- (NSString *) callJavaScriptWithString:(NSString *)aString
{
    SEQUENCER_LOG(@"JavaScript call: %s", [aString cStringUsingEncoding:NSUTF8StringEncoding]);
    NSString *result = [webView stringByEvaluatingJavaScriptFromString:aString];
    
    SEQUENCER_LOG(@"JavaScript result is %@", result);
    
    NSError *error = [Sequencer parseJSONException:result];
    if (nil != error)
    {
        self.lastError = error;
        result = nil;
    }
    
    return result;
}

- (void) setDownloadError
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:@"PLAYER_SEQUENCER:DownloadError" forKey:NSLocalizedDescriptionKey];
    [userInfo setObject:@"Failed to create connection for download" forKey:NSLocalizedFailureReasonErrorKey];
    self.lastError = [NSError errorWithDomain:@"PLAYER_SEQUENCER" code:0 userInfo:userInfo];
    [userInfo release];
    
    [pool release];
}

- (void) sendManifestDownloadedNotification:(NSString *)manifest withError:(NSError *)error
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    
    ManifestDownloadedEventArgs *eventArgs = [[ManifestDownloadedEventArgs alloc] init];
    eventArgs.manifest = manifest;
    eventArgs.error = error;
    
    NSMutableDictionary *userInfo = [[NSMutableDictionary alloc] init];
    [userInfo setObject:eventArgs forKey:ManifestDownloadedArgsUserInfoKey];
    
    [eventArgs release];
    
    NSNotification *notification = [NSNotification notificationWithName:ManifestDownloadedNotification object:self userInfo:userInfo];
    [[NSNotificationCenter defaultCenter] performSelectorOnMainThread:@selector(postNotification:) withObject:notification waitUntilDone:NO];
    
    [userInfo release];
    
    [pool release];
}

#pragma mark -
#pragma mark Notification callbacks:

- (void) connection:(NSURLConnection *)connection didReceiveData:(NSData *)data
{
    if (connection == downloadConnection)
    {
        [downloadData appendData:data];
    }
}

- (void) connectionDidFinishLoading:(NSURLConnection *)connection
{
    if (connection == downloadConnection)
    {
        [downloadConnection release];
        downloadConnection = nil;
        
        NSString *result = [[NSString alloc] initWithData:downloadData encoding:NSASCIIStringEncoding];
        [self sendManifestDownloadedNotification:result withError:nil];
        [result release];
        
        [downloadData release];
        downloadData = nil;
    }
}

- (void) connection:(NSURLConnection *)connection didFailWithError:(NSError *)error
{
    if (connection == downloadConnection)
    {
        self.lastError = error;
        [self sendManifestDownloadedNotification:nil withError:error];
        
        [downloadConnection release];
        downloadConnection = nil;
        [downloadData release];
        downloadData = nil;
    }
}

#pragma mark -
#pragma mark Public instance methods:

- (id) initWithUIWebView:(UIWebView *)aWebView
{
    self = [super init];
    
    if (self){
        webView = aWebView;
        vastParser = [[VASTParser alloc] initWithUIWebView:aWebView];
        vmapParser = [[VMAPParser alloc] initWithUIWebView:aWebView];
        downloadData = nil;
        downloadConnection = nil;
    }
        
    return self;
}

//
// download a manifest (VAST/VMAP/others) asynchronously
//
// Arguments:
// [aUrl]: the download url
//
// Returns: YES for success and NO for failure
//
- (BOOL) downloadManifestAsyncWithURL:(NSURL *)aUrl
{
    BOOL success = NO;
    downloadData = [[NSMutableData alloc] init];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:aUrl];
    downloadConnection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
    
    if (nil != downloadConnection)
    {
        SEQUENCER_LOG(@"start downloading for url %@", aUrl);
        success = YES;
    }
    else
    {
        [self setDownloadError];
    }
    
    return success;
}

//
// download a manifest (VAST/VMAP/others) synchronously
//
// Arguments:
// [manifest]: the downloaded manifest in string format
// [aUrl]: the download url
//
// Returns: YES for success and NO for failure
//
- (BOOL) downloadManifest:(NSString **)manifest withURL:(NSURL *)aUrl
{
    BOOL success = YES;
    
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSURLRequest *request = [NSURLRequest requestWithURL:aUrl];

    SEQUENCER_LOG(@"start downloading for url %@", aUrl);
    
    downloadData = (NSMutableData *)[NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    
    if (nil == error)
    {        
        *manifest = [[NSString alloc] initWithData:downloadData encoding:NSASCIIStringEncoding];
    }
    else
    {
        self.lastError = error;
        success = NO;
    }

    // downloadData is an autorelease object, setting it to nil is enough
    downloadData = nil;
    
    return success;
}

//
// release an AdResolver entry
//
// Arguments:
// [entryId]: the entry Id of AdResolver entry to be released
//
// Returns: YES for success and NO for failure
//
- (BOOL) releaseEntry:(int32_t)entryId
{
    NSString *result = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"releaseEntry\\\", "
                           "\\\"params\\\": \\\"%d\\\" }\")",
                           entryId] autorelease];
    result = [self callJavaScriptWithString:function];
    
    return (nil != result);
}

//
// get a generic element list from the VAST entry
//
// Arguments:
// [elementList]: the list of the generic element with a specified XML path
// [xmlPath]: the array of Element name:count strings that lead a particular element
//
// Returns: YES for success and NO for failure
//
- (BOOL) getElementList:(NSArray **)elementList withPath:(NSArray *)xmlPath;
{
    BOOL success = YES;
    
    /// TODO: to be implemented.
    
    return success;
}

#pragma mark -
#pragma mark Properties:

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    SEQUENCER_LOG(@"AdResolver dealloc called.");
    
    [lastError release];
    [vastParser release];
    [vmapParser release];
    if (nil != downloadData)
    {
        [downloadData release];
    }
    if (nil != downloadConnection)
    {
        [downloadConnection release];
    }
    
    [super dealloc];
}

@end
