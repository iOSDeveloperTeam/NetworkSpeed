//
//  NetWorkSpeedMonitor.h
//  NetworkSpeedMonitor
//
//  Created by 范东 on 15/8/24.
//  Copyright (c) 2015年 ifandong.com. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct FDNetWorkBytes {
    long long int inBytes;
    long long int outBytes;
}FDNetWorkBytes;

@interface FDNetWorkSpeedMonitor : NSObject

+(FDNetWorkSpeedMonitor *)sharedMonitor;

@property (assign,nonatomic,readonly,getter=isMonitoring) BOOL monitoring;
@property (assign,nonatomic,readonly) long long int bytesPerSecond;
@property (assign,nonatomic,readonly) FDNetWorkBytes networkBytesPerSecond;

@property (strong,nonatomic,readonly) NSString *speedStr;
@property (strong,nonatomic,readonly) NSString *downloadStr;
@property (strong,nonatomic,readonly) NSString *uploadStr;

- (void)startMonitor;
- (void)stopMonitor;
@end
