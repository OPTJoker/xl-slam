//
//  AppDelegate.m
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import "AppDelegate.h"

@interface AppDelegate ()

@end

@implementation AppDelegate


- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    // 应用启动后的自定义设置入口
    return YES;
}


#pragma mark - UISceneSession lifecycle


- (UISceneConfiguration *)application:(UIApplication *)application configurationForConnectingSceneSession:(UISceneSession *)connectingSceneSession options:(UISceneConnectionOptions *)options {
    // 当新的场景会话被创建时调用
    // 在此方法中选择配置以创建新场景
    return [[UISceneConfiguration alloc] initWithName:@"Default Configuration" sessionRole:connectingSceneSession.role];
}


- (void)application:(UIApplication *)application didDiscardSceneSessions:(NSSet<UISceneSession *> *)sceneSessions {
    // 当用户弃用某个场景会话时调用
    // 若应用未运行时场景被丢弃，将在 didFinishLaunching 后不久调用
    // 在此方法中释放被丢弃场景占用的资源
}


@end
