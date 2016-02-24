//
//  NetWorkSpeedMonitor.m
//  NetworkSpeedMonitor
//
//  Created by 范东 on 15/8/24.
//  Copyright (c) 2015年 ifandong.com. All rights reserved.
//

#import "NetWorkSpeedMonitor.h"
#import "Reachability.h"
#include <stdio.h>
#include <ifaddrs.h>
#include <sys/socket.h>
#include <net/if.h>

@interface FDNetWorkSpeedMonitor ()

@property (assign,nonatomic) long long int bytesPerSecond;
@property (assign,nonatomic) FDNetWorkBytes networkBytesPerSecond;
//@property (strong,nonatomic) NSString *speedStr;

@property (strong,nonatomic) NSTimer *timer;
@property (strong,nonatomic) dispatch_source_t timerGCD;
@property (assign,nonatomic) NSTimeInterval gapOfTimer;

@property (assign,nonatomic) BOOL monitoring;

@end

@implementation FDNetWorkSpeedMonitor

+(FDNetWorkSpeedMonitor *)sharedMonitor {
    static FDNetWorkSpeedMonitor *sharedMonitor = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        sharedMonitor = [[FDNetWorkSpeedMonitor alloc] init];
    });
    return sharedMonitor;
}

- (instancetype)init {
    if (self = [super init]) {
        self.gapOfTimer = 1.0;
    }
    return self;
}

#pragma mark - Custom Accessors

- (void)setTimer:(NSTimer *)timer {
    if (_timer!=timer) {
        [_timer invalidate];
        _timer = nil;
    }
    _timer = timer;
}

- (void)setTimerGCD:(dispatch_source_t)timerGCD {
    if (_timerGCD && _timerGCD!=timerGCD) {
        dispatch_cancel(self.timerGCD);
        _timerGCD = nil;
    }
    _timerGCD = timerGCD;
}

- (NSString *)speedStr {
    NSString  *speedStr = [self bytesToSpeedStr:self.bytesPerSecond];
    return speedStr;
}

- (NSString *)downloadStr {
    NSString  *speedStr = [self bytesToSpeedStr:self.networkBytesPerSecond.inBytes];
    return speedStr;
}

- (NSString *)uploadStr {
    NSString  *speedStr = [self bytesToSpeedStr:self.networkBytesPerSecond.outBytes];
    return speedStr;
}

#pragma mark - Pubic

- (void)startMonitor {
    if (!self.isMonitoring) {
        __weak typeof(self) weakSelf = self;
        
        NSTimeInterval period = 1.0; //设置时间间隔
        dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0);
        dispatch_source_t timer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
        dispatch_source_set_timer(timer, dispatch_walltime(NULL, 0), period * NSEC_PER_SEC, 0); //每秒执行
        dispatch_source_set_event_handler(timer, ^{
            //在这里执行事件
            [weakSelf monitorNetWorkSpeed];
        });
        dispatch_resume(timer);
        self.timerGCD = timer;
        self.monitoring = YES;
    }
}

- (void)stopMonitor {
    self.timerGCD = nil;
    self.monitoring = NO;
}

#pragma mark - Private

- (void)monitorNetWorkSpeed {
    FDNetWorkBytes bytes = [self getBytes];
    [self performSelector:@selector(reSetBtyesPersceond:)
                 onThread:[NSThread mainThread]
               withObject:@{@"inBytes":@(bytes.inBytes),@"outBytes":@(bytes.outBytes)}
            waitUntilDone:YES];
}

//获取每秒字节数
-(FDNetWorkBytes)getBytes
{
    static NSTimeInterval lastTime = 0;
    static FDNetWorkBytes lastNetworkBytes = {0,0};
    static NetworkStatus lastStatus = NotReachable;
    
    FDNetWorkBytes currentNetworkBytes = {0,0};
    
    Reachability *CurReach = [Reachability reachabilityForInternetConnection];
    NetworkStatus currentStauts = [CurReach currentReachabilityStatus];
    switch (currentStauts) {
        case NotReachable://没有网络
        {
            NSLog(@"noActiveNet");
            break;
        }
        case ReachableViaWiFi://有wifi
        {
            currentNetworkBytes = [self getWifiBytes];
            break;
        }
        case ReachableViaWWAN://有3G
        {
            currentNetworkBytes = [self getGprsBytes];
            break;
        }
        default:
            break;
    }
    
    NSTimeInterval currentTime = [[NSDate date] timeIntervalSince1970];
    NSTimeInterval duration = currentTime - lastTime;
    
    FDNetWorkBytes bytes = {0,0};
    if (lastTime==0||duration==0||lastStatus!=currentStauts) {
        
    } else {
        bytes.outBytes = (currentNetworkBytes.outBytes - lastNetworkBytes.outBytes)/duration;
        bytes.inBytes = (currentNetworkBytes.inBytes - lastNetworkBytes.inBytes)/duration;
    }
    lastTime = currentTime;
    lastNetworkBytes = currentNetworkBytes;
    lastStatus = currentStauts;
    return bytes;
}

- (void)reSetBtyesPersceond:(NSDictionary *)bytesDic {
    FDNetWorkBytes bytes;
    bytes.inBytes = [[bytesDic objectForKey:@"inBytes"] longLongValue];
    bytes.outBytes = [[bytesDic objectForKey:@"outBytes"] longLongValue];
    self.networkBytesPerSecond = bytes;
    self.bytesPerSecond = _networkBytesPerSecond.inBytes + _networkBytesPerSecond.outBytes;
}

- (NSString *)bytesToSpeedStr:(long long int)bytes
{
    if(bytes < 1024)     // B
    {
        return [NSString stringWithFormat:@"%lldB/s", bytes];
    }
    else if(bytes >= 1024 && bytes < 1024 * 1024) // KB
    {
        return [NSString stringWithFormat:@"%.1fKB/s", (double)bytes / 1024];
    }
    else if(bytes >= 1024 * 1024 && bytes < 1024 * 1024 * 1024)   // MB
    {
        return [NSString stringWithFormat:@"%.2fMB", (double)bytes / (1024 * 1024)];
    }
    else    // GB
    {
        return [NSString stringWithFormat:@"%.3fGB", (double)bytes / (1024 * 1024 * 1024)];
    }
}

/**
 *  获取当前的Wifi流量
 *
 *  @return 流量字节数
 */
- (FDNetWorkBytes)getWifiBytes
{
    FDNetWorkBytes bytes = {0,0};
    
    struct ifaddrs *ifa_list = 0, *ifa;
    if (getifaddrs(&ifa_list) == -1) {
        return bytes;
    }
    uint32_t iBytes = 0;
    uint32_t oBytes = 0;
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        if (AF_LINK != ifa->ifa_addr->sa_family)
            continue;
        if (!(ifa->ifa_flags & IFF_UP) && !(ifa->ifa_flags & IFF_RUNNING))
            continue;
        if (ifa->ifa_data == 0)
            continue;
        if (strncmp(ifa->ifa_name, "lo", 2)) {
            //lo表示是本地网卡即127.0.0.1
            //en0是Wifi网卡
            //pdp_ip0是2G/3G接入网卡
            struct if_data *if_data = (struct if_data *)ifa->ifa_data;
            iBytes += if_data->ifi_ibytes;
            oBytes += if_data->ifi_obytes;
            //NSLog(@"%s :iBytes is %d, oBytes is %d", ifa->ifa_name, iBytes, oBytes);
        }
    }
    freeifaddrs(ifa_list);
    bytes.inBytes = iBytes;
    bytes.outBytes = oBytes;
    return bytes;
}

/**
 *  获取当前的GPRS流量
 *
 *  @return 流量字节数
 */
- (FDNetWorkBytes) getGprsBytes
{
    FDNetWorkBytes bytes = {0,0};
    
    struct ifaddrs *ifa_list= 0, *ifa;
    if (getifaddrs(&ifa_list)== -1) {
        return bytes;
    }
    uint32_t iBytes = 0;
    uint32_t oBytes = 0;
    for (ifa = ifa_list; ifa; ifa = ifa->ifa_next) {
        if (AF_LINK != ifa->ifa_addr->sa_family)
            continue;
        if (!(ifa->ifa_flags& IFF_UP) &&!(ifa->ifa_flags & IFF_RUNNING))
            continue;
        if (ifa->ifa_data == 0)
            continue;
        if (!strcmp(ifa->ifa_name,"pdp_ip0")) {
             //pdp_ip0是2G/3G接入网卡
            struct if_data *if_data = (struct if_data*)ifa->ifa_data;
            iBytes += if_data->ifi_ibytes;
            oBytes += if_data->ifi_obytes;
            //NSLog(@"%s :iBytes is %d, oBytes is %d",ifa->ifa_name, iBytes, oBytes);
        }
    }
    freeifaddrs(ifa_list);
    bytes.inBytes = iBytes;
    bytes.outBytes = oBytes;
    return bytes;
}



@end
