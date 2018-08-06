//
//  XXURLInterceptor.h
//  Test_Demo
//
//  Created by 许毓方 on 2018/7/24.
//  Copyright © 2018 SN. All rights reserved.
//
//  webview url 拦截器
//  官方 https://developer.apple.com/library/ios/samplecode/CustomHTTPProtocol/CustomHTTPProtocol.zip

#import <Foundation/Foundation.h>

@protocol XXXURLInterceptorProtocol <NSObject>

@optional

+ (BOOL)hook_canInitWithRequest:(NSURLRequest *)request;

+ (NSURLRequest *)hook_canonicalRequestForRequest:(NSURLRequest *)request;

@end

@interface XXXURLInterceptor : NSURLProtocol

/// 开始监听  自定义拦截内容
+ (void)startMonitoringClass:(Class<XXXURLInterceptorProtocol>)hookCls;
/// 开始监听
+ (void)startMonitoring;
/// 停止监听
+ (void)stopMonitoring;



@end
