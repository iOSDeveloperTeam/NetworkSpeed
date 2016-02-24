//
//  ViewController.m
//  NetworkSpeed
//
//  Created by 范东 on 15/9/25.
//  Copyright © 2015年 ifandong. All rights reserved.
//

#import "ViewController.h"
#import "NetWorkSpeedMonitor.h"

@interface ViewController ()
@property (weak, nonatomic) IBOutlet UILabel *speedLabel;

@property (nonatomic, strong) FDNetWorkSpeedMonitor *speedMonitor;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    self.speedMonitor = [FDNetWorkSpeedMonitor sharedMonitor];
    [self.speedMonitor startMonitor];
}

- (void)dealloc
{
    [self.speedMonitor stopMonitor];
    self.speedMonitor = nil;
}

- (void)setSpeedMonitor:(FDNetWorkSpeedMonitor *)speedMonitor
{
    _speedMonitor = speedMonitor;
    if (_speedMonitor) {
        [_speedMonitor addObserver:self forKeyPath:@"bytesPerSecond" options:NSKeyValueObservingOptionNew context:nil];
        [_speedMonitor addObserver:self forKeyPath:@"monitoring" options:NSKeyValueObservingOptionNew context:nil];
    }
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSString *,id> *)change context:(void *)context
{
    if ([keyPath isEqualToString:@"bytesPerSecond"]) {
        NSLog(@"%@",[NSString stringWithFormat:@"\n 下载：%15s \n 上传：%15s \n 总计：%15s",[self.speedMonitor.downloadStr UTF8String],[self.speedMonitor.uploadStr UTF8String],[self.speedMonitor.speedStr UTF8String]]);
        self.speedLabel.text = [NSString stringWithFormat:@"%15s",[self.speedMonitor.downloadStr UTF8String]];
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
