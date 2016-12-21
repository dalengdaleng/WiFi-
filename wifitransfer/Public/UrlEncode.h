//
//  UrlEncode.h
//  PRIS
//
//  Created by huangxiaowei on 10-12-16.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import <Foundation/Foundation.h>



@interface UrlEncode : NSObject {

}
+ (BOOL)needEncode:(NSString *)aStr;
+ (NSString *)encode:(NSString *)aStr;
+ (NSString *)encode:(NSString *)aStr usingEncoding:(NSStringEncoding)aEncoding;
//4.9.0用户评论内容空格不能替换成+
+ (NSString *)encodeComment:(NSString *)aStr usingEncoding:(NSStringEncoding)aEncoding;
@end

@interface OAuthPercentEncode : NSObject
{
}
+ (NSString *)encode:(NSString *)aStr;
@end;