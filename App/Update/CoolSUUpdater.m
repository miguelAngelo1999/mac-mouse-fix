//
// --------------------------------------------------------------------------
// CoolSUUpdater.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2024
// Licensed under MIT
// --------------------------------------------------------------------------
//

#import "CoolSUUpdater.h"
#import "SparkleUpdaterController.h"
#import <objc/runtime.h>

#pragma mark - SSL Trust URL Protocol (for corporate proxy)

@interface MFSSLTrustURLProtocol : NSURLProtocol <NSURLSessionDataDelegate>
@property (nonatomic, strong) NSURLSessionDataTask *dataTask;
@property (nonatomic, strong) NSURLSession *innerSession;
@end

@implementation MFSSLTrustURLProtocol

+ (BOOL)canInitWithRequest:(NSURLRequest *)request {
    if (![request.URL.scheme isEqualToString:@"https"]) return NO;
    if ([NSURLProtocol propertyForKey:@"MFSSLHandled" inRequest:request]) return NO;
    
    NSString *host = request.URL.host;
    return ([host containsString:@"google"] || [host containsString:@"googleapis"]);
}

+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request {
    return request;
}

- (void)startLoading {
    NSMutableURLRequest *req = [self.request mutableCopy];
    [NSURLProtocol setProperty:@YES forKey:@"MFSSLHandled" inRequest:req];
    
    NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
    config.protocolClasses = @[]; // Prevent recursion
    self.innerSession = [NSURLSession sessionWithConfiguration:config delegate:self delegateQueue:nil];
    self.dataTask = [self.innerSession dataTaskWithRequest:req];
    [self.dataTask resume];
}

- (void)stopLoading {
    [self.dataTask cancel];
    [self.innerSession invalidateAndCancel];
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
  completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler {
    if ([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]) {
        completionHandler(NSURLSessionAuthChallengeUseCredential,
                          [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust]);
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition))completionHandler {
    [self.client URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageNotAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data {
    [self.client URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error {
    if (error) {
        [self.client URLProtocol:self didFailWithError:error];
    } else {
        [self.client URLProtocolDidFinishLoading:self];
    }
}

@end

#pragma mark - Swizzle NSURLSessionConfiguration to inject our protocol

@implementation NSURLSessionConfiguration (MFSSLInject)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // Also register globally for sharedSession
        [NSURLProtocol registerClass:[MFSSLTrustURLProtocol class]];
        
        // Swizzle defaultSessionConfiguration to inject our protocol
        Method original = class_getClassMethod(self, @selector(defaultSessionConfiguration));
        Method swizzled = class_getClassMethod(self, @selector(mf_defaultSessionConfiguration));
        method_exchangeImplementations(original, swizzled);
        
        // Swizzle ephemeralSessionConfiguration too
        Method origEph = class_getClassMethod(self, @selector(ephemeralSessionConfiguration));
        Method swizEph = class_getClassMethod(self, @selector(mf_ephemeralSessionConfiguration));
        method_exchangeImplementations(origEph, swizEph);
        
        NSLog(@"MFSSLTrustURLProtocol: Installed protocol injection into NSURLSessionConfiguration");
    });
}

+ (NSURLSessionConfiguration *)mf_defaultSessionConfiguration {
    // This calls the original (swizzled) implementation
    NSURLSessionConfiguration *config = [self mf_defaultSessionConfiguration];
    NSMutableArray *protocols = [NSMutableArray arrayWithObject:[MFSSLTrustURLProtocol class]];
    if (config.protocolClasses) {
        [protocols addObjectsFromArray:config.protocolClasses];
    }
    config.protocolClasses = protocols;
    return config;
}

+ (NSURLSessionConfiguration *)mf_ephemeralSessionConfiguration {
    NSURLSessionConfiguration *config = [self mf_ephemeralSessionConfiguration];
    NSMutableArray *protocols = [NSMutableArray arrayWithObject:[MFSSLTrustURLProtocol class]];
    if (config.protocolClasses) {
        [protocols addObjectsFromArray:config.protocolClasses];
    }
    config.protocolClasses = protocols;
    return config;
}

@end

#pragma mark - CoolSUUpdater

@implementation CoolSUUpdater

- (void)checkForUpdates:(id)sender {
    [SparkleUpdaterController resetSkippedVersions];
    [super checkForUpdates:sender];
}

@end
