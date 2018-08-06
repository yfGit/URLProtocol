//
//  XXXURLSessionDecoupler.m
//  Test_Demo
//
//  Created by 许毓方 on 2018/8/1.
//  Copyright © 2018 SN. All rights reserved.
//

#import "XXXURLSessionDecoupler.h"

#pragma mark - TaskInfo
@interface XXXURLSessionDecouplerTaskInfo : NSObject

- (instancetype)initWithTask:(NSURLSessionDataTask *)task delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes;

@property (nonatomic, strong, readonly) NSURLSessionDataTask *task;
@property (nonatomic, strong, readonly) id<NSURLSessionDataDelegate> delegate;
@property (nonatomic, strong, readonly) NSThread *thread;
@property (nonatomic, copy,   readonly) NSArray *modes;

- (void)performBlock:(dispatch_block_t)block;

- (void)invalidate;

@end

@interface XXXURLSessionDecouplerTaskInfo ()

@property (nonatomic, strong, readwrite) id<NSURLSessionDataDelegate> delegate;
@property (nonatomic, strong, readwrite) NSThread *thread;

@end

@implementation XXXURLSessionDecouplerTaskInfo

- (instancetype)initWithTask:(NSURLSessionDataTask *)task delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes
{
    assert(task != nil);
    assert(delegate != nil);
    assert(modes != nil);
    
    self = [super init];
    if (self != nil) {
        _task = task;
        _delegate = delegate;
        _thread = [NSThread currentThread];
        _modes = [modes copy];
    }
    return self;
}

- (void)performBlock:(dispatch_block_t)block
{
    assert(self.delegate != nil);
    assert(self.thread != nil);
    [self performSelector:@selector(performBlockOnClientThread:) onThread:self.thread withObject:[block copy] waitUntilDone:NO modes:self.modes];
}

- (void)performBlockOnClientThread:(dispatch_block_t)block
{
    assert([NSThread currentThread] == self.thread);
    block();
}

- (void)invalidate
{
    self.delegate = nil;
    self.thread   = nil;
}


@end


#pragma mark - Decoupler
@interface XXXURLSessionDecoupler ()<NSURLSessionDelegate>

@property (nonatomic, strong, readonly) NSOperationQueue *sessionDelegateQueue;

@property (nonatomic, strong, readonly) NSMutableDictionary *taskInfoByTaskID;

@end

@implementation XXXURLSessionDecoupler

- (instancetype)init
{
    return [self initWithConfiguration:nil];
}

- (instancetype)initWithConfiguration:(NSURLSessionConfiguration *)configuration
{
    self = [super init];
    if (self) {
        if (configuration == nil)
            configuration = [NSURLSessionConfiguration defaultSessionConfiguration];
        _configuration = configuration;
        
        _taskInfoByTaskID = [NSMutableDictionary dictionary];
        
        // 代理回调在哪个线程
        _sessionDelegateQueue = [NSOperationQueue new];
        [_sessionDelegateQueue setMaxConcurrentOperationCount:1];
        [_sessionDelegateQueue setName:@"XXXURLSessionDecoupler"];
        
        _session = [NSURLSession sessionWithConfiguration:_configuration delegate:self delegateQueue:_sessionDelegateQueue];
        _session.sessionDescription = @"XXXURLSessionDecoupler";
    }
    
    return self;
}

- (NSURLSessionDataTask *)dataTaskWithRequest:(NSURLRequest *)request delegate:(id<NSURLSessionDataDelegate>)delegate modes:(NSArray *)modes
{
    NSURLSessionDataTask *task;
    XXXURLSessionDecouplerTaskInfo *taskInfo;
    
    assert(request != nil);
    assert(delegate != nil);
    
    if (modes.count == 0) {
        modes = @[NSDefaultRunLoopMode];
    }
    
    task = [self.session dataTaskWithRequest:request];
    assert(task != nil);
    
    taskInfo = [[XXXURLSessionDecouplerTaskInfo alloc] initWithTask:task delegate:delegate modes:modes];
    self.taskInfoByTaskID[@(task.taskIdentifier)] = taskInfo;
    
    return task;
}

#pragma mark - Private Method
- (XXXURLSessionDecouplerTaskInfo *)taskInfoForTask:(NSURLSessionTask *)task {
    return self.taskInfoByTaskID[@(task.taskIdentifier)];;
}




#pragma mark - <NSURLSessionDelegate>

/**
 会话接收的最后一个消息。会话只会因为系统错误或显式地无效而变得无效，在这种情况下，错误参数将为nil。解引用
 
 显示调用:
 invalidateAndCancel: 直接关闭session的所有task, 即使还有一些在等待，将要去执行，但是也取消了
 finishTasksAndInvalidate: 可以让等待的task继续执行，只是不去创建新的task了
 */
- (void)URLSession:(NSURLSession *)session didBecomeInvalidWithError:(nullable NSError *)error {
    
}

/**
 NSURLSession接收到后台的挑战的时候
 
 如果实现了连接级别身份验证的挑战，则该委托将获得向底层连接提供身份验证凭据的机会。
 某些类型的身份验证将应用于对服务器的给定连接的多个请求(SSL服务器信任挑战)。
 如果未实现此委托消息，则行为将使用默认处理，这可能涉及用户交互。
 */
//- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
// completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler {
//    NSLog(@"%s", __func__);
//    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
//}

/**
 如果应用程序收到了 -application:handleeventsforbackgrounddurlsession:completionHandler: 消息，
 会话委托将接收到这条消息，以表明之前为这个会话排队的所有消息已经被发送。
 此时，可以安全地调用先前存储的完成处理程序，或者开始任何将导致调用完成处理程序的内部更新。
 */
- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession *)session {
    NSLog(@"%s", __func__);
}


#pragma mark - <NSURLSessionTaskDelegate>

/**
 当系统准备好使用延迟的启动时间集开始工作时发送(使用earliestBeginDate属性)。
 必须调用completionHandler来进行加载。向完成处理程序提供的处理将继续加载提供给任务的原始请求，将请求替换为指定任务，或者取消任务。
 如果这个委托没有实现，加载将继续原始请求
*/
//- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task willBeginDelayedRequest:(NSURLRequest *)request completionHandler:(void (^)(NSURLSessionDelayedRequestDisposition disposition, NSURLRequest * _Nullable newRequest))completionHandler

/**
 当任务无法启动网络加载过程时发送，因为当前的网络连接不可用或不足以满足任务的请求。
 每个任务最多调用一次这个委托，只有在NSURLSessionConfiguration中的waitsForConnectivity属性被设置为YES时才调用它。
 这个委托回调不会被后台会话调用，因为这些会话会忽略waitForConnectivity属性。
 */
- (void)URLSession:(NSURLSession *)session taskIsWaitingForConnectivity:(NSURLSessionTask *)task
{
    NSLog(@"%s", __func__);
}

/**
 当收集到该任务的完整统计信息时发送。
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task didFinishCollectingMetrics:(NSURLSessionTaskMetrics *)metrics  API_AVAILABLE(ios(10.0)){
    NSLog(@"%s", __func__);
}

/**
 HTTP请求的时候，打算去请求一个新的URL
 
 HTTP请求正在尝试对不同的URL执行重定向。您必须调用完成例程以允许重定向，
 允许使用修改后的请求重定向，或者将nil传递给completionHandler以使重定向响应的主体作为此请求的有效负载交付。默认情况是遵循重定向。
 对于后台会话中的任务，总是遵循重定向，不会调用此方法。
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                     willPerformHTTPRedirection:(NSHTTPURLResponse *)response
                                     newRequest:(NSURLRequest *)newRequest
                              completionHandler:(void (^)(NSURLRequest * _Nullable))completionHandler
{
    XXXURLSessionDecouplerTaskInfo *taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:willPerformHTTPRedirection:newRequest:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task willPerformHTTPRedirection:response newRequest:newRequest completionHandler:completionHandler];
        }];
    }else {
        completionHandler(newRequest);
    }
}

/**
 任务已经收到一个请求特定的身份验证挑战。如果未实现此委托，将调用会话特定的身份验证挑战，其行为将与使用默认处理配置相同
 
 NSURLSessionDelegate 的 Challenge方法 实现了, 就不会再调用这方法
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                            didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge
                              completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition disposition, NSURLCredential * _Nullable credential))completionHandler
{
    XXXURLSessionDecouplerTaskInfo *taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:didReceiveChallenge:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task didReceiveChallenge:challenge completionHandler:completionHandler];
        }];
    } else {
        completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
    }
}

/**
 如果任务需要一个新的未打开的body stream，则发送。
 当涉及body stream的任何请求的身份验证失败时，这可能是必要的。
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                              needNewBodyStream:(void (^)(NSInputStream * _Nullable bodyStream))completionHandler
{
    XXXURLSessionDecouplerTaskInfo *taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:needNewBodyStream:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task needNewBodyStream:completionHandler];
        }];
    }else {
        completionHandler(nil);
    }
}

/**
 定期发送通知 上传进度 的委托。这些信息也可以作为任务的属性使用。
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                                didSendBodyData:(int64_t)bytesSent
                                 totalBytesSent:(int64_t)totalBytesSent
                       totalBytesExpectedToSend:(int64_t)totalBytesExpectedToSend
{
    XXXURLSessionDecouplerTaskInfo *taskInfo = [self taskInfoForTask:task];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:didSendBodyData:totalBytesSent:totalBytesExpectedToSend:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task didSendBodyData:bytesSent totalBytesSent:totalBytesSent totalBytesExpectedToSend:totalBytesExpectedToSend];
        }];
    }
}

/**
 最后一条消息发送。错误可能为nil，这意味着没有发生错误，这个任务已经完成。
 */
- (void)URLSession:(NSURLSession *)session task:(NSURLSessionTask *)task
                           didCompleteWithError:(nullable NSError *)error
{
    XXXURLSessionDecouplerTaskInfo *taskInfo = [self taskInfoForTask:task];
    // 这是我们的最后一个委托回调，因此我们删除了任务信息记录。
    [self.taskInfoByTaskID removeObjectForKey:@(task.taskIdentifier)];
    
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:task:didCompleteWithError:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session task:task didCompleteWithError:error];
            [taskInfo invalidate];
        }];
    } else {
        [taskInfo invalidate];
    }
}

#pragma mark <NSURLSessionDataDelegate>
/**
 第一个调用(重定向, 证书除外), 决定是否cancel, allow, BecomeDownload, BecomeStream
 
 任务已经收到响应，在调用完成块之前，不会再收到任何消息。配置允许您取消请求或将数据任务转换为下载任务。
 这个委托消息是可选的——如果不实现它，可以将响应作为任务的属性。
 此方法不用于后台上传任务(不能转换为下载任务)。
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                 didReceiveResponse:(NSURLResponse *)response
                                  completionHandler:(void (^)(NSURLSessionResponseDisposition disposition))completionHandler
{
    XXXURLSessionDecouplerTaskInfo *taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveResponse:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask didReceiveResponse:response completionHandler:completionHandler];
        }];
    } else {
        completionHandler(NSURLSessionResponseAllow);
    }
}

/**
 通知 data task 已成为 download task。不会向 data task 发送任何未来的消息
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                              didBecomeDownloadTask:(NSURLSessionDownloadTask *)downloadTask
{
    XXXURLSessionDecouplerTaskInfo *taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:didBecomeDownloadTask:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask didBecomeDownloadTask:downloadTask];
        }];
    }
}

/*
 通知 data task 已成为 bidirectional stream task. 不会向 data task 发送任何未来的消息
 新创建的 streamTask 将携带原始请求和响应作为属性
 对于流水线上的请求，流对象只允许读取，对象将立即发出-URLSession:writeClosedForStream:。可以为会话中的所有请求禁用管道，或者通过NSURLRequest HTTPShouldUsePipelining属性禁用管道。底层连接不再被认为是HTTP连接缓存的一部分，也不会计算每个主机的连接总数
 */
//- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didBecomeStreamTask:(NSURLSessionStreamTask *)streamTask API_AVAILABLE(ios(9.0));

/**
 response 后调用
 
 当委托可以使用数据时发送。假设委托将保留而不是复制数据。
 由于数据可能是不连续的，您应该使用[NSData enumerateByteRangesUsingBlock:]来访问它。
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask didReceiveData:(NSData *)data
{
    XXXURLSessionDecouplerTaskInfo *taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:didReceiveData:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask didReceiveData:data];
        }];
    }
}

/**
 使用有效的NSCachedURLResponse调用完成例程以允许缓存结果数据，或者传递nil以防止缓存。
 注意，不能保证会对给定的资源尝试缓存，您不应该依赖此消息来接收资源数据。
 */
- (void)URLSession:(NSURLSession *)session dataTask:(NSURLSessionDataTask *)dataTask
                                  willCacheResponse:(NSCachedURLResponse *)proposedResponse
                                  completionHandler:(void (^)(NSCachedURLResponse * _Nullable cachedResponse))completionHandler
{
    XXXURLSessionDecouplerTaskInfo *taskInfo = [self taskInfoForTask:dataTask];
    if ([taskInfo.delegate respondsToSelector:@selector(URLSession:dataTask:willCacheResponse:completionHandler:)]) {
        [taskInfo performBlock:^{
            [taskInfo.delegate URLSession:session dataTask:dataTask willCacheResponse:proposedResponse completionHandler:completionHandler];
        }];
    } else {
        completionHandler(proposedResponse);
    }
}


@end
