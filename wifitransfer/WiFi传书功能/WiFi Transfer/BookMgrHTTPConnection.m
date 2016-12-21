#import "BookMgrHTTPConnection.h"
#import <HttpServerFramework/HTTPMessage.h>
#import <HttpServerFramework/HTTPDataResponse.h>
#import <HttpServerFramework/DELETEResponse.h>
#import <HttpServerFramework/HTTPLogging.h>

#import <HttpServerFramework/MultipartFormDataParser.h>
#import <HttpServerFramework/MultipartMessageHeaderField.h>
#import <HttpServerFramework/HTTPFileResponse.h>
#import "NSObject+SBJSON.h"

#import "Util.h"


#import "Md5.h"
#import "UrlDecode.h"
#import "WebServerMgr.h"

#define ARRAY_SIZE              (5)
static NSString*                g_uploadFileName[ARRAY_SIZE] = {nil};
static NSString*                g_bookId = nil;
static UInt64                   g_totalSize[ARRAY_SIZE];
static UInt64                   g_recvedSize[ARRAY_SIZE];
static eOpState                 g_server_state = eIdle;
static int                      g_cur_index = 0;
static int                      g_uploadResult[ARRAY_SIZE];
static BOOL                     g_uploadCancled = NO;

// Log levels : off, error, warn, info, verbose
// Other flags: trace
//static const int httpLogLevel = HTTP_LOG_LEVEL_VERBOSE; // | HTTP_LOG_FLAG_TRACE;

/**
 * All we have to do is override appropriate methods in HTTPConnection.
 **/

void resetWebServerState(void)
{
    g_server_state = eIdle;
    for (int i = 0; i < ARRAY_SIZE; i++)
    {
        if (g_uploadFileName[i])
        {
            [g_uploadFileName[i] release];
            g_uploadFileName[i] = nil;
        }
        g_uploadResult[i] = 200;
    }
    if (g_bookId)
    {
        [g_bookId release];
        g_bookId = nil;
    }
    g_cur_index = 0;
}

@implementation BookMgrHTTPConnection

@synthesize storeFile = _storeFile;
@synthesize parser = _parser;
@synthesize path = _path;

- (void)dealloc {
    [_parser release];
    [_path release];
    if (_storeFile)
    {
        [_storeFile closeFile];
        [_storeFile release];
        _storeFile = nil;
    }
    switch (currentOpState) {
        case eUpload:
            //NSLog(@"dealloc upload");
            if (uploadOk == NO)
            {
                NSFileManager *fileMgr = [[NSFileManager alloc] init];
                [fileMgr removeItemAtPath:[[self getBookUploadDir] stringByAppendingPathComponent:g_uploadFileName[g_cur_index]] error:nil];
                [fileMgr release];
            }
        case eGet:
        case eDelete:
            g_server_state = eIdle;
            break;
        default:
            break;
    }

	[super dealloc];
}

- (BOOL)supportsMethod:(NSString *)method atPath:(NSString *)path
{
    //NSLog(@"supportsMethod");
	// Add support for POST
    if (errCode == 503)
    {
        return YES;
    }
    errCode = 200;
    self.path = [UrlDecode decode:[path lastPathComponent]];
    currentRequest = eOther;
	if ([method isEqualToString:@"POST"])
	{
        if (g_server_state == eIdle)
        {
            if ([path isEqualToString:@"/files"])//upload
            {
                currentOpState = eUpload;
                g_server_state = eUpload;
                currentRequest = eUpload;
            }
            else if ([path hasPrefix:@"/files/"])//delete
            {
                currentOpState = eDelete;
                g_server_state = eDelete;
                currentRequest = eDelete;
                if (g_bookId)
                    [g_bookId release];
                
                //g_bookId = [[Md5 encode:fileName] retain];
                g_bookId = [[path substringFromIndex:[@"/files/" length]] retain];
            }
        }
        else
        {
            errCode = 503;
        }
		return YES;
	}
	if ([method isEqualToString:@"GET"])
    {
        if ([path hasPrefix:@"/files/"])//download
        {
            if (g_server_state == eIdle)
            {
                currentOpState = eGet;
                g_server_state = eGet;
                currentRequest = eGet;
                if (g_bookId)
                {
                    [g_bookId release];
                    g_bookId = nil;
                }
                
                path = [UrlDecode decode:path];
                //g_bookId = [[Md5 encode:fileName] retain];
                g_bookId = [path substringFromIndex:[@"/files/" length]];
                NSArray *subArray = [[path substringFromIndex:[@"/files/" length]] componentsSeparatedByString:@"/"];
                if ([subArray count])
                {
                    g_bookId = [[subArray objectAtIndex:0] retain];
                }
            }
            else
            {
                errCode = 503;
            }
        }
        else if ([path hasPrefix:@"/progress/"])//get progress
        {
            NSString *fileName = [UrlDecode decode:[path lastPathComponent]];
            NSArray *arr = [fileName componentsSeparatedByString:@"?"];
            fileName = [arr objectAtIndex:0];
            
            errCode = 404;
            for (int i = 0; i < ARRAY_SIZE; i++)
            {
                if ([fileName isEqualToString:g_uploadFileName[i]])
                {
                    errCode = 200;
                    _index = i;
                    break;
                }
            }
            
            currentRequest = eGetProgress;
        }
        else if ([path hasPrefix:@"/files?"])//get book info
        {
            currentRequest = eGetBookInfo;
        }
        else if ([path hasPrefix:@"/out"])//cancle upload
        {
            if (g_server_state == eUpload)
            {
                NSString *fileName = [UrlDecode decode:[path lastPathComponent]];
                NSArray *arr = [fileName componentsSeparatedByString:@"?"];
                fileName = [arr objectAtIndex:0];
                
                if ([fileName isEqualToString:g_uploadFileName[g_cur_index]])
                {
                    g_uploadCancled = YES;
                }
            }
            
            currentRequest = eDisconnect;
        }
        return YES;
    }
	return [super supportsMethod:method atPath:path];
}

- (BOOL)expectsRequestBodyFromMethod:(NSString *)method atPath:(NSString *)path statusCode:(int *)code
{
    //NSLog(@"expectsRequestBodyFromMethod method: %@; path: %@", method, path);
	uploadOk = YES;
    
	// Inform HTTP server that we expect a body to accompany a POST request
    if ([method isEqualToString:@"POST"])
    {
        //NSLog(@"expectsRequestBodyFromMethod method: %@; path: %@", method, path);
        if ([path isEqualToString:@"/files"]) {
            if (g_server_state != eIdle)
            {
                errCode = 503;
                if (code)
                    *code = 503;
                NSLog(@"expectsRequestBodyFromMethod busy: %@", path);
                return NO;
            }
            // here we need to make sure, boundary is set in header
            NSString* contentType = [request headerField:@"Content-Type"];
            int paramsSeparator = [contentType rangeOfString:@";"].location;
            if (NSNotFound == paramsSeparator ) {
                return NO;
            }
            if (paramsSeparator >= contentType.length - 1 ) {
                return NO;
            }
            NSString* type = [contentType substringToIndex:paramsSeparator];
            if (![type isEqualToString:@"multipart/form-data"] ) {
                // we expect multipart/form-data content type
                return NO;
            }
            
            // enumerate all params in content-type, and find boundary there
            NSArray* params = [[contentType substringFromIndex:paramsSeparator + 1] componentsSeparatedByString:@";"];
            for( NSString* param in params ) {
                paramsSeparator = [param rangeOfString:@"="].location;
                if ((NSNotFound == paramsSeparator) || paramsSeparator >= param.length - 1 ) {
                    continue;
                }
                NSString* paramName = [param substringWithRange:NSMakeRange(1, paramsSeparator-1)];
                NSString* paramValue = [param substringFromIndex:paramsSeparator+1];
                
                if ([paramName isEqualToString: @"boundary"]) {
                    // let's separate the boundary from content-type, to make it more handy to handle
                    [request setHeaderField:@"boundary" value:paramValue];
                }
            }
            // check if boundary specified
            if (nil == [request headerField:@"boundary"])  {
                return NO;
            }
            
            return YES;
        }
    }

	return [super expectsRequestBodyFromMethod:method atPath:path statusCode:code];
}

- (NSObject<HTTPResponse> *)httpResponseForMethod:(NSString *)method URI:(NSString *)path
{
    //NSLog(@"httpResponseForMethod");
    if (errCode != 200)
    {
        NSLog(@"code: %d; state: %d; global state: %d", errCode, currentRequest, g_server_state);
        return [[[HTTPDataResponse alloc] initWithData: nil status:errCode] autorelease];
    }
	if (currentRequest == eDelete)
    {
//        DeleteBookTask *task = [[DeleteBookTask alloc] initWithBookId:g_bookId];
//        [gDataEngine syncRunTask:task];
//        errCode = task.status;
//        [task release];
        currentOpState = eIdle;
        g_server_state = eIdle;
        return [[[HTTPDataResponse alloc] initWithData: nil status:errCode] autorelease];
        //return [[[DELETEResponse alloc] initWithFilePath:[[self getBookUploadDir] stringByAppendingPathComponent:g_uploadFileName]] autorelease];
    }
    if (currentRequest == eUpload)
    {
        return [[[HTTPDataResponse alloc] initWithData: nil status:errCode] autorelease];
    }
    if (currentRequest == eGetProgress)
    {
        //get the uploaded files progress
        return [[[HTTPDataResponse alloc] initWithData: [self bookProgress] status:errCode] autorelease];
    }
    if (currentRequest == eGet)
    {
		//download the uploaded files
//        Column *newColumn = [gDataEngine getColumnFromLocal:g_bookId];
//        NSString *bookPath = [[gDataEngine getBookMgr] getBookUncompressedPath:g_bookId];
//        if (newColumn)
//        {
//            bookPath = [bookPath stringByAppendingPathComponent: newColumn.bookFileName];
//        }
//		return [[[HTTPFileResponse alloc] initWithFilePath: bookPath forConnection:self] autorelease];
	}
    if (currentRequest == eGetBookInfo)
    {
		//get the files info
//        GetBookInfoTask *task = [[GetBookInfoTask alloc] init];
//        [gDataEngine syncRunTask:task];
//        NSData* data = [NSData dataWithData:task.bookInfoData];
//        [task release];
//		return [[[HTTPDataResponse alloc] initWithData: data status:errCode] autorelease];
	}
    if (currentRequest == eDisconnect)
    {
        return [[[HTTPDataResponse alloc] initWithData:nil status:200] autorelease];
    }
	return [super httpResponseForMethod:method URI:path];
}

- (void)prepareForBodyWithSize:(UInt64)contentLength
{
    //NSLog(@"prepareForBodyWithSize: %d", errCode);
    if (errCode != 200)
        return;
	
	// set up mime parser
    NSString* boundary = [request headerField:@"boundary"];
    if (boundary)
    {
        _totalSize = contentLength;
        if (contentLength > 200)
        {
            _totalSize -= 200;
        }
        MultipartFormDataParser *multiparser = [[MultipartFormDataParser alloc] initWithBoundary:boundary formEncoding:NSUTF8StringEncoding];
        multiparser.delegate = self;
        self.parser = multiparser;
        [multiparser release];
    }
}

- (void)processBodyData:(NSData *)postDataChunk
{
    //NSLog(@"processBodyData: %d", errCode);
    if (errCode != 200)
        return;
    NSString *str = nil;
    if (postDataChunk.length < ([@"_method=delete" length] + 2))
    {
        str = [[NSString alloc] initWithData:postDataChunk  encoding:NSUTF8StringEncoding];
    }
    if (str && [str isEqualToString:@"_method=delete"])
    {
        [str release];
        return;
    }
    [str release];
    // append data to the parser. It will invoke callbacks to let us handle
    // parsed data.
    [_parser appendData:postDataChunk];
}

//-----------------------------------------------------------------
#pragma mark multipart form data parser delegate

- (void) processStartOfPartWithHeader:(MultipartMessageHeader*) header {
    //NSLog(@"processStartOfPartWithHeader: %d", errCode);
    if (errCode != 200)
        return;
	// in this sample, we are not interested in parts, other then file parts.
	// check content disposition to find out filename
    MultipartMessageHeaderField* disposition = [header.fields objectForKey:@"Content-Disposition"];
	NSString* filename = [disposition.params objectForKey:@"filename"];
    filename = [filename stringByReplacingOccurrencesOfString:@"\\" withString:@"/"];
    filename = [filename lastPathComponent];

    NSString *ext = [[filename pathExtension] lowercaseString];
    if (ext != nil && ([ext isEqualToString:@"pdf"] ||[ext isEqualToString:@"epub"] || [ext isEqualToString:@"doc"] || [ext isEqualToString:@"txt"] || [ext isEqualToString:@"docx"] || [ext isEqualToString:@"ppt"] || [ext isEqualToString:@"pptx"]))
    {

    }
    else
    {
        return;
    }
    //NSLog(@"processStartOfPartWithHeader: %@", filename);
    if ((nil == filename) || [filename isEqualToString: @""]) {
        // it's either not a file part, or
		// an empty form sent. we won't handle it.
		return;
	}

    NSString* uploadDir = [self getBookUploadDir];
    MakeDir(uploadDir);
    
    _index = -1;
    for (int i = 0; i < ARRAY_SIZE; i++)
    {
        if ([filename isEqualToString:g_uploadFileName[i]])
        {
            _index = i;
            break;
        }
    }
    if (_index == -1)
    {
        g_cur_index++;
        g_cur_index = g_cur_index % ARRAY_SIZE;
    }
    else
    {
        g_cur_index = _index;
    }
    g_recvedSize[g_cur_index] = 0;
    g_totalSize[g_cur_index] = _totalSize;
    if (g_uploadFileName[g_cur_index])
        [g_uploadFileName[g_cur_index] release];
    g_uploadFileName[g_cur_index] = [filename retain];
    g_uploadCancled = NO;
    
    //wifi上传书的task
//    [WifiImportBookTask notifyWifiUploadBookInfo:g_uploadFileName[g_cur_index] percent:0 entryId:nil result:0];
    NSString* filePath = [uploadDir stringByAppendingPathComponent: filename];

    NSFileManager *fileMgr = [[NSFileManager alloc] init];
    if ([fileMgr fileExistsAtPath:filePath]) {
        [fileMgr removeItemAtPath:filePath error:nil];
    }

    [fileMgr createFileAtPath:filePath contents:nil attributes:nil];
    self.storeFile = [NSFileHandle fileHandleForWritingAtPath:filePath];
    uploadOk = NO;
    [fileMgr release];
}

- (void) processContent:(NSData*) data WithHeader:(MultipartMessageHeader*) header 
{
    //NSLog(@"processContent: %d", errCode);
    if (errCode != 200)
        return;
    if (g_uploadCancled)
    {
        NSLog(@"processContent cancled");
        if (_storeFile)
        {
            [_storeFile closeFile];
            [_storeFile release];
            _storeFile = nil;
            uploadOk = NO;
            
            //wifi上传书的task
//            [WifiImportBookTask notifyWifiUploadBookInfo:g_uploadFileName[g_cur_index] percent:100 entryId:nil result:-1];
        }
        g_server_state = eIdle;
        g_uploadCancled = NO;
        return;
    }
	// here we just write the output from parser to the file.
	if (_storeFile) {
        g_recvedSize[g_cur_index] += [data length];
        [_storeFile writeData:data];
        //[NSThread sleepForTimeInterval:0.04];
        
        float progress = 0.0;
        if (g_totalSize[g_cur_index] > 0)
        {
            progress = (float)(g_recvedSize[g_cur_index] * 1.0 / g_totalSize[g_cur_index]);
        }
        int upProgress = (int)(progress * 100);
        if (upProgress > 99)
            upProgress = 99;
        
        //wifi上传书的task
//        [WifiImportBookTask notifyWifiUploadBookInfo:g_uploadFileName[g_cur_index] percent:upProgress entryId:nil result:0];
	}
}

- (void) processEndOfPartWithHeader:(MultipartMessageHeader*) header
{
    //NSLog(@"processEndOfPartWithHeader: %d", errCode);
    if (errCode != 200)
        return;
	// as the file part is over, we close the file.
    if (_storeFile)
    {
        [_storeFile closeFile];
        [_storeFile release];
        _storeFile = nil;
        uploadOk = YES;
        
        //wifi上传书的task
//        WifiImportBookTask *task = [[WifiImportBookTask alloc] initWithBookPath:[[self getBookUploadDir] stringByAppendingPathComponent:g_uploadFileName[g_cur_index]]];
//        [gDataEngine syncRunTask:task];
//        g_uploadResult[g_cur_index] = task.status;
//        [task release];
    }
 
    g_server_state = eIdle;
}

- (NSData *)preprocessResponse:(HTTPMessage *)response
{
	// Override me to customize the response headers
	// You'll likely want to add your own custom headers, and then return [super preprocessResponse:response]
	
	// Add standard headers
    if ((errCode == 200) && (_path != nil))
    {
        NSString * ext = [[_path pathExtension] lowercaseString];
        if ([ext isEqualToString:@"css"])
        {
            [response setHeaderField:@"Content-Type" value:@"text/css"];
        }
        else if ([ext isEqualToString:@"js"])
        {
            [response setHeaderField:@"Content-Type" value:@"application/x-javascript"];
        }
    }
   	
	return [super preprocessResponse:response];
}

- (void)finishResponse
{
    errCode = 200;
    if ((currentOpState == eGet) || (currentOpState == eDelete) || (currentOpState == eUpload))
    {
        NSLog(@"finishResponse: %d; %d", currentOpState, g_server_state);
        currentOpState = eIdle;
        g_server_state = eIdle;
        if (uploadOk == NO)
        {
            NSLog(@"file removed");
            NSFileManager *fileMgr = [[NSFileManager alloc] init];
            [fileMgr removeItemAtPath:[[self getBookUploadDir] stringByAppendingPathComponent:g_uploadFileName[g_cur_index]] error:nil];
            [fileMgr release];
        }
    }
    [super finishResponse];
}

- (NSData *)bookProgress
{
    NSString *result = @"200";
    float progress = 0.0;

    if (g_totalSize[_index] > 0)
    {
        progress = (float)(g_recvedSize[_index] * 1.0 / g_totalSize[_index]);
    }
    if ((progress > 0.99) || (g_totalSize[_index] < 10240))
    {
        progress = 1.0;
        result = [NSString stringWithFormat:@"%d", g_uploadResult[_index]];
    }

    NSString *progreeStr = [NSString stringWithFormat:@"%.3f", progress];
    NSString *sizeStr = nil;
    if (g_totalSize[_index] >= 1024 * 1024)
    {
        sizeStr = [NSString stringWithFormat:@"%.1f M", g_totalSize[_index] * 1.0 / 1024 / 1024];
    }
    else if (g_totalSize[_index] >= 1024)
    {
        sizeStr = [NSString stringWithFormat:@"%.1f K", g_totalSize[_index] * 1.0 / 1024];
    }
    else
    {
        sizeStr = [NSString stringWithFormat:@"%lld", g_totalSize[_index]];
    }
    NSDictionary *node = [NSDictionary dictionaryWithObjectsAndKeys: g_uploadFileName[_index], @"fileName", sizeStr, @"size", progreeStr, @"progress", result, @"result", nil];
    NSString *jsonString = [node JSONRepresentation];
    
    //NSLog(@"%@", jsonString);
    return [jsonString dataUsingEncoding:NSUTF8StringEncoding];
}

- (NSString *)getBookUploadDir
{
    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
    NSString *libraryDirectory = [paths objectAtIndex:0];
    NSString* uploadDirPath = [libraryDirectory stringByAppendingPathComponent:@"upload"];
    MakeDir(uploadDirPath);
    return uploadDirPath;
}

@end
