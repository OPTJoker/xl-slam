//
//  R3DExporter.h
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import <Foundation/Foundation.h>
#import "FrameRecord.h"

@interface R3DExporter : NSObject

+ (BOOL)exportRecords:(NSArray<FrameRecord *> *)records toPath:(NSString *)path;

@end
