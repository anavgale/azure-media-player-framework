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

#import "VMAPParser_Internal.h"
#import "Sequencer_Internal.h"
#import "AdBreak.h"
#import "AdSource.h"
#import "TrackingEvent.h"
#import "VMAPExtension.h"
#import "Trace.h"

// Define constant like: NSString * const NotImplementedException = @"NotImplementedException";

@implementation VMAPParser

@synthesize lastError;

#pragma mark -
#pragma mark Internal class methods:


#pragma mark -
#pragma mark Private instance methods:

- (NSTimeInterval) secondsFromHMS:(NSString *)hmsString
{
    // handle start or end first
    if ([hmsString isEqualToString:@"start"])
    {
        return 0;
    }
    else if ([hmsString isEqualToString:@"end"])
    {
        return -1;
    }
    
    NSArray *hmsArray = [hmsString componentsSeparatedByString:@":"];
    if (3 != hmsArray.count)
    {
        return 0;
    }
    return (NSTimeInterval)(([[hmsArray objectAtIndex:0] intValue] * 60 + [[hmsArray objectAtIndex:1] intValue]) * 60 + [[hmsArray objectAtIndex:2] floatValue]);
}

- (NSArray *) parseJSONAdBreakList:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_out)
    {
        return nil;
    }
    
    NSMutableArray *adBreakList = [NSMutableArray arrayWithCapacity:[json_out count]];
    for (NSDictionary *nAdBreak in json_out)
    {
        AdBreak *adBreak = [[[AdBreak alloc] init] autorelease];
        adBreak.elementList = [nAdBreak objectForKey:@"elements"];
                
        NSDictionary *nAttrs = [nAdBreak objectForKey:@"attrs"];
        if ([NSNull null] != (NSNull *)nAttrs)
        {
            adBreak.timeOffset = [self secondsFromHMS:[nAttrs objectForKey:@"timeOffset"]];
            adBreak.breakId = [nAttrs objectForKey:@"breakId"];
            adBreak.breakType = [nAttrs objectForKey:@"breakType"];
        }
        
        [adBreakList addObject:adBreak];
    }
    
    return adBreakList;
}

- (AdSource *) parseJSONAdSource:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_array = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_array || 1 != [json_array count])
    {
        return nil;
    }
 
    NSDictionary *json_out = [json_array objectAtIndex:0];
    
    AdSource *adSource = [[AdSource alloc] init];
    NSString *type = [json_out objectForKey:@"type"];
    if ([type isEqualToString:@"VASTAdData"])
    {
        adSource.type = VASTAdData;
    }
    else if ([type isEqualToString:@"CustomAdData"])
    {
        adSource.type = CustomAdData;
    }
    else
    {
        assert([type isEqualToString:@"AdTagURI"]);
        adSource.type = AdTagURI;
    }
    
    adSource.value = [json_out objectForKey:@"value"];
    
    NSDictionary *nAttrs = [json_out objectForKey:@"attrs"];
    if ([NSNull null] != (NSNull *)nAttrs)
    {
        adSource.idString = [nAttrs objectForKey:@"id"];
        adSource.allowMultipleAds = [[nAttrs objectForKey:@"allowMultipleAds"] boolValue];
        adSource.followRedirects = [[nAttrs objectForKey:@"followRedirects"] boolValue];
        adSource.templateType = [nAttrs objectForKey:@"templateType"];        
    }
    
    NSMutableArray *nElements = [json_out objectForKey:@"elements"];
    for (NSDictionary *nElement in nElements)
    {
        adSource.element = [[[CompositeElement alloc] init] autorelease];
        adSource.element.name = [nElement objectForKey:@"name"];
        adSource.element.expanded = NO;
        adSource.element.elementCount = [[nElement objectForKey:@"elements"] intValue];
        adSource.element.attrs = [nElement objectForKey:@"attrs"];        
    }
        
    return adSource;
}

- (NSArray *) parseJSONTrackingEventsList:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_out)
    {
        return nil;
    }
    
    NSMutableArray *eventsList = [NSMutableArray arrayWithCapacity:[json_out count]];
    for (NSDictionary *nTracking in json_out)
    {
        TrackingEvent *event = [[[TrackingEvent alloc] init] autorelease];
        event.uriString = [nTracking objectForKey:@"value"];
        
        NSDictionary *nAttrs = [nTracking objectForKey:@"attrs"];
        if ([NSNull null] != (NSNull *)nAttrs)
        {
            event.event = [nAttrs objectForKey:@"event"];
        }
        
        [eventsList addObject:event];
    }
    
    return eventsList;
}

- (NSArray *) parseJSONExtensionsList:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_out)
    {
        return nil;
    }
    
    NSMutableArray *extensionsList = [NSMutableArray arrayWithCapacity:[json_out count]];
    for (NSDictionary *nExtension in json_out)
    {
        VMAPExtension *extension = [[[VMAPExtension alloc] init] autorelease];
        extension.xmlString = [nExtension objectForKey:@"value"];
        
        NSDictionary *nAttrs = [nExtension objectForKey:@"attrs"];
        if ([NSNull null] != (NSNull *)nAttrs)
        {
            extension.type = [nAttrs objectForKey:@"type"];
        }
        
        [extensionsList addObject:extension];
    }
    
    return extensionsList;
}

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

#pragma mark -
#pragma mark Notification callbacks:


#pragma mark -
#pragma mark Public instance methods:

- (id) initWithUIWebView:(UIWebView *)aWebView
{
    self = [super init];
    
    if (self){
        webView = aWebView;
    }
    
    return self;
}

//
// create a VMAP entry from the xml string
//
// Arguments:
// [entryId]: the returned entry Id of the newly created VAST entry
// [aManifest]: the VAST mainfest in the XML string format
//
// Returns: YES for success and NO for failure
//
- (BOOL) createEntry:(int32_t *)entryId withManifest:(NSString *)aManifest
{
    assert (nil != entryId);
    NSString *result = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vmap.createEntry\\\", "
                           "\\\"params\\\": \\\"%s\\\" }\")",
                           [[Sequencer jsonStringFromXmlString:aManifest] cStringUsingEncoding:NSUTF8StringEncoding]] autorelease];
    result = [self callJavaScriptWithString:function];
    
    if (nil != result)
    {
        *entryId = [result intValue];
    }
    
    return (nil != result);    
}

//
// get the AdBreak list from the VMAP entry
//
// Arguments:
// [adBreakList]: the output list of the AdBreak elements in the VMAP entry
// [entryId]: the entry Id of VMAP entry
//
// Returns: YES for success and NO for failure
//
- (BOOL) getAdBreakList:(NSArray **)adBreakList withEntryId:(int32_t)entryId
{
    NSString *result = nil;
    *adBreakList = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vmap.getAdBreakList\\\", "
                           "\\\"params\\\": { \\\"entryId\\\": %d } }\")",
                           entryId] autorelease];
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *adBreakList = [self parseJSONAdBreakList:result];
    }
    
    return (nil != result);
}

//
// get the AdSource from the VMAP entry
//
// Arguments:
// [adSource]: the output adSource element in the VMAP entry
// [entryId]: the entry Id of VMAP entry
// [ordinal]: the index of the adBreak list
//
// Returns: YES for success and NO for failure
//
- (BOOL) getAdSource:(AdSource **)adSource withEntryId:(int32_t)entryId adBreakOrdinal:(int32_t)ordinal
{
    NSString *result = nil;
    *adSource = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vmap.getAdSource\\\", "
                           "\\\"params\\\": "
                           "{ \\\"entryId\\\": %d, "
                           "\\\"adBreakOrdinal\\\": %d } }\")",
                           entryId,
                           ordinal] autorelease];
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *adSource = [self parseJSONAdSource:result];
    }
    
    return (nil != result);
}

//
// create a VASTEntry for a given AdBreak which is assumed to contain an AdSource/VASTAdData element.
//
// Arguments:
// [vastId]: the output VAST entry Id
// [entryId]: the entry Id of VMAP entry
// [ordinal]: the index of the adBreak list
//
// Returns: YES for success and NO for failure
//
- (BOOL) createVASTEntryFromAdBreak:(int32_t *)vastId withEntryId:(int32_t)entryId adBreakOrdinal:(int32_t)ordinal
{
    NSString *result = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vmap.createVASTEntryFromAdBreak\\\", "
                           "\\\"params\\\": "
                           "{ \\\"entryId\\\": %d, "
                           "\\\"adBreakOrdinal\\\": %d } }\")",
                           entryId,
                           ordinal] autorelease];
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *vastId = [result intValue];
    }
    
    return (nil != result);
}

//
// get the list of Tracking elements for the TrackingEvents element in a given AdBreak
//
// Arguments:
// [eventsList]: the output Tracking element list
// [entryId]: the entry Id of VMAP entry
// [ordinal]: the index of the adBreak list
//
// Returns: YES for success and NO for failure
//
- (BOOL) getTrackingEventsList:(NSArray **)eventsList withEntryId:(int32_t)entryId adBreakOrdinal:(int32_t)ordinal
{
    NSString *result = nil;
    *eventsList = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vmap.getTrackingEventsList\\\", "
                           "\\\"params\\\": "
                           "{ \\\"entryId\\\": %d, "
                           "\\\"adBreakOrdinal\\\": %d } }\")",
                           entryId,
                           ordinal] autorelease];
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *eventsList = [self parseJSONTrackingEventsList:result];
    }
    
    return (nil != result);
}

//
// get the list of Extension elements for the Extensions element in a given AdBreak
//
// Arguments:
// [extensionsList]: the output Extension element list
// [entryId]: the entry Id of VMAP entry
// [ordinal]: the index of the adBreak list
//
// Returns: YES for success and NO for failure
//
- (BOOL) getExtensionsList:(NSArray **)extensionsList withEntryId:(int32_t)entryId adBreakOrdinal:(int32_t)ordinal
{
    NSString *result = nil;
    *extensionsList = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vmap.getExtensionsList\\\", "
                           "\\\"params\\\": "
                           "{ \\\"entryId\\\": %d, "
                           "\\\"adBreakOrdinal\\\": %d } }\")",
                           entryId,
                           ordinal] autorelease];
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *extensionsList = [self parseJSONExtensionsList:result];
    }
    
    return (nil != result);
}

#pragma mark -
#pragma mark Properties:

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    SEQUENCER_LOG(@"VMAPParser dealloc called.");
    
    [lastError release];
    
    [super dealloc];
}

@end
