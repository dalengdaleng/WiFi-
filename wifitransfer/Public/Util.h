//
//  Util.h
//  PRIS
//
//  Created by iphone bad on 12/16/10.
//  Copyright 2010 __MyCompanyName__. All rights reserved.
//
//#import "CObject.h"
//#import "PRISLog.h"
//#import "AsynLoader.h"
//#import "AsynLoaderDelegate.h"
//#import "DateUtil.h"
//#import "DeviceInfo.h"
//#import "SafeNetReachability.h"
//#ifndef NDEBUG
//#import "DebugUtil.h"
//#endif
// fit for "1.3.3", "2.0" like version string compare.
// if version1 > version2 return > 0
// if version1 = version2 return 0
// if version1 < version2 return < 0
int versionCompare(NSString *aVersion1, NSString *aVersion2);


BOOL addSkipBackupAttributeToItemAtPath(NSString *aPath);

BOOL IsFileExist(NSString* fullName);
BOOL IsFolderExist(NSString *path);
BOOL MakeDir(NSString *path);
BOOL MakeDirWithBackupAttr(NSString *path);
BOOL validateUrl(NSString *candidate);

NSString* PRISBookId2IAPBookId(NSString *aBookId);
NSString* IAPBookId2PRISBookId(NSString *aBookId);

NSString* fileNameMd5(NSString *aFileName);
