/*

File: CFNetworkLoader.m

Abstract: CFNetwork ImageClient Sample

Version: 1.0

Disclaimer: IMPORTANT:  This Apple software is supplied to you by Apple
Computer, Inc. ("Apple") in consideration of your agreement to the
following terms, and your use, installation, modification or
redistribution of this Apple software constitutes acceptance of these
terms.  If you do not agree with these terms, please do not use,
install, modify or redistribute this Apple software.

In consideration of your agreement to abide by the following terms, and
subject to these terms, Apple grants you a personal, non-exclusive
license, under Apple's copyrights in this original Apple software (the
"Apple Software"), to use, reproduce, modify and redistribute the Apple
Software, with or without modifications, in source and/or binary forms;
provided that if you redistribute the Apple Software in its entirety and
without modifications, you must retain this notice and the following
text and disclaimers in all such redistributions of the Apple Software. 
Neither the name, trademarks, service marks or logos of Apple Computer,
Inc. may be used to endorse or promote products derived from the Apple
Software without specific prior written permission from Apple.  Except
as expressly stated in this notice, no other rights or licenses, express
or implied, are granted by Apple herein, including but not limited to
any patent rights that may be infringed by your derivative works or by
other works in which the Apple Software may be incorporated.

The Apple Software is provided by Apple on an "AS IS" basis.  APPLE
MAKES NO WARRANTIES, EXPRESS OR IMPLIED, INCLUDING WITHOUT LIMITATION
THE IMPLIED WARRANTIES OF NON-INFRINGEMENT, MERCHANTABILITY AND FITNESS
FOR A PARTICULAR PURPOSE, REGARDING THE APPLE SOFTWARE OR ITS USE AND
OPERATION ALONE OR IN COMBINATION WITH YOUR PRODUCTS.

IN NO EVENT SHALL APPLE BE LIABLE FOR ANY SPECIAL, INDIRECT, INCIDENTAL
OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
INTERRUPTION) ARISING IN ANY WAY OUT OF THE USE, REPRODUCTION,
MODIFICATION AND/OR DISTRIBUTION OF THE APPLE SOFTWARE, HOWEVER CAUSED
AND WHETHER UNDER THEORY OF CONTRACT, TORT (INCLUDING NEGLIGENCE),
STRICT LIABILITY OR OTHERWISE, EVEN IF APPLE HAS BEEN ADVISED OF THE
POSSIBILITY OF SUCH DAMAGE.

Copyright (c) 2005 Apple Computer, Inc., All Rights Reserved

*/ 

#import "CFNetworkLoader.h"
#import "ImageClient.h"
#import "NSURLLoader.h"

#define BUFSIZE 4096

static void handleStreamEvent(CFReadStreamRef stream, CFStreamEventType type, void *clientCallBackInfo) {
    CFNetworkLoader *self = (CFNetworkLoader *)clientCallBackInfo;
    [self handleStreamEvent:type];
}

static void proxyChanged(SCDynamicStoreRef store, CFArrayRef changedKeys, void *info) {
    CFNetworkLoader *self = (CFNetworkLoader *)info;
    [self proxyChanged];
}

@implementation CFNetworkLoader

- (id)initWithImageClient:(ImageClient *)imgClient {
    if (self = [super init]) {
        imageClient = imgClient; // No retain because the ImageClient instance is retaining us
        
        // Create the dynamic store, to monitor changes to the proxy dictionary
        SCDynamicStoreContext context = {0, self, NULL, NULL, NULL};
        systemDynamicStore = SCDynamicStoreCreate(NULL, CFSTR("ImageClient"), proxyChanged, &context);
        
        // Set up the store to monitor any changes to the proxies
        CFStringRef proxiesKey = SCDynamicStoreKeyCreateProxies(NULL);
        CFArrayRef keyArray = CFArrayCreate(NULL, (const void **)(&proxiesKey), 1, &kCFTypeArrayCallBacks);
        SCDynamicStoreSetNotificationKeys(systemDynamicStore, keyArray, NULL);
        CFRelease(keyArray);
        CFRelease(proxiesKey);
        
        // Add the dyanmic store with the run loop
        CFRunLoopSourceRef storeRLSource = SCDynamicStoreCreateRunLoopSource(NULL, systemDynamicStore, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), storeRLSource, kCFRunLoopCommonModes);
        CFRelease(storeRLSource);
        
        // Preload the proxy dictionary with the current settings
        proxyDictionary = SCDynamicStoreCopyProxies(systemDynamicStore);
    }
    return self;
}

- (void)dealloc {
    if (request) CFRelease(request);
    [self cancelLoad];
    
    if (proxyDictionary) CFRelease(proxyDictionary);

    // Need to invalidate the dynamic store's run loop source to get the store out of the run loop
    CFRunLoopSourceRef rls = SCDynamicStoreCreateRunLoopSource(NULL, systemDynamicStore, 0);
    CFRunLoopSourceInvalidate(rls);
    CFRelease(rls);
    CFRelease(systemDynamicStore);

    [super dealloc];
}

- (void)loadURL:(NSURL *)url {
    // set the request for the new transaction
    if (request) CFRelease(request);
    request = CFHTTPMessageCreateRequest(NULL, CFSTR("GET"), (CFURLRef)url, kCFHTTPVersion1_1);
    
    // Start the load
    [self loadRequest];
}

- (void)loadRequest {
    // Cancel any load currently in progress
    [self cancelLoad];

    // Start a fresh data to hold the downloaded image
    data = CFDataCreateMutable(NULL, 0);
    
    readStream = CFReadStreamCreateForHTTPRequest(NULL, request);
    
    /* Support for the default proxy - quick and dirty
       The code below would work, but is very expensive for repeated downloads, because each call, it recreates
       the state necessary for communicating with the system configuration server.  Use it for single-shot downloads only;
       for repeated downloads, maintain a dynamic store to watch for changes, as we do
       (see the -initWithImageClient:, above, for the necessary set up)
       
        CFDictionaryRef proxyDict = SCDynamicStoreCopyProxies(NULL);
        CFReadStreamSetProperty(readStream, kCFStreamPropertyHTTPProxy, proxyDict);
    */

    // proxyDictionary is maintained by systemDynamicStore and its callback; see the setup in -initWithClient: for details
    CFReadStreamSetProperty(readStream, kCFStreamPropertyHTTPProxy, proxyDictionary);
    
    CFStreamClientContext context = {0, self, NULL, NULL, NULL};
    CFReadStreamSetClient(readStream, kCFStreamEventHasBytesAvailable | kCFStreamEventEndEncountered | kCFStreamEventErrorOccurred, handleStreamEvent, &context);
    CFReadStreamScheduleWithRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);

    CFReadStreamOpen(readStream);
}

- (void)cancelLoad {
    if (readStream) {
        CFReadStreamClose(readStream);
        CFReadStreamSetClient(readStream, kCFStreamEventNone, NULL, NULL);
        CFReadStreamUnscheduleFromRunLoop(readStream, CFRunLoopGetCurrent(), kCFRunLoopCommonModes);
        CFRelease(readStream);
        readStream = NULL;
    }
    if (data) {
        CFRelease(data);
        data = NULL;
    }
}

// Callback for CFReadStream
- (void)handleStreamEvent:(CFStreamEventType)event {
    switch (event) {
        case kCFStreamEventHasBytesAvailable: {
            UInt8 buffer[BUFSIZE];
            int bytesRead = CFReadStreamRead(readStream, buffer, BUFSIZE);
            if (bytesRead > 0) {
                CFDataAppendBytes(data, buffer, bytesRead);
            }
            // Don't worry about bytesRead <= 0, because those will generate other events
            break;
        }
        case kCFStreamEventEndEncountered: 
            [imageClient setImageData:(NSData *)data];
            [self cancelLoad];
            break;
        case kCFStreamEventErrorOccurred: {
            CFNetDiagnosticRef diagnostics = CFNetDiagnosticCreateWithStreams(NULL, readStream, NULL);
            [imageClient errorOccurredLoadingImage:diagnostics];
			[self cancelLoad];
            break;
        }
        default:
            NSLog(@"Received unexpected stream event %d\n", event);
    }
}

// Callback for a change in the proxy dictionary
- (void)proxyChanged {
    CFRelease(proxyDictionary);
    proxyDictionary = SCDynamicStoreCopyProxies(systemDynamicStore);
}

@end
