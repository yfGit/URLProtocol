//
//  TestHTTPDNSHandle.m
//  Test_Demo
//
//  Created by 许毓方 on 2018/8/2.
//  Copyright © 2018 SN. All rights reserved.
//

#import "TestHTTPDNSHandle.h"
#import "XXXDNSResolver.h"

@implementation TestHTTPDNSHandle

+ (BOOL)hook_canInitWithRequest:(NSURLRequest *)request
{
    BOOL shouldAccept = YES;
    NSURL *url = request.URL;
    NSString *scheme = [[url scheme] lowercaseString];
    
    // Check the basics.
    shouldAccept = (request != nil);
    if (shouldAccept) {
        shouldAccept = (url != nil);
    }
    
    if (!shouldAccept) {
        NSLog(@"decline request %@", request); // <rdar://problem/15197355>
        return shouldAccept;
    }
    
    // Check scheme
    shouldAccept = (scheme != nil);
    if (!shouldAccept) {
        NSLog(@"no scheme %@", request);
        assert(scheme != nil);
    }
    
    // Check http https
    if (shouldAccept) {
        shouldAccept = YES && [scheme isEqual:@"http"];
        if ( !shouldAccept ) {
            shouldAccept = YES && [scheme isEqual:@"https"];
        }
    }
    
    return shouldAccept;
}

+ (NSURLRequest *)hook_canonicalRequestForRequest:(NSURLRequest *)request
{
//    NSString *scheme = [request.URL scheme];
//    if ([scheme isEqualToString:@"http"]) {
    NSMutableURLRequest *mRequest = [request mutableCopy];
    NSString *absoluteString = request.URL.absoluteString;
    NSString *host = request.URL.host;
    NSString *ip = [XXXDNSResolver queryIpv4FromHost:host];
    if (ip.length > 0) {
        NSRange range = [absoluteString rangeOfString:host];
        if (range.location != NSNotFound) {
            absoluteString = [absoluteString stringByReplacingCharactersInRange:range withString:ip];
            mRequest.URL = [NSURL URLWithString:absoluteString];
            [mRequest setValue:host forHTTPHeaderField:@"host"];
            return mRequest;
        }
    }else {
        NSLog(@">>>>>> ip 解析失败: %@", request);
    }
    return request;
}

@end
