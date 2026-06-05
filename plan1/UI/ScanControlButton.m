//
//  ScanControlButton.m
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import "ScanControlButton.h"

// 柔和配色
static UIColor *MilkGreenColor(void) {
    return [UIColor colorWithRed:0.529 green:0.910 blue:0.584 alpha:1.0]; // #BAE8C8
}

static UIColor *MilkRedColor(void) {
    return [UIColor colorWithRed:0.941 green:0.406 blue:0.406 alpha:1.0]; // #F0B4B4
}

static CGFloat const kButtonSize = 80.0;
static CGFloat const kShadowRadius = 6.0;
static CGFloat const kShadowOpacity = 0.25;

@interface ScanControlButton ()

@property (nonatomic) ScanButtonState scanState;

@end

@implementation ScanControlButton

#pragma mark - 初始化

- (instancetype)init {
    self = [super initWithFrame:CGRectMake(0, 0, kButtonSize, kButtonSize)];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)commonInit {
    self.layer.cornerRadius = kButtonSize / 2;
    self.clipsToBounds = NO;
    self.titleLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightBold];
    [self setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];

    // 阴影
    self.layer.shadowColor = [UIColor blackColor].CGColor;
    self.layer.shadowOffset = CGSizeMake(0, 4);
    self.layer.shadowRadius = kShadowRadius;
    self.layer.shadowOpacity = kShadowOpacity;

    [self addTarget:self action:@selector(didTapSelf) forControlEvents:UIControlEventTouchUpInside];

    self.scanState = ScanButtonStateStart;
    [self applyState:ScanButtonStateStart];
}

#pragma mark - 公开方法

- (void)setScanState:(ScanButtonState)scanState animated:(BOOL)animated {
    self->_scanState = scanState;
    if (animated) {
        [UIView animateWithDuration:0.3
                              delay:0
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            [self applyState:scanState];
        } completion:nil];
    } else {
        [self applyState:scanState];
    }
}

- (void)setScanState:(ScanButtonState)scanState {
    [self setScanState:scanState animated:NO];
}

#pragma mark - 事件处理

- (void)didTapSelf {
    if (self.onTap) {
        self.onTap(self.scanState);
    }
}

#pragma mark - 私有方法

- (void)applyState:(ScanButtonState)state {
    switch (state) {
        case ScanButtonStateStart:
            self.backgroundColor = MilkGreenColor();
            [self setTitle:@"开始" forState:UIControlStateNormal];
            break;
        case ScanButtonStateEnd:
            self.backgroundColor = MilkRedColor();
            [self setTitle:@"结束" forState:UIControlStateNormal];
            break;
    }
}

@end
