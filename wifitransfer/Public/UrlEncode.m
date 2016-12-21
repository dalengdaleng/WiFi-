//
//  UrlEncode.m
//  PRIS
//
//  Created by huangxiaowei on 10-12-16.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

#import "UrlEncode.h"

const char kHexChars[] = "0123456789ABCDEF";

@implementation UrlEncode

+ (BOOL)needEncode:(NSString *)aStr
{
    int len = [aStr length];
	if(len <= 0)
	{
		return NO;
	}
	
	BOOL needEncode = NO;
	unichar c = 0;
	for (int i=0; i<len; i++) 
	{
		c = [aStr characterAtIndex:i];
		if ('A' <= c && c <= 'Z' )		       // 'A'..'Z'
		{
			continue;
		}
		else if ('a' <= c && c <= 'z')	   // 'a'..'z'
		{
			continue;
		}
		else if ('0' <= c && c <= '9')	   // '0'..'9'
		{
			continue;
		}
		else if (c == '-' || c == '_' || c == '.' || c == '!'      // ≤ª–Ë“™◊™ªØ
                 || c == '~' || c == '*'	|| c == '\'' || c == '(' || c == ')')
		{
			continue;
		}		
		else {
			needEncode = YES;
			break;			
		}
	}
	return needEncode;
}


+ (NSString *)encode:(NSString *)aStr usingEncoding:(NSStringEncoding)aEncoding;
{
	if([aStr length] <= 0)
	{
		return @"";
	}
    
    NSData *data = [aStr dataUsingEncoding:aEncoding];
    int len = [data length];
    
    char *strUtf8 = (char *)[data bytes];
    char *resultUtf8 = (char *)calloc(1, 3*len+3);
    char *to = resultUtf8;
	unsigned char c = 0;
	for (int i=0; i<len; i++) 
	{
		c = (unsigned char)strUtf8[i];
		if ('A' <= c && c <= 'Z' )		       // 'A'..'Z'
		{
			*to++ = c;
		}
		else if ('a' <= c && c <= 'z')	   // 'a'..'z'
		{
			*to++ = c;
		}
		else if ('0' <= c && c <= '9')	   // '0'..'9'
		{
			*to++ = c;
		}
		else if (c == '-' || c == '_' || c == '.' || c == '!'      // ≤ª–Ë“™◊™ªØ
                 || c == '~' || c == '*'	|| c == '\'' || c == '(' || c == ')')
		{
			*to++ = c;
		}		
		else if (c == ' ')				       // space
		{
			*to++ = '+';
		}
		else {
			to[0] = '%';
			to[1] = kHexChars[c >> 4];
			to[2] = kHexChars[c & 15];
			to += 3;
		}
	}
	*to = 0;
    
    NSString *result = [NSString stringWithUTF8String:resultUtf8]; 
    free(resultUtf8);
    
    return result;
}

+ (NSString *)encode:(NSString *)aStr
{
	return [UrlEncode encode:aStr usingEncoding:NSUTF8StringEncoding];
}

+ (NSString *)encodeComment:(NSString *)aStr usingEncoding:(NSStringEncoding)aEncoding
{
    if([aStr length] <= 0)
    {
        return @"";
    }
    
    NSData *data = [aStr dataUsingEncoding:aEncoding];
    int len = [data length];
    
    char *strUtf8 = (char *)[data bytes];
    char *resultUtf8 = (char *)calloc(1, 3*len+3);
    char *to = resultUtf8;
    unsigned char c = 0;
    for (int i=0; i<len; i++)
    {
        c = (unsigned char)strUtf8[i];
        if ('A' <= c && c <= 'Z' )		       // 'A'..'Z'
        {
            *to++ = c;
        }
        else if ('a' <= c && c <= 'z')	   // 'a'..'z'
        {
            *to++ = c;
        }
        else if ('0' <= c && c <= '9')	   // '0'..'9'
        {
            *to++ = c;
        }
        else if (c == '-' || c == '_' || c == '.' || c == '!'      // ≤ª–Ë“™◊™ªØ
                 || c == '~' || c == '*'	|| c == '\'' || c == '(' || c == ')')
        {
            *to++ = c;
        }
        else if (c == ' ')				       // space
        {
            *to++ = ' ';
        }
        else {
            to[0] = '%';
            to[1] = kHexChars[c >> 4];
            to[2] = kHexChars[c & 15];
            to += 3;
        }
    }
    *to = 0;
    
    NSString *result = [NSString stringWithUTF8String:resultUtf8]; 
    free(resultUtf8);
    
    return result;
}
@end


@implementation OAuthPercentEncode

+ (NSString *)encode:(NSString *)aStr
{
	NSString *stringEncoded = (NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
																				  (CFStringRef)aStr,
																				  NULL,
																				  CFSTR("!*'();:@&=+$,/?%#[]"),
																				  kCFStringEncodingUTF8);
	return [stringEncoded autorelease];
}

@end;
