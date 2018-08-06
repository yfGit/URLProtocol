//
//  ViewController.m
//  URLProtocol
//
//  Created by 许毓方 on 2018/8/6.
//  Copyright © 2018 SN. All rights reserved.
//

#import "ViewController.h"
@import WebKit;
#import "XXXURLInterceptor.h"
#import "TestHTTPDNSHandle.h"

@interface ViewController ()

@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, strong) UIProgressView *progressView;

@end

@implementation ViewController
- (void)dealloc
{
    [_webView removeObserver:self forKeyPath:@"estimatedProgress"];
    NSLog(@"%s", __func__);
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [XXXURLInterceptor startMonitoringClass:TestHTTPDNSHandle.class];
    [self loadRequest];
}

- (void)loadRequest
{
    NSString *url = @"https://www.baidu.com/";
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [self.webView loadRequest:request];
}

- (IBAction)reloadAction:(UIBarButtonItem *)sender {
    [self.webView reloadFromOrigin];
}


- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"estimatedProgress"]) {
        CGFloat newProgress = [[change objectForKey:NSKeyValueChangeNewKey] doubleValue];
        
        self.progressView.alpha = 1;
        [self.progressView setProgress:newProgress animated:YES];
        
        if (newProgress >= 1) {
            [UIView animateWithDuration:0.8 animations:^{
                self.progressView.alpha = 0;
            }completion:^(BOOL finished) {
                [self.progressView setProgress:0 animated:NO];
            }];
        }
    }
}

- (WKWebView *)webView
{
    if (!_webView) {
        WKWebViewConfiguration *config = [WKWebViewConfiguration new];
        _webView = [[WKWebView alloc] initWithFrame:self.view.bounds configuration:config];
        _webView.allowsBackForwardNavigationGestures = YES;
        [_webView addObserver:self forKeyPath:@"estimatedProgress" options:NSKeyValueObservingOptionNew context:nil];
        [self.view addSubview:_webView];
        [self.webView addSubview:self.progressView];
    }
    return _webView;
}

- (UIProgressView *)progressView
{
    if (!_progressView) {
        _progressView = [[UIProgressView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.navigationController.navigationBar.frame), [UIScreen mainScreen].bounds.size.width, 2)];
        _progressView.tintColor      = [UIColor orangeColor];
        _progressView.trackTintColor = [UIColor whiteColor];
    }
    return _progressView;
}


@end
