//
//  XXDNSResolver.m
//  Test_Demo
//
//  Created by 许毓方 on 2018/7/25.
//  Copyright © 2018 SN. All rights reserved.
//

#import "XXXDNSResolver.h"

// 域名 -> ip
#include <sys/types.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <netdb.h>

// 获取ip
#include <arpa/inet.h>
#include <netdb.h>
#include <net/if.h>
#include <ifaddrs.h>
#import <dlfcn.h>
#import <SystemConfiguration/SystemConfiguration.h>

@interface XXXDNSResolver ()

/// ip映射表   ipv4_host : ipv4, ipv6_host: ipv6
@property (nonatomic, strong, readonly, class) NSMutableDictionary *ipMaps;

@end

static NSMutableDictionary *_ipMaps = nil;

@implementation XXXDNSResolver

+ (void)clearIpMaps
{
    [XXXDNSResolver.ipMaps removeAllObjects];
}

+ (void)resetIpMapsWithHost:(NSString *)host
{
    if (host.length == 0) return;
    
    NSString *ipv4Key = [NSString stringWithFormat:@"ipv4_%@",host];
    NSString *ipv6Key = [NSString stringWithFormat:@"ipv6_%@",host];
    [XXXDNSResolver.ipMaps removeObjectForKey:ipv4Key];
    [XXXDNSResolver.ipMaps removeObjectForKey:ipv6Key];
}

#pragma mark - DNS
+ (NSString *)queryIpFromHost:(NSString *)host
{
    NSString *ipAddress = [self queryIpv6FromHost:host]; // 先ipv6
    if (ipAddress == nil) {
        ipAddress = [self queryIpv4FromHost:host];
    }
    return ipAddress;
}

+ (NSString *)queryIpv4FromHost:(NSString *)host
{
    // 0. 是否ip字符串
    if ([self isValidIpv4:host]) return host;
    
    // 1. 是否已经解析过
    NSString *parseIp = [self ipAddressForHost:host isIpv4:YES];
    if (parseIp) return parseIp;
    
    // 2. 解析
    struct hostent *phost = [self getHostByName:host isIpv4:YES];
    if ( phost == NULL ) { return nil; }
    
    struct in_addr ip_addr;
    memcpy(&ip_addr, phost->h_addr_list[0], 4);
    
    char ip[20] = { 0 };
    inet_ntop(AF_INET, &ip_addr, ip, sizeof(ip));
    NSString *ipAddress = [NSString stringWithUTF8String:ip];
    
    NSLog(@"ipv4 ==== %@ ===> %@", host, ipAddress);
    [self storeHost:host ipAddress:ipAddress isIpv4:YES];
    return ipAddress;
}

+ (NSString *)queryIpv6FromHost:(NSString *)host
{
    if ([self isValidIpv4:host]) return host;
    
    NSString *parseIp = [self ipAddressForHost:host isIpv4:NO];
    if (parseIp) return parseIp;
    
    
    struct hostent *phost = [self getHostByName:host isIpv4:NO];
    if ( phost == NULL ) { return nil; }
    
    char ip[32] = { 0 };
    char **aliases;
    switch (phost->h_addrtype) {
        case AF_INET:
        case AF_INET6: {
            for (aliases = phost->h_addr_list; *aliases != NULL; aliases++) {
                NSString *ipAddress = [NSString stringWithUTF8String: inet_ntop(phost->h_addrtype, *aliases, ip, sizeof(ip))];
                if (ipAddress) {
                    NSLog(@"ipv6 ==== %@ ===> %@", host, ipAddress);
                    [self storeHost:host ipAddress:ipAddress isIpv4:NO];
                    return ipAddress;
                }
            }
        } break;
            
        default:
            break;
    }
    return nil;
}


+ (struct hostent *)getHostByName:(NSString *)hostName isIpv4:(BOOL)isIpv4
{
    const char *host = [hostName UTF8String];
    struct hostent *phot;
    @try {
        phot = isIpv4 ? gethostbyname(host) : gethostbyname2(host, AF_INET6);
    } @catch (NSException *exception) {
        return NULL;
    }
    
    if (phot == NULL)
        NSLog(@"%@ => %@ 获取失败", hostName, isIpv4 ? @"ipv4" : @"ipv6");
    
    return phot;
}

#pragma mark - Local
+ (NSString *)queryWiFiIPAddress
{
    BOOL success;
    struct ifaddrs *addrs;
    const struct ifaddrs * cursor;
    
    success = getifaddrs(&addrs) == 0;
    if (success) {
        cursor = addrs;
        while (cursor != NULL) {
            // the second test keeps from picking up the loopback address
            if (cursor->ifa_addr->sa_family == AF_INET && (cursor->ifa_flags & IFF_LOOPBACK) == 0)
            {
                NSString *name = [NSString stringWithUTF8String:cursor->ifa_name];
                if ([name isEqualToString:@"en0"])  {// Wi-Fi adapter
                    NSString *ipAddress = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)cursor->ifa_addr)->sin_addr)];
                    NSLog(@"WiFi ip =======> %@", ipAddress);
                    freeifaddrs(addrs);
                    return ipAddress;
                }
            }
            cursor = cursor->ifa_next;
        }
        freeifaddrs(addrs);
    }
    return nil;
}

+ (NSString *)queryWWANIPAddress
{
    NSString *ipAddress = [[self deviceWWANIPAdress] valueForKey:@"cip"];
    NSLog(@"WWAN ip =======> %@", ipAddress);
    return ipAddress;
}

+ (NSDictionary *)deviceWWANIPAdress
{
    NSError *error;
    
    NSURL *ipURL = [NSURL URLWithString:@"http://pv.sohu.com/cityjson?ie=utf-8"];
    
    NSMutableString *ip = [NSMutableString stringWithContentsOfURL:ipURL encoding:NSUTF8StringEncoding error:&error];
    
    //判断返回字符串是否为所需数据
    if ([ip hasPrefix:@"var returnCitySN = "])
    {
        //对字符串进行处理，然后进行json解析
        
        //删除字符串多余字符串
        
        NSRange range = NSMakeRange(0, 19);
        
        [ip deleteCharactersInRange:range];
        
        NSString * nowIp =[ip substringToIndex:ip.length-1];
        
        //将字符串转换成二进制进行Json解析
        
        NSData * data = [nowIp dataUsingEncoding:NSUTF8StringEncoding];
        
        NSDictionary * dict = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:nil];
        
        return dict;
    }
    return nil;
}

#pragma mark - judgement
+ (BOOL)isValidIP:(NSString *)ip {
    return [self isValidIpv4:ip] || [self isValidIpv6:ip];
}

+ (BOOL)isValidIpv4:(NSString *)ip {
    NSString *ipRegExp = @"^(([1-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])(\\.([0-9]|[1-9][0-9]|1[0-9][0-9]|2[0-4][0-9]|25[0-5])){3})|(0\\.0\\.0\\.0)$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"SELF matches %@", ipRegExp];
    return [predicate evaluateWithObject:ip];
}

+ (BOOL)isValidIpv6:(NSString *)ip {
    NSString *ipRegExp = @"^(^((\\p{XDigit}{1,4}):){7}(\\p{XDigit}{1,4})$)|(^(::((\\p{XDigit}//{1,4}):){0,5}(\\p{XDigit}{1,4}))$)|(^((\\p{XDigit}{1,4})(:|::)){0,6}(\\p//{XDigit}{1,4})$)$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat: @"SELF matches %@", ipRegExp];
    return [predicate evaluateWithObject:ip];
}

+ (BOOL)isValidHost:(NSString *)host {
    NSString *regex = @"^(?=^.{3,255}$)[a-zA-Z0-9][-a-zA-Z0-9]{0,62}(\\.[a-zA-Z0-9][-a-zA-Z0-9]{0,62})+$";
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"SELF MATCHES %@",regex];
    return [predicate evaluateWithObject:host];
}

#pragma mark - Private Method

/// 是否解析过
+ (NSString *)ipAddressForHost:(NSString *)host isIpv4:(BOOL)isIpv4
{
    if (host.length == 0) return nil;
    
    NSString *ipAddress;
    
    NSString *hostKey = [NSString stringWithFormat:@"%@_%@", isIpv4 ? @"ipv4" : @"ipv6", host];
    ipAddress = XXXDNSResolver.ipMaps[hostKey];

    return ipAddress;
}

/// 存储ip
+ (void)storeHost:(NSString *)host ipAddress:(NSString *)ipAddress isIpv4:(BOOL)isIpv4
{
    if (ipAddress.length == 0 || host.length == 0) return;
    
    NSString *hostKey = [NSString stringWithFormat:@"%@_%@", isIpv4 ? @"ipv4" : @"ipv6", host];
    XXXDNSResolver.ipMaps[hostKey] = ipAddress;
}

#pragma mark - Getter & Setter
+ (NSMutableDictionary *)ipMaps
{
    if (!_ipMaps) {
        _ipMaps = [NSMutableDictionary dictionary];
    }
    return _ipMaps;
}


@end
