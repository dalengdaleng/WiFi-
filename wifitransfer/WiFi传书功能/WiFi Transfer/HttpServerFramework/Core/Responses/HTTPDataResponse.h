#import <Foundation/Foundation.h>
#import "HTTPResponse.h"


@interface HTTPDataResponse : NSObject <HTTPResponse>
{
	NSUInteger offset;
	NSData *data;
    NSInteger _status;
}

- (id)initWithData:(NSData *)dataParam status:(NSInteger)status;

@end
