//
//  ScanDataManager.h
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import <ARKit/ARKit.h>
#import "FrameRecord.h"

@interface ScanDataManager : NSObject

- (void)startRecording;
- (void)recordFrame:(ARFrame *)frame;
- (NSArray<FrameRecord *> *)stopRecording;

@property (nonatomic, readonly) BOOL isRecording;
@property (nonatomic, readonly) NSUInteger frameCount;

@end
