//
//  Md5.m
//  PRIS
//
//  Created by huangxiaowei on 10-12-11.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "Md5.h"
#import <CommonCrypto/CommonDigest.h>

@implementation Md5

+ (NSString *)encode:(NSString *)aStr
{
    if ([aStr length] == 0)
    {
        return nil;
    }
	const char *cStr = [aStr UTF8String];
	unsigned char result[16];
	CC_MD5( cStr, strlen(cStr), result );
	return [NSString stringWithFormat:
            @"%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X%02X",
            result[0], result[1], result[2], result[3], 
            result[4], result[5], result[6], result[7],
            result[8], result[9], result[10], result[11],
            result[12], result[13], result[14], result[15]
            ];	
}


+ (NSString *)md5OfFile:(NSString *)aFilePath
{
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:aFilePath];
    if( handle== nil ) {
        return nil;
    }
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    BOOL done = NO;

    int cacheSize = 0;
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
    while(!done)
    {
		NSData* fileData = [handle readDataOfLength: 256];
		CC_MD5_Update(&md5, [fileData bytes], [fileData length]);
		if([fileData length] == 0) {
            done = YES;   
        }
        else
        {
            cacheSize += [fileData length];
            if (cacheSize >= 1024*1024) // 超过1m进行清理。
            {
                [pool drain];
                 pool = [NSAutoreleasePool new];
                cacheSize = 0;
            }            
        }
    }
    [pool drain];    

    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);
    NSString* s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                   digest[0], digest[1], 
                   digest[2], digest[3],
                   digest[4], digest[5],
                   digest[6], digest[7],
                   digest[8], digest[9],
                   digest[10], digest[11],
                   digest[12], digest[13],
                   digest[14], digest[15]];
    
    return s;    
}

+ (NSString *)md5OfFileAcceleration:(NSString *)aFilePath displayName:(NSString *)displayName
{
    NSFileHandle *handle = [NSFileHandle fileHandleForReadingAtPath:aFilePath];
    if (handle == nil ) {
        return nil;
    }
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    
//    const char *cStr = nil; //4.8.6 unused Variable
    //导入时，不再允许内容相同而名字不同的书籍导入
//    if (displayName){
//        cStr = [displayName UTF8String];
//    }
//    else{
//        cStr = [[aFilePath lastPathComponent] UTF8String];
//    }
//	CC_MD5_Update(&md5, cStr, strlen(cStr));
    
    BOOL done = NO;
    int i = 0;
    
	unsigned long long offset;
    while (!done)
    {
		NSData* fileData = [handle readDataOfLength: 128];
		CC_MD5_Update(&md5, [fileData bytes], [fileData length]);
		if ([fileData length] == 0) {
            done = YES;
        }
        if (++i > 10)
            done = YES;
        offset = [handle offsetInFile];
        [handle seekToFileOffset:256 + offset];
    }
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);
    NSString* s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                   digest[0], digest[1],
                   digest[2], digest[3],
                   digest[4], digest[5],
                   digest[6], digest[7],
                   digest[8], digest[9],
                   digest[10], digest[11],
                   digest[12], digest[13],
                   digest[14], digest[15]];
    
    return s;
}

#define DATA_BUF_LEN 256
+ (NSString *)md5OfData:(NSData *)data
{
    if ([data length] == 0)
        return nil;
    CC_MD5_CTX md5;
    CC_MD5_Init(&md5);
    
    int cacheSize = 0;
    unsigned char buf[DATA_BUF_LEN];
    NSRange rang;
    rang.location = 0;
    rang.length = DATA_BUF_LEN;
    int nTotalLen = [data length];
    int nLen = 0;
    if (nTotalLen < DATA_BUF_LEN)
    {
        rang.length = nTotalLen;
    }
	NSAutoreleasePool * pool = [NSAutoreleasePool new];
    while(nTotalLen > 0)
    {
		[data getBytes: buf range:rang];
        nLen = nTotalLen > DATA_BUF_LEN ? DATA_BUF_LEN : nTotalLen;
        
		CC_MD5_Update(&md5, buf, nLen);
		cacheSize += nLen;
        if (cacheSize >= 1024 * 1024) // 超过1m进行清理。
        {
            [pool drain];
            pool = [NSAutoreleasePool new];
            cacheSize = 0;
        }
        nTotalLen -= nLen;
        rang.location = rang.location + nLen;
        if (nTotalLen < DATA_BUF_LEN)
        {
            rang.length = nTotalLen;
        }
    }
    [pool drain];    
    
    unsigned char digest[CC_MD5_DIGEST_LENGTH];
    CC_MD5_Final(digest, &md5);
    NSString* s = [NSString stringWithFormat: @"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x",
                   digest[0], digest[1], 
                   digest[2], digest[3],
                   digest[4], digest[5],
                   digest[6], digest[7],
                   digest[8], digest[9],
                   digest[10], digest[11],
                   digest[12], digest[13],
                   digest[14], digest[15]];
    
    return s;    
}

@end