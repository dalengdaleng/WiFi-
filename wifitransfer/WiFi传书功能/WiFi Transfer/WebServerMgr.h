
//
//  WebServerMgr.h
//  PRIS
//
//  Created by zhangcj on 13-01-09
//  Copyright 2013 NetEase Co.Ltd. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WebServerMgr : NSObject

+ (void) webServerStop;
+ (BOOL) webServerStart;
+ (NSString*) getWebServerAddr;
@end
