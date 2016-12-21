//
//  WebServerMgr.m
//  PRIS
//
//  Created by zhangcj on 13-01-09
//  Copyright 2013 NetEase Co.Ltd. All rights reserved.
//
#import "WebServerMgr.h"
#import <HttpServerFramework/HTTPServer.h>
#import <HttpServerFramework/DDLog.h>
#import <HttpServerFramework/DDTTYLogger.h>
#import "BookMgrHTTPConnection.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/ioctl.h>
#include <sys/types.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <arpa/inet.h>
#include <sys/sockio.h>
#include <net/if.h>
#include <errno.h>
#include <net/if_dl.h>

#import <ifaddrs.h>
#import <arpa/inet.h>
#import <SystemConfiguration/SCNetworkReachability.h>

#define min(a, b) ((a) < (b) ? (a) : (b))
#define max(a, b) ((a) > (b) ? (a) : (b))

#define BUFFERSIZE 1024
#define MAXADDRS   16

static char *if_names[MAXADDRS];
static char *ip_names[MAXADDRS];
static unsigned long ip_addrs[MAXADDRS];

static void InitAddresses(void)
{
    int i;
    for (i = 0; i < MAXADDRS; ++i)
    {
        if_names[i] = ip_names[i] = NULL;
        ip_addrs[i] = 0;
    }
}

static void FreeAddresses(void)
{
    int i;
    for (i = 0; i < MAXADDRS; ++i)
    {
        if (if_names[i] != 0) free(if_names[i]);
        if (ip_names[i] != 0) free(ip_names[i]);
        ip_addrs[i] = 0;
    }
    InitAddresses();
}

static void GetIPAddresses(void)
{
    int i, len, flags;
    char buffer[BUFFERSIZE], *ptr, lastname[IFNAMSIZ], *cptr;
    struct ifconf ifc;
    struct ifreq *ifr, ifrcopy;
    struct sockaddr_in *sin;
    
    char temp[80];
    int sockfd; 
    int nextAddr = 0;
    
    for (i = 0; i < MAXADDRS; ++i)
    {
        if_names[i] = ip_names[i] = NULL;
        ip_addrs[i] = 0;
    }
    
    sockfd = socket(AF_INET, SOCK_DGRAM, 0);
    if (sockfd < 0)
    {
        perror("socket failed");
        return;
    }
    
    ifc.ifc_len = BUFFERSIZE;
    ifc.ifc_buf = buffer;
    
    if (ioctl(sockfd, SIOCGIFCONF, &ifc) < 0)
    {
        perror("ioctl error");
        return;
    }
    
    lastname[0] = 0;
    
    for (ptr = buffer; ptr < buffer + ifc.ifc_len; )
    {
        ifr = (struct ifreq *)ptr;
        len = max(sizeof(struct sockaddr), ifr->ifr_addr.sa_len);
        ptr += sizeof(ifr->ifr_name) + len; // for next one in buffer
        
        if (ifr->ifr_addr.sa_family != AF_INET)
        {
            continue; // ignore if not desired address family
        }
        
        if ((cptr = (char *)strchr(ifr->ifr_name, ':')) != NULL)
        {
            *cptr = 0; // replace colon will null
        }
        
        if (strncmp(lastname, ifr->ifr_name, IFNAMSIZ) == 0)
        {
            continue; /* already processed this interface */
        }
        
        memcpy(lastname, ifr->ifr_name, IFNAMSIZ);
        
        ifrcopy = *ifr;
        ioctl(sockfd, SIOCGIFFLAGS, &ifrcopy);
        flags = ifrcopy.ifr_flags;
        if ((flags & IFF_UP) == 0)
        {
            continue; // ignore if interface not up
        }
        
        if_names[nextAddr] = (char *)malloc(strlen(ifr->ifr_name)+1);
        if (if_names[nextAddr] == NULL)
        {
            return;
        }
        strcpy(if_names[nextAddr], ifr->ifr_name);
        
        sin = (struct sockaddr_in *)&ifr->ifr_addr;
        strcpy(temp, inet_ntoa(sin->sin_addr));
        
        ip_names[nextAddr] = (char *)malloc(strlen(temp) + 1);
        if (ip_names[nextAddr] == NULL)
        {
            return;
        }
        strcpy(ip_names[nextAddr], temp);
        
        ip_addrs[nextAddr] = sin->sin_addr.s_addr;
        
        ++nextAddr;
    }
    
    close(sockfd);
}

#define WEB_SERVER_PORT         (12306)

static HTTPServer *httpServer = nil;
static const int ddLogLevel = LOG_LEVEL_VERBOSE;

@implementation WebServerMgr

+ (void) webServerStop
{
    if (httpServer)
    {
        [DDLog removeAllLoggers];
        [httpServer stop];
        [httpServer release];
        httpServer = nil;
    }
}

+ (BOOL) webServerStart
{
    BOOL success = YES;
    
    [WebServerMgr webServerStop];
    resetWebServerState();
    // Configure our logging framework.
	// To keep things simple and fast, we're just going to log to the Xcode console.
	[DDLog addLogger:[DDTTYLogger sharedInstance]];
	
	// Create server using our custom MyHTTPServer class
	httpServer = [[HTTPServer alloc] init];
	
	// Tell the server to broadcast its presence via Bonjour.
	// This allows browsers such as Safari to automatically discover our service.
	[httpServer setType:@"_http._tcp."];
	
	// Normally there's no need to run our server on any specific port.
	// Technologies like Bonjour allow clients to dynamically discover the server's port at runtime.
	// However, for easy testing you may want force a certain port so you can just hit the refresh button.
	[httpServer setPort:WEB_SERVER_PORT];
    [httpServer setConnectionClass:[BookMgrHTTPConnection class]];
	
	// Serve files from our embedded Web folder
	NSString *webPath = [[[NSBundle mainBundle] resourcePath] stringByAppendingPathComponent:@"wifi_fileupload"];
    //NSString *webPath = [[NSBundle mainBundle] resourcePath];
	DDLogInfo(@"Setting document root: %@", webPath);
	
	[httpServer setDocumentRoot:webPath];
	
	// Start the server (and check for problems)
	
	NSError *error;
    success = [httpServer start:&error];
	if (success)
	{
		NSLog(@"Started HTTP Server on port %hu", [httpServer listeningPort]);
	}
	else
	{
		NSLog(@"Error starting HTTP Server: %@", error);
	}
    return success;
}

+ (NSString*) getWebServerAddr
{
    NSString *ipvaddress = [self getIPvAddress:NO];//获得ipv6地址，手机和模拟器获得不一样，需要区分
    NSString *returnAddress = [NSString stringWithFormat:@"[%@]",ipvaddress];
    NSString *webServerAddr = [NSString stringWithFormat:@"http://%@:%d", returnAddress, WEB_SERVER_PORT];
    
#if TARGET_IPHONE_SIMULATOR
    ipvaddress = [self getIPvAddress:YES];//获得ipv4地址
    
    returnAddress = [NSString stringWithFormat:@"%@",ipvaddress];
    webServerAddr = [NSString stringWithFormat:@"http://%@:%d", returnAddress, WEB_SERVER_PORT];
    
    return webServerAddr;
#else
    //webServerAddr如何判断是否能连接？
    BOOL isConnectIpv6 = [self connectedToNetwork:NO];
    if(isConnectIpv6)
    {
        return webServerAddr;
    }
    else
    {
        ipvaddress = [self getIPvAddress:YES];//获得ipv4地址
        
        returnAddress = [NSString stringWithFormat:@"%@",ipvaddress];
        webServerAddr = [NSString stringWithFormat:@"http://%@:%d", returnAddress, WEB_SERVER_PORT];
        
        return webServerAddr;
    }
#endif
    
/*    int i = 0;
    InitAddresses();
    GetIPAddresses();
    
    for (i = 0; i < MAXADDRS; i++)
    {
        if (if_names[i] != 0)
        {
            NSString *ifName = [NSString stringWithFormat:@"%s", if_names[i]];
            if ([[ifName lowercaseString] hasPrefix:@"en"])
            {
                break;
            }
        }
    }
    if (MAXADDRS == i){
        FreeAddresses();
        return @"";
    }
    NSString *ip = [NSString stringWithFormat:@"%s", ip_names[i]];
    FreeAddresses();
    
    return [NSString stringWithFormat:@"http://%@:%d", ip, WEB_SERVER_PORT];
 */
}

#define IOS_CELLULAR    @"pdp_ip0"
#define IOS_WIFI        @"en0"
#define IOS_VPN         @"utun0"
#define IP_ADDR_IPv4    @"ipv4"
#define IP_ADDR_IPv6    @"ipv6"


+ (NSString *)getIPvAddress:(BOOL)aPreferIPv4
{
    NSArray *searchArray = aPreferIPv4 ?
    @[ IOS_VPN @"/" IP_ADDR_IPv4, IOS_VPN @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6 ] :
    @[ IOS_VPN @"/" IP_ADDR_IPv6, IOS_VPN @"/" IP_ADDR_IPv4, IOS_WIFI @"/" IP_ADDR_IPv6, IOS_WIFI @"/" IP_ADDR_IPv4, IOS_CELLULAR @"/" IP_ADDR_IPv6, IOS_CELLULAR @"/" IP_ADDR_IPv4 ] ;
    
    NSDictionary *addresses = [self getIPAddresses];
    NSLog(@"addresses: %@", addresses);
    
    __block NSString *address;
    [searchArray enumerateObjectsUsingBlock:^(NSString *key, NSUInteger idx, BOOL *stop)
     {
         address = addresses[key];
         if(address) *stop = YES;
     } ];
    return address ? address : @"0.0.0.0";
}

+ (NSDictionary *)getIPAddresses
{
    NSMutableDictionary *addresses = [NSMutableDictionary dictionaryWithCapacity:8];
    
    // retrieve the current interfaces - returns 0 on success
    struct ifaddrs *interfaces;
    if(!getifaddrs(&interfaces)) {
        // Loop through linked list of interfaces
        struct ifaddrs *interface;
        for(interface=interfaces; interface; interface=interface->ifa_next) {
            if(!(interface->ifa_flags & IFF_UP) /* || (interface->ifa_flags & IFF_LOOPBACK) */ ) {
                continue; // deeply nested code harder to read
            }
            const struct sockaddr_in *addr = (const struct sockaddr_in*)interface->ifa_addr;
            char addrBuf[ MAX(INET_ADDRSTRLEN, INET6_ADDRSTRLEN) ];
            if(addr && (addr->sin_family==AF_INET || addr->sin_family==AF_INET6)) {
                NSString *name = [NSString stringWithUTF8String:interface->ifa_name];
                NSString *type;
                if(addr->sin_family == AF_INET) {
                    if(inet_ntop(AF_INET, &addr->sin_addr, addrBuf, INET_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv4;
                    }
                } else {
                    const struct sockaddr_in6 *addr6 = (const struct sockaddr_in6*)interface->ifa_addr;
                    if(inet_ntop(AF_INET6, &addr6->sin6_addr, addrBuf, INET6_ADDRSTRLEN)) {
                        type = IP_ADDR_IPv6;
                    }
                }
                if(type) {
                    NSString *key = [NSString stringWithFormat:@"%@/%@", name, type];
                    addresses[key] = [NSString stringWithUTF8String:addrBuf];
                }
            }
        }
        // Free memory
        freeifaddrs(interfaces);
    }
    return [addresses count] ? addresses : nil;
}

//连接网络：aIsIpv4 yes,判断是否是ipv4网络，否则判断ipv6网络，网上找的方法，暂时使用时可以的，不知道还有没有其它方法？？？？
+ (BOOL) connectedToNetwork:(BOOL)aIsIpv4
{
    if(aIsIpv4)
    {
        //创建零地址，0.0.0.0的地址表示查询本机的网络连接状态
        struct sockaddr_in zeroAddress;
        bzero(&zeroAddress, sizeof(zeroAddress));
        zeroAddress.sin_len = sizeof(zeroAddress);
        zeroAddress.sin_family = AF_INET;
        // Recover reachability flags
        SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
        SCNetworkReachabilityFlags flags;
        //获得连接的标志
        BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
        CFRelease(defaultRouteReachability);
        //如果不能获取连接标志，则不能连接网络，直接返回
        if (!didRetrieveFlags)
        {
            return NO;
        }
        //根据获得的连接标志进行判断
        BOOL isReachable = flags & kSCNetworkFlagsReachable;
        BOOL needsConnection = flags & kSCNetworkFlagsConnectionRequired;
        return (isReachable && !needsConnection) ? YES : NO;
    }
    else
    {
        //创建零地址，0.0.0.0的地址表示查询本机的网络连接状态
        struct sockaddr_in6 zeroAddress;
        bzero(&zeroAddress, sizeof(zeroAddress));
        zeroAddress.sin6_len = sizeof(zeroAddress);
        zeroAddress.sin6_family = AF_INET6;
        // Recover reachability flags
        SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
        SCNetworkReachabilityFlags flags;
        //获得连接的标志
        BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
        CFRelease(defaultRouteReachability);
        //如果不能获取连接标志，则不能连接网络，直接返回
        if (!didRetrieveFlags)
        {
            return NO;
        }
        //根据获得的连接标志进行判断
        BOOL isReachable = flags & kSCNetworkFlagsReachable;
        BOOL needsConnection = flags & kSCNetworkFlagsConnectionRequired;
        return (isReachable && !needsConnection) ? YES : NO;
    }
}
@end
