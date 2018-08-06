//
//  XXURLInterceptor.m
//  Test_Demo
//
//  Created by 许毓方 on 2018/7/24.
//  Copyright © 2018 SN. All rights reserved.
//


/*
 config.protocolClasses = @[class];
 默认字自定义NSURLProtocol子类只能拦截到 [NSURLSession sharedSession], 需要在 NSURLSessionConfiguration 中显式声明协议类
 

 下列方法可以从任何线程调用，并且必须完全线程安全：
 -initWithRequest:cachedResponse:client:
 -dealloc
 +canInitWithRequest:
 +canonicalRequestForRequest:
 +requestIsCacheEquivalent:toRequest:
 
 
 下列方法总是由客户端线程调用： thread name = com.apple.CFNetwork.CustomProtocols
 -startLoading
 -stopLoading

 */

#import "XXXURLInterceptor.h"
#import "NSURLProtocol+XXXWebKitSupport.h"
#import "XXXURLSessionDecoupler.h"

#define kStartRequestFlagKey @"kStartRequestFlagKey"

@interface XXXURLInterceptor () <NSURLSessionDataDelegate>

@property (nonatomic, strong) NSURLSessionTask *task;

@property (nonatomic, strong) NSThread *clientThread;

@property (nonatomic, strong) NSArray *runloopModes;

@property (nonatomic, strong, class) Class<XXXURLInterceptorProtocol> hookCls;

@end


@implementation XXXURLInterceptor

static Class _hookCls = nil;

+ (void)startMonitoringClass:(Class<XXXURLInterceptorProtocol>)hookCls
{
    [NSURLProtocol registerClass:self];
    
    for (NSString *scheme in @[@"http", @"https"]) {
        [self xxx_registerScheme:scheme];
    }
    
    XXXURLInterceptor.hookCls = hookCls;
}

+ (void)startMonitoring {
    [self startMonitoringClass:nil];
}

+ (void)stopMonitoring {
    [NSURLProtocol unregisterClass:self];
    
    for (NSString *scheme in @[@"http", @"https"]) {
        [self xxx_unregisterScheme:scheme];
    }
    
    XXXURLInterceptor.hookCls = nil;
}


#pragma mark - NSURLProtocol
+ (BOOL)canInitWithTask:(NSURLSessionTask *)task {
    return [self canInitWithRequest:task.currentRequest];
}

/// 1. 过滤请求
+ (BOOL)canInitWithRequest:(NSURLRequest *)request
{
    BOOL shouldAccept = YES;
    
    // startLoading的请求不需要再走流程
    shouldAccept = ([self propertyForKey:kStartRequestFlagKey inRequest:request] == nil);
    if (!shouldAccept) {
        return shouldAccept;
    }
    
    if ([XXXURLInterceptor.hookCls respondsToSelector:@selector(hook_canInitWithRequest:)]) {
        return [XXXURLInterceptor.hookCls hook_canInitWithRequest:request];
    }
    
    return shouldAccept;
}

/// 2. 规范化请求
+ (NSURLRequest *)canonicalRequestForRequest:(NSURLRequest *)request
{
    if ([XXXURLInterceptor.hookCls respondsToSelector:@selector(hook_canonicalRequestForRequest:)]) {
        return [XXXURLInterceptor.hookCls hook_canonicalRequestForRequest:request];
    }
    
    return request;
}

/// 3. 初始化协议
- (instancetype)initWithRequest:(NSURLRequest *)request cachedResponse:(NSCachedURLResponse *)cachedResponse client:(id<NSURLProtocolClient>)client
{
    self = [super initWithRequest:request cachedResponse:cachedResponse client:client];
    return self;
}

/// 4. 请求
- (void)startLoading
{
    self.clientThread = [NSThread currentThread];
    NSMutableArray *modes = [NSMutableArray array];
    [modes addObject:NSDefaultRunLoopMode];
    NSString *currentMode = [[NSRunLoop currentRunLoop] currentMode];
    if ( (currentMode != nil) && ! [currentMode isEqual:NSDefaultRunLoopMode] ) {
        [modes addObject:currentMode];
    }
    self.runloopModes = modes;
    
    
    BOOL isHook = NO;
    NSMutableURLRequest *request = [self.request mutableCopy];
    [[self class] setProperty:@YES forKey:kStartRequestFlagKey inRequest:request];
    
    
    if (!isHook) {
        
        self.task = [[[self class] sharedDecopler] dataTaskWithRequest:request delegate:self modes:self.runloopModes];
        [self.task resume];
        
    }else {
//        request = // 注意线程
    }
}

- (void)stopLoading
{
    assert([NSThread currentThread] == self.clientThread);
    if (self.task != nil) {
        [self.task cancel];
        self.task = nil;
    }
}

- (void)dealloc
{
    NSLog(@"%s", __func__);
}


#pragma mark - <NSURLSessionDelegate>

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                            didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
                              completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler
{
    /**
     http://nathanli.cn/2016/12/20/httpdns-%E5%9C%A8-ios-%E4%B8%AD%E7%9A%84%E5%AE%9E%E8%B7%B5/
     https 握手的验证证书处理, 未完成
     */
    // 是否服务器证书认证
    if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust ) {
        // 现在是全都通过, 不校验
        SecTrustRef trust = challenge.protectionSpace.serverTrust;
        NSURLCredential *credential = [NSURLCredential credentialForTrust:trust];
        completionHandler(NSURLSessionAuthChallengeUseCredential, credential);
    }else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

#pragma mark - <NSURLSessionDataDelegate>
// 任务已经收到响应，在调用完成块之前，不会再收到任何消息。配置允许您取消请求或将数据任务转换为下载任务
// download upload 不会被调用
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveResponse:(NSURLResponse *)response completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    [[self client] URLProtocol:self didReceiveResponse:response cacheStoragePolicy:NSURLCacheStorageAllowed];
    completionHandler(NSURLSessionResponseAllow);
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
    didReceiveData:(NSData *)data
{
    [[self client] URLProtocol:self didLoadData:data];
}

- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
 willCacheResponse:(NSCachedURLResponse *)proposedResponse
 completionHandler:(void (^)(NSCachedURLResponse * _Nullable cachedResponse))completionHandler
{
    completionHandler(proposedResponse);
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didCompleteWithError:(NSError *)error
{
    if (error == nil) {
        [[self client] URLProtocolDidFinishLoading:self];
        
    } else if ( [[error domain] isEqual:NSURLErrorDomain] && ([error code] == NSURLErrorCancelled) ) {
        // 1. 在重定向过程中，在这种情况下，重定向代码已经告诉客户端失败的情况  willPerformHTTPRedirection 代理方法
        // 2. 如果请求被调用-stopLoading取消，在这种情况下，客户机不想知道失败。
    } else {
        [[self client] URLProtocol:self didFailWithError:error];
        NSLog(@"error:>>>>> %@", error);
    }
}

- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willPerformHTTPRedirection:(NSHTTPURLResponse *)response newRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
    // 新的请求是从我们的旧请求中复制的，所以它具有我们的神奇属性。我们实际上必须删除它，以便当客户端启动新请求时，
    // 我们可以看到它。如果我们不这样做，那么我们就永远看不到新的请求，因此也就没有机会更改它的缓存行为。
    // 我们还取消了当前的连接，因为客户端无论如何都会为我们启动一个新的请求。
    NSMutableURLRequest *redirectRequest = [request mutableCopy];
    [[self class] removePropertyForKey:kStartRequestFlagKey inRequest:redirectRequest];
    
    [[self client] URLProtocol:self wasRedirectedToRequest:redirectRequest redirectResponse:response];
    
    // 停止我们的加载。CFNetwork将创建一个新的NSURLProtocol实例来运行重定向的加载
    [self.task cancel];
    
    // 下面的代码最后调用-URLSession:task:didCompleteWithError:使用NSURLErrorDomain / nsurlerrorcancorcancorcancel，这将具体地捕获并忽略错误。
    [[self client] URLProtocol:self didFailWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:NSUserCancelledError userInfo:nil]];
}


#pragma mark - Private Method
// 客户端线程执行
- (void)performBlock:(dispatch_block_t)block
{
    assert(self.clientThread != nil);
    assert(block != nil);
    [self performSelector:@selector(performBlockOnClientThread:) onThread:self.clientThread withObject:[block copy] waitUntilDone:NO modes:self.runloopModes];
}

- (void)performBlockOnClientThread:(dispatch_block_t)block
{
    assert([NSThread currentThread] == self.clientThread);
    block();
}


#pragma mark - Getter && Setter

+ (XXXURLSessionDecoupler *)sharedDecopler
{
    static XXXURLSessionDecoupler *decoupler = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSURLSessionConfiguration *configration = [NSURLSessionConfiguration defaultSessionConfiguration];
        configration.protocolClasses = @[self]; // 必须显式的配置协议, 否则将接收不到重定向
        decoupler = [[XXXURLSessionDecoupler alloc] initWithConfiguration:configration];
    });
    return decoupler;
}

+ (Class)hookCls
{
    return _hookCls;
}

+ (void)setHookCls:(Class)hookCls
{
    if (hookCls != _hookCls) {
        _hookCls = hookCls;
    }
}

@end
