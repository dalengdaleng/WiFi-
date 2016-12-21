//
//  ViewController.m
//  WiFi传书功能
//
//  Created by ios on 16/5/21.
//  Copyright © 2016年 KyleWong. All rights reserved.
//

#import "ViewController.h"
#import "WebServerMgr.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
    //这个工程只是简易的wifi传书的代码，wifi传书功能众多，所以只是继承了获得本机ip地址以及打开自定义页面的功能，至于传书过程，需要自定义task功能
    [WebServerMgr webServerStop];
    [WebServerMgr webServerStart];
    //获得本地地址
    NSString *ip  = [WebServerMgr getWebServerAddr];
    NSLog(@"ipaddress is %@",ip);
    
    //如果真正传书，还需要在注释掉的task地方增加代码：wifi传书task
    
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
