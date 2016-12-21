
#import <HttpServerFramework/HTTPConnection.h>

typedef enum
{
    eIdle = 0,
    eGetBookInfo = 1,
    eDelete = 2,
    eUpload = 3,
    eGet = 4,
    eGetProgress = 5,
    eDisconnect = 6,
    eOther = 7,
}eOpState;

void resetWebServerState(void);

@class MultipartFormDataParser;

@interface BookMgrHTTPConnection : HTTPConnection  {
    MultipartFormDataParser*        _parser;
	NSFileHandle*					_storeFile;

    eOpState                        currentOpState;
    eOpState                        currentRequest;
    int                             errCode;
    BOOL                            uploadOk;
    NSString*                       _path;
    int                             _index;
    UInt64                          _totalSize;
}

@property(nonatomic, retain) MultipartFormDataParser* parser;
@property(nonatomic, retain) NSFileHandle* storeFile;
@property(nonatomic, retain) NSString* path;

@end

