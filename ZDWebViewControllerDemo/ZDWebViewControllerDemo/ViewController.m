//
//  ViewController.m
//  ZDWebViewControllerDemo
//
//  Created by 符现超 on 2017/3/13.
//  Copyright © 2017年 Zero.D.Saber. All rights reserved.
//

#import "ViewController.h"
#import "ZDWebViewController.h"
#import <WebKit/WebKit.h>

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UIButton *button;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)present:(UIButton *)sender {
    __unused NSString *url1 = @"https://github.com/sticksen/STKWebKitViewController";
    
    NSString *urlStr = @"https://github.com/faimin";
    UIViewController *web = [ZDWebViewController webViewControllerWithURL:urlStr pushOrPresent:ShowType_Push];
//    [self presentViewController:web animated:YES completion:^{
//        NSLog(@"弹出");
//    }];
    
    [self.navigationController pushViewController:web animated:YES];
}

@end
