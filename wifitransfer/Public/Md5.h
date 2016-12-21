//
//  Md5.h
//  PRIS
//
//  Created by huangxiaowei on 10-12-11.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//


#import <Foundation/Foundation.h>


@interface Md5 : NSObject {
    
}

+ (NSString *)encode:(NSString *)aStr;

+ (NSString *)md5OfFile:(NSString *)aFilePath;
+ (NSString *)md5OfFileAcceleration:(NSString *)aFilePath displayName:(NSString *)displayName;
+ (NSString *)md5OfData:(NSData *)data;
@end