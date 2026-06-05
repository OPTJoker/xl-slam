//
//  ScanDataManager.m
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import "ScanDataManager.h"
#import <CoreImage/CoreImage.h>
#import <CoreVideo/CoreVideo.h>
#import <compression.h>

#ifndef kCVPixelFormatType_DepthFloat32
#define kCVPixelFormatType_DepthFloat32 'f32d'
#endif
#ifndef kCVPixelFormatType_ConfidenceMap
#define kCVPixelFormatType_ConfidenceMap 'cmon'
#endif

static CGSize const kTargetColorSize = {720, 960};
static CGFloat const kJPEGQuality = 0.85;

@interface ScanDataManager ()

@property (nonatomic, strong) NSMutableArray<FrameRecord *> *records;
@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, strong) dispatch_queue_t processingQueue;

@end

@implementation ScanDataManager

#pragma mark - 初始化

- (instancetype)init {
    self = [super init];
    if (self) {
        _records = [[NSMutableArray alloc] init];
        _ciContext = [[CIContext alloc] init];
        _processingQueue = dispatch_queue_create("com.plan1.scanprocessing", DISPATCH_QUEUE_SERIAL);
    }
    return self;
}

#pragma mark - 公开方法

- (void)startRecording {
    // 等待后台队列中所有进行中的压缩任务完成后再清空
    dispatch_sync(self.processingQueue, ^{});
    @synchronized (self) {
        [self.records removeAllObjects];
    }
}

- (void)recordFrame:(ARFrame *)frame {
    if (!frame) {
        return;
    }

    ARDepthData *depthData = frame.smoothedSceneDepth;
    if (!depthData || !depthData.depthMap) {
        return;
    }

    // 保留 pixel buffer 引用，供异步队列使用
    CVPixelBufferRef colorBuffer = frame.capturedImage;
    CVPixelBufferRef depthBuffer = depthData.depthMap;
    CVPixelBufferRef confidenceBuffer = depthData.confidenceMap;
    CVPixelBufferRetain(colorBuffer);
    CVPixelBufferRetain(depthBuffer);
    if (confidenceBuffer) {
        CVPixelBufferRetain(confidenceBuffer);
    }

    // 在主线程同步拷贝元数据（开销极小）
    simd_float4x4 transform = frame.camera.transform;
    simd_float3 position = simd_make_float3(transform.columns[3].x,
                                            transform.columns[3].y,
                                            transform.columns[3].z);
    simd_float3x3 rotation = {
        transform.columns[0].xyz,
        transform.columns[1].xyz,
        transform.columns[2].xyz
    };
    simd_quatf quaternion = simd_quaternion(rotation);
    simd_float3x3 intrinsics = frame.camera.intrinsics;
    NSTimeInterval timestamp = frame.timestamp;

    dispatch_async(self.processingQueue, ^{
        FrameRecord *record = [[FrameRecord alloc] init];
        record.timestamp = timestamp;
        record.position = position;
        record.quaternion = quaternion;
        record.intrinsics = intrinsics;

        // 耗时操作：JPEG + LZFSE 压缩（在后台队列执行）
        record.jpegData = [self jpegFromPixelBuffer:colorBuffer];
        record.depthWidth = CVPixelBufferGetWidth(depthBuffer);
        record.depthHeight = CVPixelBufferGetHeight(depthBuffer);
        record.depthData = [self lzfseCompressPixelBuffer:depthBuffer
                                                formatType:kCVPixelFormatType_DepthFloat32];
        if (confidenceBuffer) {
            record.confidenceData = [self lzfseCompressPixelBuffer:confidenceBuffer
                                                          formatType:kCVPixelFormatType_ConfidenceMap];
        }

        CVPixelBufferRelease(colorBuffer);
        CVPixelBufferRelease(depthBuffer);
        if (confidenceBuffer) {
            CVPixelBufferRelease(confidenceBuffer);
        }

        @synchronized (self) {
            [self.records addObject:record];
        }
    });
}

- (NSArray<FrameRecord *> *)stopRecording {
    // 等待所有进行中的任务完成后再快照
    dispatch_sync(self.processingQueue, ^{});
    @synchronized (self) {
        NSArray<FrameRecord *> *snapshot = [self.records copy];
        [self.records removeAllObjects];
        return snapshot;
    }
}

- (NSUInteger)frameCount {
    @synchronized (self) {
        return self.records.count;
    }
}

- (BOOL)isRecording {
    return YES;
}

#pragma mark - JPEG 转换

- (NSData *)jpegFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CGFloat w = ciImage.extent.size.width;
    CGFloat h = ciImage.extent.size.height;

    // 如果传感器方向为横屏，则旋转为竖屏
    CIImage *workingImage = ciImage;
    if (w > h) {
        workingImage = [ciImage imageByApplyingOrientation:kCGImagePropertyOrientationRight];
    }

    CGRect cropRect = [self cropRectForImageSize:workingImage.extent.size
                                       targetSize:kTargetColorSize];
    CIImage *croppedImage = [workingImage imageByCroppingToRect:cropRect];

    CGFloat scaleX = kTargetColorSize.width / cropRect.size.width;
    CGFloat scaleY = kTargetColorSize.height / cropRect.size.height;
    CIImage *scaledImage = [croppedImage imageByApplyingTransform:CGAffineTransformMakeScale(scaleX, scaleY)];

    CGImageRef cgImage = [self.ciContext createCGImage:scaledImage
                                              fromRect:CGRectMake(0, 0, kTargetColorSize.width, kTargetColorSize.height)];
    if (!cgImage) {
        return nil;
    }

    UIImage *image = [UIImage imageWithCGImage:cgImage];
    NSData *jpegData = UIImageJPEGRepresentation(image, kJPEGQuality);
    CGImageRelease(cgImage);

    return jpegData;
}

- (CGRect)cropRectForImageSize:(CGSize)imageSize targetSize:(CGSize)targetSize {
    CGFloat targetAspect = targetSize.width / targetSize.height;
    CGFloat imageAspect = imageSize.width / imageSize.height;

    if (imageAspect > targetAspect) {
        CGFloat cropWidth = imageSize.height * targetAspect;
        return CGRectMake((imageSize.width - cropWidth) / 2, 0, cropWidth, imageSize.height);
    } else {
        CGFloat cropHeight = imageSize.width / targetAspect;
        return CGRectMake(0, (imageSize.height - cropHeight) / 2, imageSize.width, cropHeight);
    }
}

#pragma mark - LZFSE 压缩

- (NSData *)lzfseCompressPixelBuffer:(CVPixelBufferRef)pixelBuffer formatType:(OSType)formatType {
    if (!pixelBuffer) {
        return nil;
    }

    size_t width = CVPixelBufferGetWidth(pixelBuffer);
    size_t height = CVPixelBufferGetHeight(pixelBuffer);

    size_t elementSize = 0;
    if (formatType == kCVPixelFormatType_DepthFloat32) {
        elementSize = sizeof(float);
    } else if (formatType == kCVPixelFormatType_ConfidenceMap) {
        elementSize = sizeof(uint8_t);
    } else {
        return nil;
    }

    size_t dataSize = width * height * elementSize;

    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    const uint8_t *baseAddress = (const uint8_t *)CVPixelBufferGetBaseAddress(pixelBuffer);
    if (!baseAddress) {
        CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
        return nil;
    }

    NSData *rawData = [NSData dataWithBytes:baseAddress length:dataSize];
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);

    return [self lzfseCompressData:rawData];
}

- (NSData *)lzfseCompressData:(NSData *)input {
    if (!input || input.length == 0) {
        return nil;
    }

    size_t srcSize = input.length;
    const uint8_t *src = (const uint8_t *)input.bytes;

    size_t dstCapacity = srcSize + 256;
    uint8_t *dst = malloc(dstCapacity);
    if (!dst) {
        return nil;
    }

    size_t compressedSize = compression_encode_buffer(dst, dstCapacity,
                                                       src, srcSize,
                                                       NULL, COMPRESSION_LZFSE);
    if (compressedSize == 0) {
        free(dst);
        return nil;
    }

    NSData *result = [NSData dataWithBytes:dst length:compressedSize];
    free(dst);
    return result;
}

@end
