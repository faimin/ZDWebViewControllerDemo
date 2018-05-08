//
//  ZDWebViewController.m
//  ZDWebViewControllerDemo
//
//  Created by 符现超 on 2017/3/13.
//  Copyright © 2017年 Zero.D.Saber. All rights reserved.
//
//  https://my.oschina.net/dahuilang123/blog/850246
//  http://www.tuicool.com/articles/n67n2yA

#import "ZDWebViewController.h"
#if __has_include(<ReactiveCocoa/ReactiveCocoa.h>)
#import <ReactiveCocoa/ReactiveCocoa.h>
#endif

UIKIT_STATIC_INLINE UIBarButtonItem *ZD_SpaceItem(CGFloat space) {
    UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:NULL];
    item.width = space;
    return item;
}

NS_CLASS_AVAILABLE_IOS(8_0)
@interface ZDWebViewController () <WKNavigationDelegate, WKUIDelegate, UIGestureRecognizerDelegate>
@property (nonatomic, strong) WKWebView *webView;
@property (nonatomic, copy  ) NSString *urlString;
@property (nonatomic, strong) UIButton *forwardButton;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) NSLayoutConstraint *bottomViewHeightConstraint;
@property (nonatomic, assign) CGFloat bottomViewHeight;
@property (nonatomic, assign) double estimatedProgress;
@property (nonatomic, weak  ) id <UIGestureRecognizerDelegate> originalDelegate;
@end

@implementation ZDWebViewController

#pragma mark - Public Method

+ (__kindof UIViewController *)webViewControllerWithURL:(NSString *)urlString
                                          pushOrPresent:(ShowType)type {
    __kindof UIViewController *vc = nil;
    ZDWebViewController *webVC = [[self alloc] initWithURLString:urlString];
    if (type == ShowType_Present) {
        vc = [[UINavigationController alloc] initWithRootViewController:webVC];
    }
    else {
        vc = webVC;
    }
    return vc;
}

+ (void)cleanWKCache {
    if (@available(iOS 9.0, *)) {
#if DEBUG
        [[WKWebsiteDataStore defaultDataStore] fetchDataRecordsOfTypes:[WKWebsiteDataStore allWebsiteDataTypes] completionHandler:^(NSArray<WKWebsiteDataRecord *> * _Nonnull webRecords) {
            for (WKWebsiteDataRecord *record in webRecords) {
                NSLog(@"%@", record.displayName);
            }
        }];
#endif
        
        NSSet *websiteDataTypes = [NSSet setWithArray:@[WKWebsiteDataTypeDiskCache, WKWebsiteDataTypeMemoryCache]]; // [WKWebsiteDataStore allWebsiteDataTypes]
        NSDate *dateFrom = [NSDate dateWithTimeIntervalSince1970:0];
        // Execute
        [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:websiteDataTypes modifiedSince:dateFrom completionHandler:^{
            NSLog(@"WKCache 清理完毕");
            // Done
        }];
    } else {
        NSString *cachePath = [[NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingString:@"/Cookies"];
        [[NSFileManager defaultManager] removeItemAtPath:cachePath error:nil];
    }
}

#pragma mark - Life Cycle

- (void)dealloc {
    if (_webView.isLoading) {
        [_webView stopLoading];
    }
}

- (instancetype)initWithURLString:(NSString *)urlString {
    if (self = [super init]) {
        _urlString = urlString;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    self.automaticallyAdjustsScrollViewInsets = NO;
    self.edgesForExtendedLayout = UIRectEdgeNone;
    //self.navigationItem.leftItemsSupplementBackButton = YES;
    
    self.bottomViewHeight = _bottomViewHeight ?: 49;
    
    [self setupView];
    [self loadWebView];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.navigationController.viewControllers.count > 1) {
        self.originalDelegate = self.navigationController.interactivePopGestureRecognizer.delegate;
        self.navigationController.interactivePopGestureRecognizer.delegate = self;
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if (self.originalDelegate) {
        self.navigationController.interactivePopGestureRecognizer.delegate = self.originalDelegate;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
    [self.class cleanWKCache];
}

- (void)loadWebView {
    [self loadWebViewWithURLString:_urlString];
}

- (void)setupView {
    [self setupNavigatioinItems];
    [self webView];
    [self setupBottomView];
    
#if __has_include(<ReactiveCocoa/ReactiveCocoa.h>)
    RAC(self, estimatedProgress) = RACObserve(self.webView, estimatedProgress);
    RAC(self, title) = RACObserve(self.webView, title);
    RAC(self.backButton, enabled) = RACObserve(self.webView, canGoBack);
    RAC(self.forwardButton, enabled) = RACObserve(self.webView, canGoForward);
#endif
}

- (void)setupNavigatioinItems {
    CGFloat fontSize = 14.0;
    
    UIButton *backButton = ({
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.backgroundColor = [UIColor blackColor];
        [button setImage:[UIImage imageNamed:@"icon_back"] forState:UIControlStateNormal];
        [button setTitle:@"返回" forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:fontSize];
        CGFloat space = 2.5;
        button.imageEdgeInsets = UIEdgeInsetsMake(0, -space, 0, space);
        button.titleEdgeInsets = UIEdgeInsetsMake(0, space, 0, -space);
        button.contentEdgeInsets = UIEdgeInsetsMake(0, space, 0, space);
        [button sizeToFit];
        [button addTarget:self action:@selector(returnPreOrPop) forControlEvents:UIControlEventTouchUpInside];
        button;
    });
    UIButton *closeButton = ({
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.backgroundColor = [UIColor blackColor];
        [button setTitle:@"关闭" forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:fontSize];
        [button sizeToFit];
        [button addTarget:self action:@selector(closeWebView) forControlEvents:UIControlEventTouchUpInside];
        button;
    });
    UIButton *refreshButton = ({
        UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
        button.backgroundColor = [UIColor blackColor];
        [button setTitle:@"刷新" forState:UIControlStateNormal];
        button.titleLabel.font = [UIFont systemFontOfSize:fontSize];
        [button sizeToFit];
        [button addTarget:self action:@selector(refreshWebView) forControlEvents:UIControlEventTouchUpInside];
        button;
    });
    
    UIBarButtonItem *leftItem1 = [[UIBarButtonItem alloc] initWithCustomView:backButton];
    UIBarButtonItem *leftItem2 = [[UIBarButtonItem alloc] initWithCustomView:closeButton];
    
    UIBarButtonItem *rightItem = [[UIBarButtonItem alloc] initWithCustomView:refreshButton];
    
    self.navigationItem.leftBarButtonItems = @[ZD_SpaceItem(-10), leftItem1, leftItem2];
    // 从右往左排列
    self.navigationItem.rightBarButtonItems = @[ZD_SpaceItem(-10), rightItem];
}

#pragma mark - Privete Method

- (void)loadWebViewWithURLString:(NSString *)urlString {
    if (urlString.length == 0) return;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString]
                                             cachePolicy:NSURLRequestReturnCacheDataElseLoad
                                         timeoutInterval:10];
    [self.webView loadRequest:request];
}

// 返回到最后一页的时候直接pop回上一界面
- (void)returnPreOrPop {
    if ([self.webView canGoBack]) {
        [self.webView goBack];
    }
    else {
        [self closeWebView];
    }
}

- (void)goBack {
    if ([self.webView canGoBack]) {
        [self.webView goBack];
    }
}

- (void)goForward {
    if ([self.webView canGoForward]) {
        [self.webView goForward];
    }
}

- (void)closeWebView {
    if (self.presentingViewController) {
        [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
    }
    else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

- (void)refreshWebView {
    [self.webView reload];
}

#pragma mark - WKNavigationDelegate

/// 准备加载页面(还没开始)。等同于UIWebViewDelegate: - webView:shouldStartLoadWithRequest:navigationType
- (void)webView:(WKWebView *)webView didStartProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"准备加载");
}

/// 数据内容开始加载. 等同于UIWebViewDelegate: - webViewDidStartLoad:
- (void)webView:(WKWebView *)webView didCommitNavigation:(WKNavigation *)navigation {
    NSLog(@"开始加载，内容开始返回");
}

/// 页面加载完成。 等同于UIWebViewDelegate: - webViewDidFinishLoad:
- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    // 删除顶部导航和底部链接
    NSMutableString *js1 = ({
        NSMutableString *js = [[NSMutableString alloc] init];
        [js appendString:@"var header = document.getElementsByTagName('header')[0];"];
        [js appendString:@"header.parentNode.removeChild(header);"];
        [js appendString:@"var footer = document.getElementsByTagName('footer')[0];"];
        [js appendString:@"footer.parentNode.removeChild(footer);"];
        js;
    });
    [webView evaluateJavaScript:js1 completionHandler:^(id _Nullable value, NSError * _Nullable error) {
        if (error) {
            NSLog(@"error = %@", error.localizedDescription);
        }
    }];
    
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.25 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        NSMutableString *js2 = ({
            NSMutableString *js = [[NSMutableString alloc] init];
            [js appendString:@"var list = document.body.childNodes;"];
            [js appendString:@"var len = list.length;"];
            [js appendString:@"var banner = list[len-1];"];
            [js appendString:@"banner.parentNode.removeChild(banner);"];
            js;
        });
        [webView evaluateJavaScript:js2 completionHandler:^(id _Nullable value, NSError * _Nullable error) {
            if (error) {
                NSLog(@"error = %@", error.localizedDescription);
            }
        }];
    });
    
    NSLog(@"页面加载完成");
}

/// 开始加载数据时发生错误，调用
- (void)webView:(WKWebView *)webView didFailProvisionalNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"开始加载数据时出错：%@", error.localizedDescription);
}

/// 页面数据加载过程中发生错误导致的加载失败。 等同于UIWebViewDelegate: - webView:didFailLoadWithError:
- (void)webView:(WKWebView *)webView didFailNavigation:(WKNavigation *)navigation withError:(NSError *)error {
    NSLog(@"页面数据加载过程中：%@", error.localizedDescription);
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_9_0
/// 加载中断时调用
- (void)webViewWebContentProcessDidTerminate:(WKWebView *)webView {
    NSLog(@"加载中断");
    [webView reload];
}
#endif

/// 根据webView、navigationAction相关信息决定这次跳转是否可以继续进行,这些信息包含HTTP发送请求，如头部包含User-Agent,Accept,refer
/// 在发送请求之前，决定是否跳转的代理
- (void)webView:(WKWebView *)webView decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSLog(@"在发送请求之前决定是否跳转");
    decisionHandler(WKNavigationActionPolicyAllow);
}

/// 这个代理方法表示当客户端收到服务器的响应头，根据response相关信息，可以决定这次跳转是否可以继续进行。
/// 在收到服务器的响应头时调用，决定是否跳转的代理
- (void)webView:(WKWebView *)webView decidePolicyForNavigationResponse:(WKNavigationResponse *)navigationResponse decisionHandler:(void (^)(WKNavigationResponsePolicy))decisionHandler {
    NSLog(@"收到响应头，并判定是否跳转");
    decisionHandler(WKNavigationResponsePolicyAllow);
}

/// 收到服务器重定向(Redirect)请求后调用
- (void)webView:(WKWebView *)webView didReceiveServerRedirectForProvisionalNavigation:(WKNavigation *)navigation {
    NSLog(@"接收到服务器重定向请求");
}

/// SSL认证时调用
- (void)webView:(WKWebView *)webView didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential * _Nullable))completionHandler {
    NSLog(@"SSL认证时调用");
    completionHandler(NSURLSessionAuthChallengePerformDefaultHandling, nil);
}

#pragma mark - WKUIDelegate

/***  注意！必须返回一个新的WKWebView，而不能是原来的
 1、必须使用指定的配置（configuration）来创建新的WKWebView
 2、必须加入视图中webView.addSubview(web)//动画自己可自己定义
 3、代理需要重新设置（optional）
 **/
- (WKWebView *)webView:(WKWebView *)webView createWebViewWithConfiguration:(WKWebViewConfiguration *)configuration forNavigationAction:(WKNavigationAction *)navigationAction windowFeatures:(WKWindowFeatures *)windowFeatures {
    WKWebView *webView_new = [[WKWebView alloc] initWithFrame:webView.bounds configuration:configuration];
    webView_new.navigationDelegate = self;
    webView_new.UIDelegate = self;
    [webView addSubview:webView_new];
    return webView_new;
}

/// JS的事件被WKWebview拦截了，需要在此代理方法中调用原生的alert、confirm、prompt事件
/// 最后都必须调用 completionHandler()
/// 弹框
- (void)webView:(WKWebView *)webView runJavaScriptAlertPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(void))completionHandler{
    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"😋😀😋😀" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertView addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler();
    }]];
    [self presentViewController:alertView animated:YES completion:nil];
}

/// 选择框
- (void)webView:(WKWebView *)webView runJavaScriptConfirmPanelWithMessage:(NSString *)message initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(BOOL))completionHandler {
    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"😋😀😋😀" message:message preferredStyle:UIAlertControllerStyleAlert];
    [alertView addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
        [alertView dismissViewControllerAnimated:YES completion:nil];
    }]];
    [alertView addAction:[UIAlertAction actionWithTitle:@"放弃" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(YES);
        [alertView dismissViewControllerAnimated:YES completion:nil];
    }]];
    [self presentViewController:alertView animated:YES completion:nil];
}

/// 输入框
- (void)webView:(WKWebView *)webView runJavaScriptTextInputPanelWithPrompt:(NSString *)prompt defaultText:(NSString *)defaultText initiatedByFrame:(WKFrameInfo *)frame completionHandler:(void (^)(NSString * _Nullable))completionHandler {
    UIAlertController *alertView = [UIAlertController alertControllerWithTitle:@"😋😀😋😀" message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertView addTextFieldWithConfigurationHandler:^(UITextField * _Nonnull textField) {
        textField.textColor = [UIColor redColor];
        textField.placeholder = @"测试placeholder";
    }];
    [alertView addAction:[UIAlertAction actionWithTitle:@"确定" style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
        completionHandler(@"game over");
    }]];
    [self presentViewController:alertView animated:YES completion:nil];
}

#if __IPHONE_OS_VERSION_MAX_ALLOWED > __IPHONE_10_0
/// 这个方法只会调用元素在WebKit默认的预览,这是限于链接。在未来,它可以调用附加的元素
- (BOOL)webView:(WKWebView *)webView shouldPreviewElement:(WKPreviewElementInfo *)elementInfo {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    return YES;
}

- (UIViewController *)webView:(WKWebView *)webView previewingViewControllerForElement:(WKPreviewElementInfo *)elementInfo defaultActions:(NSArray<id<WKPreviewActionItem>> *)previewActions {
    NSLog(@"%@", NSStringFromSelector(_cmd));
    return nil;
}

- (void)webView:(WKWebView *)webView commitPreviewingViewController:(UIViewController *)previewingViewController {
    NSLog(@"%@", NSStringFromSelector(_cmd));
}
#endif

#pragma mark - Getter

- (void)setupBottomView {
    UIView *bottomView = ({
        UIView *view = [[UIView alloc] initWithFrame:CGRectZero];
        view.backgroundColor = [UIColor lightGrayColor];
        [self.view addSubview:view];
        
        UIButton *backButton = ({
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            //[button setImage:[UIImage imageNamed:@"xxxx"] forState:UIControlStateNormal];
            [button setTitle:@"后退" forState:UIControlStateNormal];
            [button addTarget:self action:@selector(goBack) forControlEvents:UIControlEventTouchUpInside];
            button;
        });
        self.backButton = backButton;
        
        UIButton *forwardButton = ({
            UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
            //[button setImage:[UIImage imageNamed:@"xxxx"] forState:UIControlStateNormal];
            [button setTitle:@"前进" forState:UIControlStateNormal];
            [button addTarget:self action:@selector(goForward) forControlEvents:UIControlEventTouchUpInside];
            button;
        });
        self.forwardButton = forwardButton;
        
        [view addSubview:backButton];
        [view addSubview:forwardButton];
        
        backButton.translatesAutoresizingMaskIntoConstraints = NO;
        NSLayoutConstraint *backCentYConstraint = [NSLayoutConstraint constraintWithItem:backButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
        NSLayoutConstraint *backBottomConstraint = [NSLayoutConstraint constraintWithItem:backButton attribute:NSLayoutAttributeLeft relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeLeft multiplier:1 constant:30];
        
        forwardButton.translatesAutoresizingMaskIntoConstraints = NO;
        NSLayoutConstraint *forwardCentYConstraint = [NSLayoutConstraint constraintWithItem:forwardButton attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeCenterY multiplier:1 constant:0];
        NSLayoutConstraint *forwardBottomConstraint = [NSLayoutConstraint constraintWithItem:forwardButton attribute:NSLayoutAttributeRight relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeRight multiplier:1 constant:-30];
        
        [view addConstraints:@[backCentYConstraint, backBottomConstraint, forwardCentYConstraint, forwardBottomConstraint]];
        
        view;
    });
    
    bottomView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|" options:NSLayoutFormatDirectionLeftToRight metrics:nil views:@{@"view":bottomView}]];
    NSLayoutConstraint *bottomConstraint = [NSLayoutConstraint constraintWithItem:bottomView attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0];
    NSLayoutConstraint *heightConstraint = [NSLayoutConstraint constraintWithItem:bottomView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:_bottomViewHeight];
    self.bottomViewHeightConstraint = heightConstraint;
    
    NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:bottomView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.webView attribute:NSLayoutAttributeBottom multiplier:1.0 constant:0.0];
    [self.view addConstraints:@[bottomConstraint, heightConstraint, topConstraint]];
}

- (WKWebView *)webView {
    if (!_webView) {
        _webView = ({
            WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
            WKPreferences *preferences = [[WKPreferences alloc] init];
            preferences.javaScriptCanOpenWindowsAutomatically = YES;
            preferences.javaScriptEnabled = YES;
            config.preferences = preferences;
            config.allowsInlineMediaPlayback = YES;
            
            WKWebView *webView = [[WKWebView alloc] initWithFrame:(CGRect){CGPointZero, CGRectGetWidth(self.view.bounds), CGRectGetHeight(self.view.bounds)-_bottomViewHeight} configuration:config];
            webView.backgroundColor = [UIColor colorWithRed:0.157 green:0.137 blue:0 alpha:1];
            webView.navigationDelegate = self;
            webView.UIDelegate = self;
            webView.allowsBackForwardNavigationGestures = YES;
            if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_9_0) {
                webView.allowsLinkPreview = YES;
            }
            webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            [self.view addSubview:webView];
            
            webView.translatesAutoresizingMaskIntoConstraints = NO;
            NSArray *horizonConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[webView]|" options:NSLayoutFormatDirectionLeftToRight metrics:nil views:@{@"webView":webView}];
            NSLayoutConstraint *topConstraint = [NSLayoutConstraint constraintWithItem:webView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0 constant:0.0];
            [self.view addConstraints:horizonConstraints];
            [self.view addConstraint:topConstraint];
            webView;
        });
    }
    return _webView;
}

@end











