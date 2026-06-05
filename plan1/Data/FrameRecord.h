//
//  FrameRecord.h
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import <simd/simd.h>
#import <Foundation/Foundation.h>

@interface FrameRecord : NSObject

@property (nonatomic) NSTimeInterval timestamp;
@property (nonatomic) simd_float3 position;
@property (nonatomic) simd_quatf quaternion;
@property (nonatomic) simd_float3x3 intrinsics;

@property (nonatomic, strong) NSData *jpegData;
@property (nonatomic, strong) NSData *depthData;
@property (nonatomic, strong) NSData *confidenceData;

@end
