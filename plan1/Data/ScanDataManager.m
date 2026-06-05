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

@end

@implementation ScanDataManager

#pragma mark - Init

- (instancetype)init {
    self = [super init];
    if (self) {
        _records = [[NSMutableArray alloc] init];
        _ciContext = [[CIContext alloc] init];
    }
    return self;
}

#pragma mark - Public

- (void)startRecording {
    [self.records removeAllObjects];
}

- (void)recordFrame:(ARFrame *)frame {
    if (!frame) {
        return;
    }

    ARDepthData *depthData = frame.smoothedSceneDepth;
    if (!depthData || !depthData.depthMap) {
        return;
    }

    FrameRecord *record = [[FrameRecord alloc] init];
    record.timestamp = frame.timestamp;

    // Pose
    simd_float4x4 transform = frame.camera.transform;
    record.position = simd_make_float3(transform.columns[3].x,
                                        transform.columns[3].y,
                                        transform.columns[3].z);
    simd_float3x3 rotation = {
        transform.columns[0].xyz,
        transform.columns[1].xyz,
        transform.columns[2].xyz
    };
    record.quaternion = simd_quaternion(rotation);

    // Intrinsics
    record.intrinsics = frame.camera.intrinsics;

    // Color image
    record.jpegData = [self jpegFromPixelBuffer:frame.capturedImage];

    // Depth
    record.depthData = [self lzfseCompressPixelBuffer:depthData.depthMap
                                            formatType:kCVPixelFormatType_DepthFloat32];

    // Confidence
    record.confidenceData = [self lzfseCompressPixelBuffer:depthData.confidenceMap
                                                  formatType:kCVPixelFormatType_ConfidenceMap];

    [self.records addObject:record];
}

- (NSArray<FrameRecord *> *)stopRecording {
    NSArray<FrameRecord *> *snapshot = [self.records copy];
    [self.records removeAllObjects];
    return snapshot;
}

- (NSUInteger)frameCount {
    return self.records.count;
}

- (BOOL)isRecording {
    return YES;
}

#pragma mark - JPEG Conversion

- (NSData *)jpegFromPixelBuffer:(CVPixelBufferRef)pixelBuffer {
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CGFloat w = ciImage.extent.size.width;
    CGFloat h = ciImage.extent.size.height;

    // Rotate to portrait if sensor is landscape
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

#pragma mark - LZFSE Compression

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
