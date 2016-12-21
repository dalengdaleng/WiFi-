//
//  Util.m
//  PRIS
//
//  Created by huangxiaowei on 10-12-22.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//

//#import "DateUtil.h"
#include <sys/xattr.h>
#include <unistd.h>
#include <dirent.h>
#import "Md5.h"
#import <UIKit/UIKit.h>

void parseStringToVersion(NSString* aVersionStr, int* aMajor, int* aMinor, int* aRevision)
{
	assert(aMajor);
	assert(aMinor);
	assert(aRevision);
	
	int majorVer = 0;
	int minorVer = 0;
	int revisionVer = 0;
	if (aVersionStr)
	{
		NSArray *verArray = [aVersionStr componentsSeparatedByString:@"."];
		if  ([verArray count] > 0)
		{
			NSString *ver = [verArray objectAtIndex:0];
			majorVer = [ver intValue];
		}
		if  ([verArray count] > 1)
		{
			NSString *ver = [verArray objectAtIndex:1];
			minorVer = [ver intValue];
		}
		if  ([verArray count] > 2)
		{
			NSString *ver = [verArray objectAtIndex:2];
			revisionVer = [ver intValue];
		}		
	}
	
	*aMajor = majorVer;
	*aMinor = minorVer;
	*aRevision = revisionVer;
}


int versionCompare(NSString* aVersion1, NSString *aVersion2)
{
	int ver1Major = 0;
	int ver1Minor = 0;
	int ver1Revision = 0;
	int ver2Major = 0;
	int ver2Minor = 0;
	int ver2Revision = 0;	
	parseStringToVersion(aVersion1, &ver1Major, &ver1Minor, &ver1Revision);
	parseStringToVersion(aVersion2, &ver2Major, &ver2Minor, &ver2Revision);	
	
	if (ver1Major > ver2Major)
	{
		return 1;
	}
	else if (ver1Major < ver2Major)
	{
		return -1;
	}
	
	if (ver1Minor > ver2Minor)
	{
		return 1;
	}
	else if (ver1Minor < ver2Minor)
	{
		return -1;
	}	
	
	if (ver1Revision > ver2Revision)
	{
		return 1;
	}
	else if (ver1Revision < ver2Revision)
	{
		return -1;
	}	
	
	return 0;
}



BOOL addSkipBackupAttributeToItemAtPath(NSString *aPath)
{
    if(![[NSFileManager defaultManager] fileExistsAtPath:aPath]){
        return NO;
    }
    
    NSError *error = nil;
    BOOL success = NO;
    
    NSString *systemVersion = [[UIDevice currentDevice] systemVersion];
    if ([systemVersion floatValue] >= 5.1f)
    {
        success = [[NSURL fileURLWithPath:aPath] setResourceValue:[NSNumber numberWithBool:YES]
                                                               forKey:@"NSURLIsExcludedFromBackupKey"
                                                                error:&error];
    }
    else if ([systemVersion isEqualToString:@"5.0.1"])
    {
        const char* filePath = [aPath fileSystemRepresentation];
        const char* attrName = "com.apple.MobileBackup";
        u_int8_t attrValue = 1;
        
        int result = setxattr(filePath, attrName, &attrValue, sizeof(attrValue), 0, 0);
        success = (result == 0);
    }
    else
    {
        NSLog(@"Can not add 'do no back up' attribute at systems before 5.0.1");
    }
    
    if(!success)
    {
        NSLog(@"Error excluding %@ from backup %@", [aPath lastPathComponent], error);
    }
    
    return success;
}

BOOL IsFileExist(NSString* fullName)
{
    if (fullName == nil)
        return NO;
//	BOOL isdir = NO ;
//    NSFileManager *fileMgr = [[NSFileManager alloc] init];
//	BOOL ret = [fileMgr fileExistsAtPath:fullName isDirectory:&isdir];
//	
//	if (ret && (isdir == YES)){
//		ret = NO;
//	}
//	
//    [fileMgr release];

    BOOL ret = NO;
    if (access([fullName cStringUsingEncoding:NSUTF8StringEncoding], F_OK)==0){
        ret = YES;
    }

	return ret;
}

BOOL IsFolderExist(NSString *path)
{
	if (path == nil)
        return NO;
    
//	BOOL isdir = NO ;
//    NSFileManager *fileMgr = [[NSFileManager alloc] init];
//	BOOL ret = [fileMgr fileExistsAtPath:path isDirectory:&isdir];
//	
//	if (ret)
//	{
//		ret = isdir ;
//	}
//    
//    [fileMgr release];
    
    BOOL ret = NO;
    DIR *pdir = opendir([path cStringUsingEncoding:NSUTF8StringEncoding]);
    
    if(pdir) {
        ret = YES;
        //4.8.5 关闭pdir
        closedir(pdir);
    }

	return ret;
}

BOOL MakeDir(NSString *path)
{
	BOOL isdir = YES ;
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
	BOOL ret = [fileMgr createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
	
	if (ret == NO)
	{
		ret = [fileMgr fileExistsAtPath:path isDirectory:&isdir];
	}
    [fileMgr release];
    addSkipBackupAttributeToItemAtPath(path);
	return (ret && isdir);
}

BOOL MakeDirWithBackupAttr(NSString *path)
{
	BOOL isdir = YES ;
    NSFileManager *fileMgr = [[NSFileManager alloc] init];
	BOOL ret = [fileMgr createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:nil];
	
	if (ret == NO)
	{
		ret = [fileMgr fileExistsAtPath:path isDirectory:&isdir];
	}
    [fileMgr release];
    addSkipBackupAttributeToItemAtPath(path);
    
	return (ret && isdir);
}

BOOL validateUrl(NSString *candidate)
{
    if ([candidate hasPrefix:@"http"] || [candidate hasPrefix:@"https"]){
        return YES;
    }
    return NO;
    /*
    NSString *urlRegEx = @"(http|https)://((\\w)*|([0-9]*)|([-|_])*)+([\\.|/]((\\w)*|([0-9]*)|([-|_])*))+";
    NSPredicate *urlTest = [NSPredicate predicateWithFormat:@"SELF MATCHES %@", urlRegEx];
    return [urlTest evaluateWithObject:candidate];
    */
}

NSString* PRISBookId2IAPBookId(NSString *aBookId)
{
    if (aBookId == nil)
        return nil;
    NSMutableString *str = [NSMutableString stringWithString:aBookId];
    [str replaceOccurrencesOfString:@"_" withString:@"." options:NSCaseInsensitiveSearch range:NSMakeRange(0, [str length])];
    return str;
}

NSString* IAPBookId2PRISBookId(NSString *aBookId)
{
    if (aBookId == nil)
        return nil;
    NSMutableString *str = [NSMutableString stringWithString:aBookId];
    [str replaceOccurrencesOfString:@"." withString:@"_" options:NSCaseInsensitiveSearch range:NSMakeRange(0, [str length])];
    return str;
}

NSString* fileNameMd5(NSString *aFileName)
{
    NSString *newFileName = nil;
    
    newFileName = [Md5 encode:aFileName];
    if ([aFileName pathExtension])
        newFileName = [newFileName stringByAppendingPathExtension:[aFileName pathExtension]];
    if (newFileName == nil)
        return @"";
    return newFileName;
}
