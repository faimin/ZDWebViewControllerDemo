//
//  ZDWebViewController.h
//  ZDWebViewControllerDemo
//
//  Created by 符现超 on 2017/3/13.
//  Copyright © 2017年 Zero.D.Saber. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

typedef NS_ENUM(NSUInteger, ShowType) {
    ShowType_Push,
    ShowType_Present,
};

@interface ZDWebViewController : UIViewController

@property (nonatomic, strong, readonly) NSLayoutConstraint *bottomViewHeightConstraint;
@property (nonatomic, strong, readonly) WKWebView *webView;
@property (nonatomic, copy, readonly) NSString *urlString;

+ (__kindof UIViewController *)webViewControllerWithURL:(NSString *)urlString
                                          pushOrPresent:(ShowType)type;

+ (void)cleanWKCache;

@end
