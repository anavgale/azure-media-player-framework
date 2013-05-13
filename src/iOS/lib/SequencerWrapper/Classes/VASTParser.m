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

#import "VASTParser_Internal.h"
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

@implementation VASTParser

@synthesize lastError;

#pragma mark -
#pragma mark Internal class methods:


#pragma mark -
#pragma mark Private instance methods:

- (NSTimeInterval) secondsFromHMS:(NSString *)hmsString
{
    NSArray *hmsArray = [hmsString componentsSeparatedByString:@":"];
    if (3 != hmsArray.count)
    {
        return 0;
    }
    return (NSTimeInterval)(([[hmsArray objectAtIndex:0] intValue] * 60 + [[hmsArray objectAtIndex:1] intValue]) * 60 + [[hmsArray objectAtIndex:2] floatValue]);
}

- (NSArray *) parseJSONAdList:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_out)
    {
        return nil;
    }
    
    NSMutableArray *adList = [NSMutableArray arrayWithCapacity:[json_out count]];
    for (NSDictionary *nAd in json_out)
    {
        Ad *ad = [[[Ad alloc] init] autorelease];
        NSString *nType = [nAd objectForKey:@"type"];
        if ([nType isEqualToString:@"InLine"])
        {
            ad.type = InLine;
        }
        else
        {
            ad.type = Wrapper;
        }
        
        NSDictionary *nParentAttrs = [nAd objectForKey:@"parentAttrs"];
        if ([NSNull null] != (NSNull *)nParentAttrs)
        {
            ad.idString = [nParentAttrs objectForKey:@"id"];
            if ([nParentAttrs objectForKey:@"sequence"])
            {
                ad.sequence = [[nParentAttrs objectForKey:@"sequence"] intValue];
            }
            else
            {
                ad.sequence = -1;
            }
        }
        
        NSMutableArray *nElements = [nAd objectForKey:@"elements"];
        if ([NSNull null] != (NSNull *)nElements)
        {
            for (NSDictionary *nElement in nElements)
            {
                if ([NSNull null] == (NSNull *)nElement)
                {
                    continue;
                }
                
                NSString *elementName = [nElement objectForKey:@"name"];
                if ([elementName isEqualToString:@"AdSystem"])
                {
                    ad.adSystem = [nElement objectForKey:@"value"];
                }
                else if ([elementName isEqualToString:@"AdTitle"])
                {
                    ad.adTitle = [nElement objectForKey:@"value"];
                }
                else if ([elementName isEqualToString:@"Description"])
                {
                    ad.description = [nElement objectForKey:@"value"];
                }
                else if ([elementName isEqualToString:@"Error"])
                {
                    ad.error = [nElement objectForKey:@"value"];
                }
                else if ([elementName isEqualToString:@"Impression"])
                {
                    ad.impression = [nElement objectForKey:@"value"];
                }
                else if ([elementName isEqualToString:@"Creatives"])
                {
                    ad.creatives = [[[CompositeElement alloc] init] autorelease];
                    ad.creatives.name = @"Creatives";
                    ad.creatives.expanded = NO;
                    ad.creatives.elementCount = [[nElement objectForKey:@"elements"] intValue];
                }
                else if ([elementName isEqualToString:@"Extensions"])
                {
                    ad.extensions = [[[CompositeElement alloc] init] autorelease];
                    ad.extensions.name = @"Extensions";
                    ad.extensions.expanded = NO;
                    ad.extensions.elementCount = [[nElement objectForKey:@"elements"] intValue];
                }
                else if ([elementName isEqualToString:@"Advertiser"])
                {
                    ad.advertiser = [nElement objectForKey:@"value"];
                }
                else if ([elementName isEqualToString:@"Pricing"])
                {
                    ad.pricing = [nElement objectForKey:@"value"];
                }
                else if ([elementName isEqualToString:@"Survey"])
                {
                    ad.survey = [nElement objectForKey:@"value"];
                }
                else if ([elementName isEqualToString:@"VASTAdTagURI"])
                {
                    ad.adTagURI = [nElement objectForKey:@"value"];
                }
            }
        }
        
        [adList addObject:ad];
    }
     
    return adList;
}

- (NSArray *) parseJSONCreativeList:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_out)
    {
        return nil;
    }
    
    NSMutableArray *creativeList = [NSMutableArray arrayWithCapacity:[json_out count]];
    for (NSDictionary *nCreative in json_out)
    {
        Creative *creative = [[[Creative alloc] init] autorelease];
        NSString *nType = [nCreative objectForKey:@"type"];
        if ([nType isEqualToString:@"CreativeExtensions"])
        {
            creative.type = CreativeExtensions;
        }
        else if ([nType isEqualToString:@"Linear"])
        {
            creative.type = Linear;
        }
        else if ([nType isEqualToString:@"CompanionAds"])
        {
            creative.type = CompanionAds;
        }
        else
        {
            creative.type = NonlinearAds;
        }
       
        NSDictionary *nParentAttrs = [nCreative objectForKey:@"parentAttrs"];
        if ([NSNull null] != (NSNull *)nParentAttrs)
        {
            creative.idString = [nParentAttrs objectForKey:@"id"];
            creative.sequence = [[nParentAttrs objectForKey:@"sequence"] intValue];
            creative.adID = [nParentAttrs objectForKey:@"adID"];
            creative.apiFramework = [nParentAttrs objectForKey:@"apiFramework"];
        }

        NSDictionary *nAttrs = [nCreative objectForKey:@"attrs"];
        if ([NSNull null] != (NSNull *)nAttrs)
        {
            creative.skipoffset = [[nAttrs objectForKey:@"skipoffset"] intValue];
            NSString *nRequired = [nAttrs objectForKey:@"required"];
            if ([nRequired isEqualToString:@"all"])
            {
                creative.required = All;
            }
            else if ([nRequired isEqualToString:@"Any"])
            {
                creative.required = Any;
            }
            else
            {
                // The default value
                creative.required = None;
            }
        }
        
        NSMutableArray *nElements = [nCreative objectForKey:@"elements"];
        if ([NSNull null] != (NSNull *)nElements)
        {
            for (NSDictionary *nElement in nElements)
            {
                if ([NSNull null] == (NSNull *)nElement)
                {
                    continue;
                }
                
                NSString *elementName = [nElement objectForKey:@"name"];
                if ([elementName isEqualToString:@"CreativeExtension"])
                {
                    creative.creativeExtension = [nElement objectForKey:@"value"];
                }
                else if ([elementName isEqualToString:@"AdParameters"])
                {
                    creative.adParameters = [nElement objectForKey:@"value"];
                    nAttrs = [nElement objectForKey:@"attrs"];
                    creative.xmlEncoded = [[nAttrs objectForKey:@"xmlEncoded"] isEqualToString:@"true"];
                }
                else if ([elementName isEqualToString:@"Duration"])
                {
                    creative.duration = [self secondsFromHMS:[nElement objectForKey:@"value"]];
                }
                else if ([elementName isEqualToString:@"MediaFiles"])
                {
                    creative.mediaFiles = [[[CompositeElement alloc] init] autorelease];
                    creative.mediaFiles.name = @"MediaFiles";
                    creative.mediaFiles.expanded = NO;
                    creative.mediaFiles.elementCount = [[nElement objectForKey:@"elements"] intValue];
                }
                else if ([elementName isEqualToString:@"TrackingEvents"])
                {
                    creative.trackingEvents = [[[CompositeElement alloc] init] autorelease];
                    creative.trackingEvents.name = @"TrackingEvents";
                    creative.trackingEvents.expanded = NO;
                    creative.trackingEvents.elementCount = [[nElement objectForKey:@"elements"] intValue];
                }
                else if ([elementName isEqualToString:@"VideoClicks"])
                {
                    creative.videoClicks = [[[CompositeElement alloc] init] autorelease];
                    creative.videoClicks.name = @"VideoClicks";
                    creative.videoClicks.expanded = NO;
                    creative.videoClicks.elementCount = [[nElement objectForKey:@"elements"] intValue];
                }
                else if ([elementName isEqualToString:@"Icons"])
                {
                    creative.icons = [[[CompositeElement alloc] init] autorelease];
                    creative.icons.name = @"Icons";
                    creative.icons.expanded = NO;
                    creative.icons.elementCount = [[nElement objectForKey:@"elements"] intValue];
                }
                else if ([elementName isEqualToString:@"Companion"])
                {
                    creative.companion = [[[CompositeElement alloc] init] autorelease];
                    creative.companion.name = @"Companion";
                    creative.companion.expanded = NO;
                    creative.companion.elementCount = [[nElement objectForKey:@"elements"] intValue];
                }
                else if ([elementName isEqualToString:@"Nonlinear"])
                {
                    creative.nonlinear = [[[CompositeElement alloc] init] autorelease];
                    creative.nonlinear.name = @"Nonlinear";
                    creative.nonlinear.expanded = NO;
                    creative.nonlinear.elementCount = [[nElement objectForKey:@"elements"] intValue];
                }             
            }
        }
        
        [creativeList addObject:creative];
    }
    
    return creativeList;
}

- (NSArray *) parseJSONLinearTrackingEventsList:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_out)
    {
        return nil;
    }
    
    NSMutableArray *eventList = [NSMutableArray arrayWithCapacity:[json_out count]];
    for (NSDictionary *nTrackingEvent in json_out)
    {
        TrackingEvent *trackingEvent = [[[TrackingEvent alloc] init] autorelease];
        trackingEvent.uriString = [nTrackingEvent objectForKey:@"value"];
                
        NSDictionary *nAttrs = [nTrackingEvent objectForKey:@"attrs"];
        if ([NSNull null] != (NSNull *)nAttrs)
        {
            trackingEvent.event = [nAttrs objectForKey:@"event"];
        }
                
        [eventList addObject:trackingEvent];
    }
    
    return eventList;
}

- (NSArray *) parseJSONVideoClicksList:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_out)
    {
        return nil;
    }
    
    NSMutableArray *videoClicksList = [NSMutableArray arrayWithCapacity:[json_out count]];
    for (NSDictionary *nVideoClick in json_out)
    {
        VideoClick *videoClick = [[[VideoClick alloc] init] autorelease];
        videoClick.uriString = [nVideoClick objectForKey:@"value"];
        NSString *name = [nVideoClick objectForKey:@"name"];
        if ([name isEqualToString:@"ClickThrough"])
        {
            videoClick.type = ClickThrough;
        }
        else if ([name isEqualToString:@"ClickTracking"])
        {
            videoClick.type = ClickTracking;
        }
        else
        {
            videoClick.type = CustomClick;
        }
        
        NSDictionary *nAttrs = [nVideoClick objectForKey:@"attrs"];
        if ([NSNull null] != (NSNull *)nAttrs)
        {
            videoClick.idString = [nAttrs objectForKey:@"id"];
        }
        
        [videoClicksList addObject:videoClick];
    }
    
    return videoClicksList;
}

- (NSArray *) parseJSONIconsList:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_out)
    {
        return nil;
    }
    
    NSMutableArray *iconsList = [NSMutableArray arrayWithCapacity:[json_out count]];
    for (NSDictionary *nIcon in json_out)
    {
        Icon *icon = [[[Icon alloc] init] autorelease];
        icon.type = [nIcon objectForKey:@"type"];
        icon.uriString = [nIcon objectForKey:@"value"];
        
        NSDictionary *nParentAttrs = [nIcon objectForKey:@"parentAttrs"];
        if ([NSNull null] != (NSNull *)nParentAttrs)
        {
            icon.program = [nParentAttrs objectForKey:@"program"];
            icon.width = [[nParentAttrs objectForKey:@"width"] intValue];
            icon.height = [[nParentAttrs objectForKey:@"height"] intValue];
            icon.xPosition = [[nParentAttrs objectForKey:@"xPosition"] intValue];
            icon.yPosition = [[nParentAttrs objectForKey:@"yPosition"] intValue];
            icon.duration = [self secondsFromHMS:[nParentAttrs objectForKey:@"duration"]];
            icon.offset = [self secondsFromHMS:[nParentAttrs objectForKey:@"offset"]];
            icon.apiFramework = [nParentAttrs objectForKey:@"apiFramework"];
        }
        
        NSDictionary *nAttrs = [nIcon objectForKey:@"attrs"];
        if ([NSNull null] != (NSNull *)nAttrs)
        {
            icon.creativeType = [nAttrs objectForKey:@"creativeType"];
        }
        
        NSMutableArray *nElements = [nIcon objectForKey:@"elements"];
        if ([NSNull null] != (NSNull *)nElements)
        {
            for (NSDictionary *nElement in nElements)
            {
                if ([NSNull null] == (NSNull *)nElement)
                {
                    continue;
                }
                
                NSString *elementName = [nElement objectForKey:@"name"];
                if ([elementName isEqualToString:@"IconClicks"])
                {
                    icon.iconClicks = [[[CompositeElement alloc] init] autorelease];
                    icon.iconClicks.name = @"IconClicks";
                    icon.iconClicks.expanded = NO;
                    icon.iconClicks.elementCount = [[nElement objectForKey:@"elements"] intValue];
                }
            }
        }
        
        [iconsList addObject:icon];
    }
    
    return iconsList;
}

- (NSArray *) parseJSONMediaFileList:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_out)
    {
        return nil;
    }
    
    NSMutableArray *mediaFileList = [NSMutableArray arrayWithCapacity:[json_out count]];
    for (NSDictionary *nMediaFile in json_out)
    {
        MediaFile *mediaFile = [[[MediaFile alloc] init] autorelease];
        mediaFile.uriString = [nMediaFile objectForKey:@"value"];
        
        NSDictionary *nAttrs = [nMediaFile objectForKey:@"attrs"];
        if ([NSNull null] != (NSNull *)nAttrs)
        {
            mediaFile.idString = [nAttrs objectForKey:@"id"];
            mediaFile.delivery = [nAttrs objectForKey:@"delivery"];
            mediaFile.type = [nAttrs objectForKey:@"type"];
            mediaFile.bitrate = [[nAttrs objectForKey:@"bitrate"] intValue];
            mediaFile.minBitrate = [[nAttrs objectForKey:@"minBitrate"] intValue];
            mediaFile.maxBitrate = [[nAttrs objectForKey:@"maxBitrate"] intValue];
            mediaFile.width = [[nAttrs objectForKey:@"width"] intValue];
            mediaFile.height = [[nAttrs objectForKey:@"height"] intValue];
            mediaFile.scalable = [[nAttrs objectForKey:@"scalable"] boolValue];
            mediaFile.maintainAspectRatio = [[nAttrs objectForKey:@"maintainAspectRatio"] boolValue];
            mediaFile.codec = [nAttrs objectForKey:@"codec"];
            mediaFile.apiFramework = [nAttrs objectForKey:@"apiFramework"];
        }
        
        [mediaFileList addObject:mediaFile];
    }
    
    return mediaFileList;
}

- (NSArray *) parseJSONCompanionAdsList:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_out)
    {
        return nil;
    }
    
    NSMutableArray *adsList = [NSMutableArray arrayWithCapacity:[json_out count]];
    for (NSDictionary *nCompanionAd in json_out)
    {
        CompanionAd *companionAd = [[[CompanionAd alloc] init] autorelease];
        companionAd.type = [nCompanionAd objectForKey:@"type"];
        companionAd.uriString = [nCompanionAd objectForKey:@"value"];
        
        NSDictionary *nParentAttrs = [nCompanionAd objectForKey:@"parentAttrs"];
        if ([NSNull null] != (NSNull *)nParentAttrs)
        {
            companionAd.idString = [nParentAttrs objectForKey:@"id"];
            companionAd.width = [[nParentAttrs objectForKey:@"width"] intValue];
            companionAd.height = [[nParentAttrs objectForKey:@"height"] intValue];
            companionAd.assetWidth = [[nParentAttrs objectForKey:@"assetWidth"] intValue];
            companionAd.assetHeight = [[nParentAttrs objectForKey:@"assetHeight"] intValue];
            companionAd.expandedWidth = [[nParentAttrs objectForKey:@"expandedWidth"] intValue];
            companionAd.expandedHeight = [[nParentAttrs objectForKey:@"expandedHeight"] intValue];
            companionAd.apiFramework = [nParentAttrs objectForKey:@"apiFramework"];
        }
        
        NSDictionary *nAttrs = [nCompanionAd objectForKey:@"attrs"];
        if ([NSNull null] != (NSNull *)nAttrs)
        {
            companionAd.creativeType = [nAttrs objectForKey:@"creativeType"];
            companionAd.xmlEncoded = [[nAttrs objectForKey:@"xmlEncoded"] boolValue];
            companionAd.clickTrackingId = [nParentAttrs objectForKey:@"id"];
        }
        
        NSMutableArray *nElements = [nCompanionAd objectForKey:@"elements"];
        if ([NSNull null] != (NSNull *)nElements)
        {
            for (NSDictionary *nElement in nElements)
            {
                if ([NSNull null] == (NSNull *)nElement)
                {
                    continue;
                }
                
                NSString *elementName = [nElement objectForKey:@"name"];
                if ([elementName isEqualToString:@"Tracking"])
                {
                    companionAd.tracking = [[[CompositeElement alloc] init] autorelease];
                    companionAd.tracking.name = @"Tracking";
                    companionAd.tracking.expanded = NO;
                    companionAd.tracking.elementCount = [[nElement objectForKey:@"elements"] intValue];
                }
            }
        }
        
        [adsList addObject:companionAd];
    }
    
    return adsList;
}

- (NSArray *) parseJSONNonLinearAdsList:(NSString *)jsonResult
{
    NSData* data = [jsonResult dataUsingEncoding:[NSString defaultCStringEncoding]];
    NSError* error = nil;
    NSMutableArray* json_out = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&error];
    if (nil == json_out)
    {
        return nil;
    }
    
    NSMutableArray *adsList = [NSMutableArray arrayWithCapacity:[json_out count]];
    for (NSDictionary *nNonLinearAd in json_out)
    {
        NonlinearAd *nonlinearAd = [[[NonlinearAd alloc] init] autorelease];
        nonlinearAd.type = [nNonLinearAd objectForKey:@"type"];
        nonlinearAd.uriString = [nNonLinearAd objectForKey:@"value"];
        
        NSDictionary *nParentAttrs = [nNonLinearAd objectForKey:@"parentAttrs"];
        if ([NSNull null] != (NSNull *)nParentAttrs)
        {
            nonlinearAd.idString = [nParentAttrs objectForKey:@"id"];
            nonlinearAd.width = [[nParentAttrs objectForKey:@"width"] intValue];
            nonlinearAd.height = [[nParentAttrs objectForKey:@"height"] intValue];
            nonlinearAd.expandedWidth = [[nParentAttrs objectForKey:@"expandedWidth"] intValue];
            nonlinearAd.expandedHeight = [[nParentAttrs objectForKey:@"expandedHeight"] intValue];
            nonlinearAd.scalable = [[nParentAttrs objectForKey:@"scalable"] boolValue];
            nonlinearAd.maintainAspectRatio = [[nParentAttrs objectForKey:@"maintainAspectRatio"] boolValue];
            nonlinearAd.minSuggestedDuration = [self secondsFromHMS:[nParentAttrs objectForKey:@"minSuggestedDuration"]];
            nonlinearAd.apiFramework = [nParentAttrs objectForKey:@"apiFramework"];
        }
        
        NSDictionary *nAttrs = [nNonLinearAd objectForKey:@"attrs"];
        if ([NSNull null] != (NSNull *)nAttrs)
        {
            nonlinearAd.creativeType = [nAttrs objectForKey:@"creativeType"];
            nonlinearAd.xmlEncoded = [[nAttrs objectForKey:@"xmlEncoded"] boolValue];
            nonlinearAd.trackingId = [nAttrs objectForKey:@"id"];
            nonlinearAd.event = [nAttrs objectForKey:@"event"];
        }
                
        [adsList addObject:nonlinearAd];
    }
    
    return adsList;
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
// download a manifest (VAST/VMAP/others) asynchronously
//
// Arguments:
// [aUrl]: the download url
//
// Returns: YES for success and NO for failure
//
- (BOOL) downloadManifestAsyncWithURL:(NSURL *)aUrl
{
    BOOL success = YES;
    
    return success;
}

//
// create a VAST entry from the xml string
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
                           "\"{\\\"func\\\": \\\"vast.createEntry\\\", "
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
// get the Ad list from the VAST entry
//
// Arguments:
// [adList]: the output list of the Ad elements in the VAST entry
// [entryId]: the entry Id of VAST entry
//
// Returns: YES for success and NO for failure
//
- (BOOL) getAdList:(NSArray **)adList withEntryId:(int32_t)entryId
{
    NSString *result = nil;
    *adList = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vast.getAdList\\\", "
                           "\\\"params\\\": { \\\"entryId\\\": %d } }\")",
                           entryId] autorelease];
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *adList = [self parseJSONAdList:result];
    }
    
    return (nil != result);    
}

//
// get the Creative list from the VAST entry
//
// Arguments:
// [creativeList]: the output list of the Creative elements in the VAST entry
// [entryId]: the entry Id of VAST entry
// [ordinal]: indicate which ad in multiple ads
// [type]: the type of the ad.
//
// Returns: YES for success and NO for failure
//
- (BOOL) getCreativeList:(NSArray **)creativeList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal adType:(VASTAdType)type
{
    NSString *result = nil;
    *creativeList = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vast.getCreativeList\\\", "
                           "\\\"params\\\": "
                           "{ \\\"entryId\\\": %d, "
                           "\\\"adOrdinal\\\": %d, "
                           "\\\"adType\\\": %@ } }\")",
                           entryId,
                           ordinal,
                           (InLine == type) ? @"\\\"InLine\\\"" : @"\\\"Wrapper\\\""] autorelease];
    
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *creativeList = [self parseJSONCreativeList:result];
    }
    
    return (nil != result);
}

//
// get the TrackingEvents list from the VAST entry
//
// Arguments:
// [eventList]: the TrackingEvents list of the Creative elements in the VAST entry
// [entryId]: the entry Id of VAST entry
// [ordinal]: indicate which ad in multiple ads
// [creativeOrdinal]: indicate which creative in multiple creatives
//
// Returns: YES for success and NO for failure
//
- (BOOL) getLinearTrackingEventsList:(NSArray **)eventList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal
{
    NSString *result = nil;
    *eventList = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vast.getLinearTrackingEventsList\\\", "
                           "\\\"params\\\": "
                           "{ \\\"entryId\\\": %d, "
                           "\\\"adOrdinal\\\": %d, "
                           "\\\"creativeOrdinal\\\": %d } }\")",
                           entryId,
                           ordinal,
                           creativeOrdinal] autorelease];
    
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *eventList = [self parseJSONLinearTrackingEventsList:result];
    }
    
    return (nil != result);
}

//
// get the VideoClicks list from the VAST entry
//
// Arguments:
// [videoClicksList]: the VideoClicks list of the Creative elements in the VAST entry
// [entryId]: the entry Id of VAST entry
// [ordinal]: indicate which ad in multiple ads
// [creativeOrdinal]: indicate which creative in multiple creatives
//
// Returns: YES for success and NO for failure
//
- (BOOL) getVideoClicksList:(NSArray **)videoClicksList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal
{
    NSString *result = nil;
    *videoClicksList = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vast.getVideoClicksList\\\", "
                           "\\\"params\\\": "
                           "{ \\\"entryId\\\": %d, "
                           "\\\"adOrdinal\\\": %d, "
                           "\\\"creativeOrdinal\\\": %d } }\")",
                           entryId,
                           ordinal,
                           creativeOrdinal] autorelease];
    
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *videoClicksList = [self parseJSONVideoClicksList:result];
    }
    
    return (nil != result);
}

//
// get the Icons list from the VAST entry
//
// Arguments:
// [iconsList]: the Icons list of the Creative elements in the VAST entry
// [entryId]: the entry Id of VAST entry
// [ordinal]: indicate which ad in multiple ads
// [creativeOrdinal]: indicate which creative in multiple creatives
//
// Returns: YES for success and NO for failure
//
- (BOOL) getIconsList:(NSArray **)iconsList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal
{
    NSString *result = nil;
    *iconsList = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vast.getIconsList\\\", "
                           "\\\"params\\\": "
                           "{ \\\"entryId\\\": %d, "
                           "\\\"adOrdinal\\\": %d, "
                           "\\\"creativeOrdinal\\\": %d } }\")",
                           entryId,
                           ordinal,
                           creativeOrdinal] autorelease];
    
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *iconsList = [self parseJSONIconsList:result];
    }
    
    return (nil != result);
}

//
// get the MediaFile list from the VAST entry
//
// Arguments:
// [mediaFilesList]: the MediaFiles list of the Creative elements in the VAST entry
// [entryId]: the entry Id of VAST entry
// [ordinal]: indicate which ad in multiple ads
// [creativeOrdinal]: indicate which creative in multiple creatives
//
// Returns: YES for success and NO for failure
//
- (BOOL) getMediaFileList:(NSArray **)mediaFilesList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal
{
    NSString *result = nil;
    *mediaFilesList = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vast.getMediaFileList\\\", "
                           "\\\"params\\\": "
                           "{ \\\"entryId\\\": %d, "
                           "\\\"adOrdinal\\\": %d, "
                           "\\\"creativeOrdinal\\\": %d } }\")",
                           entryId,
                           ordinal,
                           creativeOrdinal] autorelease];
    
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *mediaFilesList = [self parseJSONMediaFileList:result];
    }
    
    return (nil != result);
}

//
// get the CompanionAds list from the VAST entry
//
// Arguments:
// [adsList]: the CompanionAds list of the Creative elements in the VAST entry
// [entryId]: the entry Id of VAST entry
// [ordinal]: indicate which ad in multiple ads
// [creativeOrdinal]: indicate which creative in multiple creatives
//
// Returns: YES for success and NO for failure
//
- (BOOL) getCompanionAdsList:(NSArray **)adsList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal
{
    NSString *result = nil;
    *adsList = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vast.getCompanionAdsList\\\", "
                           "\\\"params\\\": "
                           "{ \\\"entryId\\\": %d, "
                           "\\\"adOrdinal\\\": %d, "
                           "\\\"creativeOrdinal\\\": %d } }\")",
                           entryId,
                           ordinal,
                           creativeOrdinal] autorelease];
    
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *adsList = [self parseJSONCompanionAdsList:result];
    }
    
    return (nil != result);
}

//
// get the NonLinearAds list from the VAST entry
//
// Arguments:
// [adsList]: the NonLinearAds list of the Creative elements in the VAST entry
// [entryId]: the entry Id of VAST entry
// [ordinal]: indicate which ad in multiple ads
// [creativeOrdinal]: indicate which creative in multiple creatives
//
// Returns: YES for success and NO for failure
//
- (BOOL) getNonLinearAdsList:(NSArray **)adsList withEntryId:(int32_t)entryId adOrdinal:(int32_t)ordinal creativeOrdinal:(int32_t)creativeOrdinal
{
    NSString *result = nil;
    *adsList = nil;
    
    NSString *function = [[[NSString alloc] initWithFormat:@"PLAYER_SEQUENCER.theAdResolver.runJSON("
                           "\"{\\\"func\\\": \\\"vast.getNonLinearAdsList\\\", "
                           "\\\"params\\\": "
                           "{ \\\"entryId\\\": %d, "
                           "\\\"adOrdinal\\\": %d, "
                           "\\\"creativeOrdinal\\\": %d } }\")",
                           entryId,
                           ordinal,
                           creativeOrdinal] autorelease];
    
    result = [self callJavaScriptWithString:function];
    if (nil != result && ![result isEqualToString:@"null"])
    {
        *adsList = [self parseJSONNonLinearAdsList:result];
    }
    
    return (nil != result);
}

#pragma mark -
#pragma mark Properties:

#pragma mark -
#pragma mark Destructor:

- (void) dealloc
{
    SEQUENCER_LOG(@"VASTParser dealloc called.");
    
    [lastError release];
    
    [super dealloc];
}

@end
