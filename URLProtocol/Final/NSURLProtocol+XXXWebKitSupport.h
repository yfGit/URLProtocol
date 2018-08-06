//
//  NSURLProtocol+XXXWebKitSupport.h
//  Test_Demo
//
//  Created by 许毓方 on 2018/8/1.
//  Copyright © 2018 SN. All rights reserved.
//
// wkWebView url拦截额外配置
// https://blog.yeatse.com/2016/10/26/support-nsurlprotocol-in-wkwebview/

#import <Foundation/Foundation.h>

@interface NSURLProtocol (XXXWebKitSupport)

+ (void)xxx_registerScheme:(NSString *)scheme;

+ (void)xxx_unregisterScheme:(NSString *)scheme;

@end
