//
//  UrlDecode.m
//  PRIS
//
//  Created by zhangcj on on 13-01-16.
//  Copyright 2013 Netease Co.Ltm All rights reserved.
//


#import "UrlDecode.h"

@implementation UrlDecode

+ (NSString *)decode:(NSString *)encodedStr
{
    //NSString *result = [encodedStr stringByReplacingOccurrencesOfString:@"+" withString:@" "];
    NSString *result = [encodedStr stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    return result;
}
@end
