//
//  R3DExporter.m
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import "R3DExporter.h"
#import "../Utility/ZipWriter.h"
#import <simd/simd.h>

@implementation R3DExporter

+ (BOOL)exportRecords:(NSArray<FrameRecord *> *)records toPath:(NSString *)path {
    if (records.count == 0) {
        return NO;
    }

    ZipWriter *zip = [[ZipWriter alloc] initWithPath:path];
    if (!zip) {
        return NO;
    }

    // 元数据 JSON
    BOOL ok = [zip addFileWithName:@"metadata" data:[self buildMetadataJSON:records]];
    if (!ok) return NO;

    // 图标（第一帧 JPEG）
    FrameRecord *first = records.firstObject;
    if (first.jpegData) {
        [zip addFileWithName:@"icon" data:first.jpegData];
    }

    // 逐帧数据
    for (NSUInteger i = 0; i < records.count; i++) {
        FrameRecord *record = records[i];
        NSString *prefix = [NSString stringWithFormat:@"rgbd/%lu", (unsigned long)i];

        if (record.jpegData) {
            [zip addFileWithName:[prefix stringByAppendingPathExtension:@"jpg"]
                            data:record.jpegData];
        }
        if (record.depthData) {
            [zip addFileWithName:[prefix stringByAppendingPathExtension:@"depth"]
                            data:record.depthData];
        }
        if (record.confidenceData) {
            [zip addFileWithName:[prefix stringByAppendingPathExtension:@"conf"]
                            data:record.confidenceData];
        }
    }

    return [zip close];
}

#pragma mark - 元数据

+ (NSData *)buildMetadataJSON:(NSArray<FrameRecord *> *)records {
    FrameRecord *first = records.firstObject;
    FrameRecord *last = records.lastObject;

    // 计算帧率
    double duration = last.timestamp - first.timestamp;
    int fps = (duration > 0) ? (int)round(records.count / duration) : 60;

    // 相机内参 K 矩阵（行主序 3×3），取自第一帧
    simd_float3x3 K = first.intrinsics;
    float fx = K.columns[0].x;
    float fy = K.columns[1].y;
    float cx = K.columns[2].x;
    float cy = K.columns[2].y;
    NSArray *KArray = @[@(fx), @(0), @(cx), @(0), @(fy), @(cy), @(0), @(0), @(1)];

    // 深度图尺寸（从实际 Pixel Buffer 读取）
    size_t depthWidth = first.depthWidth;
    size_t depthHeight = first.depthHeight;

    // 构建数据数组
    NSMutableArray *frameTimestamps = [[NSMutableArray alloc] initWithCapacity:records.count];
    NSMutableArray *poses = [[NSMutableArray alloc] initWithCapacity:records.count];
    NSMutableArray *perFrameIntrinsics = [[NSMutableArray alloc] initWithCapacity:records.count];

    for (FrameRecord *record in records) {
        // 时间戳（相对第一帧，单位秒）
        double relativeTime = record.timestamp - first.timestamp;
        [frameTimestamps addObject:@(relativeTime)];

        // 位姿：[tx, ty, tz, qx, qy, qz, qw]
        simd_quatf q = record.quaternion;
        NSArray *pose = @[@(record.position.x), @(record.position.y), @(record.position.z),
                          @(q.vector.x), @(q.vector.y), @(q.vector.z), @(q.vector.w)];
        [poses addObject:pose];

        // 内参：[fx, fy, cx, cy]
        simd_float3x3 intr = record.intrinsics;
        NSArray *intrArray = @[@(intr.columns[0].x), @(intr.columns[1].y),
                                @(intr.columns[2].x), @(intr.columns[2].y)];
        [perFrameIntrinsics addObject:intrArray];
    }

    // initPose = 第一帧位姿
    simd_quatf firstQ = first.quaternion;
    NSArray *initPose = @[@(first.position.x), @(first.position.y), @(first.position.z),
                          @(firstQ.vector.x), @(firstQ.vector.y), @(firstQ.vector.z), @(firstQ.vector.w)];

    NSDictionary *metadata = @{
        @"fps": @(fps),
        @"dw": @(depthWidth),
        @"w": @(720),
        @"K": KArray,
        @"dh": @(depthHeight),
        @"initPose": initPose,
        @"frameTimestamps": frameTimestamps,
        @"poses": poses,
        @"perFrameIntrinsicCoeffs": perFrameIntrinsics,
        @"h": @(960),
        @"cameraType": @(1)
    };

    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:metadata
                                                       options:NSJSONWritingPrettyPrinted
                                                         error:&error];
    return jsonData;
}

@end
