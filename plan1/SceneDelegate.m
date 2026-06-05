//
//  SceneDelegate.m
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import "SceneDelegate.h"

@interface SceneDelegate ()

@end

@implementation SceneDelegate


- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions {
    // 在此可选地配置 UIWindow 并将其附加到 UIWindowScene
    // 如果使用 Storyboard，window 属性会自动初始化并附加到场景
    // 此委托方法不表示连接中的场景或会话是新创建的
}


- (void)sceneDidDisconnect:(UIScene *)scene {
    // 场景被系统释放时调用
    // 在场景进入后台或会话被丢弃后不久触发
    // 释放与此场景相关的资源，这些资源可在场景重新连接时重建
    // 场景后续可能重新连接，因为其会话不一定被丢弃
}


- (void)sceneDidBecomeActive:(UIScene *)scene {
    // 场景从非活跃状态切换到活跃状态时调用
    // 在此重启场景非活跃时暂停（或未启动）的任务
}


- (void)sceneWillResignActive:(UIScene *)scene {
    // 场景即将从活跃状态切换到非活跃状态时调用
    // 可能由于临时中断导致（如来电）
}


- (void)sceneWillEnterForeground:(UIScene *)scene {
    // 场景从后台切换到前台时调用
    // 在此撤销进入后台时所做的更改
}


- (void)sceneDidEnterBackground:(UIScene *)scene {
    // 场景从前台切换到后台时调用
    // 在此保存数据、释放共享资源，并存储足够的状态信息
    // 以便将来将场景恢复到当前状态
}


@end
