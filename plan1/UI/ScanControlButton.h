//
//  ScanControlButton.h
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ScanButtonState) {
    ScanButtonStateStart,   // 奶绿色 — 准备开始扫描
    ScanButtonStateEnd      // 奶红色 — 结束扫描
};

/// 悬浮在 AR 视图之上的圆形两态控制按钮
@interface ScanControlButton : UIButton

@property (nonatomic, readonly) ScanButtonState scanState;

@property (nonatomic, copy) void (^onTap)(ScanButtonState currentState);

- (void)setScanState:(ScanButtonState)scanState animated:(BOOL)animated;
- (void)setScanState:(ScanButtonState)scanState;

@end

NS_ASSUME_NONNULL_END
