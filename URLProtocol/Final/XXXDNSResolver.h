//
//  XXDNSResolver.h
//  Test_Demo
//
//  Created by 许毓方 on 2018/7/25.
//  Copyright © 2018 SN. All rights reserved.
//
//  DNS 解析器

#import <Foundation/Foundation.h>

@interface XXXDNSResolver : NSObject

/// 域名 -> ip
+ (NSString *)queryIpFromHost:(NSString *)hostName;
+ (NSString *)queryIpv4FromHost:(NSString *)host;
+ (NSString *)queryIpv6FromHost:(NSString *)host; // 有问题

/// 清楚ip缓存表
+ (void)clearIpMaps;
+ (void)resetIpMapsWithHost:(NSString *)host;


/// WiFi IP, WWAN时返回nil
+ (NSString *)queryWiFiIPAddress;
/// WWAN IP
+ (NSString *)queryWWANIPAddress;


/// 是否有效ip
+ (BOOL)isValidIP:(NSString *)ip;
/// 是否为域名 不含scheme
+ (BOOL)isValidHost:(NSString *)host;





@end
