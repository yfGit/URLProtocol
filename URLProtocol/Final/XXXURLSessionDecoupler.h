//
//  XXXURLSessionDecoupler.h
//  Test_Demo
//
//  Created by 许毓方 on 2018/8/1.
//  Copyright © 2018 SN. All rights reserved.
//
// 解耦 XXXURLInterceptor urlsession, 以便于走 dealloc


#import <Foundation/Foundation.h>

@interface XXXURLSessionDecoupler : NSObject

@property (nonatomic, strong, readonly) NSURLSessionConfiguration *configuration;

@property (nonatomic, strong, readonly) NSURLSession *session;

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration;

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes;

@end
