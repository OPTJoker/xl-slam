//
//  ZipWriter.m
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import "ZipWriter.h"
#import <zlib.h>

@interface ZipWriter ()

@property (nonatomic, strong) NSString *outputPath;
@property (nonatomic, strong) NSMutableData *fileData;
@property (nonatomic, strong) NSMutableArray<NSData *> *centralDirectory;
@property (nonatomic) NSUInteger currentOffset;

@end

@implementation ZipWriter

#pragma mark - 初始化

- (instancetype)initWithPath:(NSString *)path {
    self = [super init];
    if (self) {
        _outputPath = [path copy];
        _fileData = [[NSMutableData alloc] init];
        _centralDirectory = [[NSMutableArray alloc] init];
        _currentOffset = 0;
        _fileCount = 0;
        [[NSFileManager defaultManager] createFileAtPath:path contents:nil attributes:nil];
    }
    return self;
}

#pragma mark - 公开方法

- (BOOL)addFileWithName:(NSString *)name data:(NSData *)data {
    if (!name || !data) {
        return NO;
    }

    NSData *nameData = [name dataUsingEncoding:NSUTF8StringEncoding];
    uLong crc = crc32(0, data.bytes, (uInt)data.length);
    uint32_t size = (uint32_t)data.length;

    // --- 本地文件头 ---
    NSMutableData *localHeader = [[NSMutableData alloc] init];

    uint32_t signature = 0x04034b50;
    [localHeader appendBytes:&signature length:4];

    uint16_t versionNeeded = 20;
    [localHeader appendBytes:&versionNeeded length:2];

    uint16_t flags = 0;
    [localHeader appendBytes:&flags length:2];

    uint16_t method = 0; // 不压缩（Stored 模式）
    [localHeader appendBytes:&method length:2];

    uint16_t modTime = 0;
    uint16_t modDate = 0;
    [localHeader appendBytes:&modTime length:2];
    [localHeader appendBytes:&modDate length:2];

    [localHeader appendBytes:&crc length:4];
    [localHeader appendBytes:&size length:4]; // compressed size
    [localHeader appendBytes:&size length:4]; // uncompressed size

    uint16_t nameLen = (uint16_t)nameData.length;
    [localHeader appendBytes:&nameLen length:2];

    uint16_t extraLen = 0;
    [localHeader appendBytes:&extraLen length:2];

    [localHeader appendData:nameData];

    // 写入本地文件头 + 文件数据
    [self.fileData appendData:localHeader];
    [self.fileData appendData:data];

    // --- 中央目录条目 ---
    NSMutableData *cdEntry = [[NSMutableData alloc] init];

    uint32_t cdSignature = 0x02014b50;
    [cdEntry appendBytes:&cdSignature length:4];

    uint16_t versionMadeBy = 20;
    [cdEntry appendBytes:&versionMadeBy length:2];

    [cdEntry appendBytes:&versionNeeded length:2];
    [cdEntry appendBytes:&flags length:2];
    [cdEntry appendBytes:&method length:2];
    [cdEntry appendBytes:&modTime length:2];
    [cdEntry appendBytes:&modDate length:2];
    [cdEntry appendBytes:&crc length:4];
    [cdEntry appendBytes:&size length:4];
    [cdEntry appendBytes:&size length:4];

    [cdEntry appendBytes:&nameLen length:2];
    [cdEntry appendBytes:&extraLen length:2];

    uint16_t commentLen = 0;
    [cdEntry appendBytes:&commentLen length:2];

    uint16_t diskStart = 0;
    [cdEntry appendBytes:&diskStart length:2];

    uint16_t internalAttrs = 0;
    [cdEntry appendBytes:&internalAttrs length:2];

    uint32_t externalAttrs = 0;
    [cdEntry appendBytes:&externalAttrs length:4];

    uint32_t headerOffset = (uint32_t)self.currentOffset;
    [cdEntry appendBytes:&headerOffset length:4];

    [cdEntry appendData:nameData];

    [self.centralDirectory addObject:cdEntry];

    self.currentOffset = (uint32_t)(localHeader.length + data.length + self.currentOffset);
    _fileCount++;

    return YES;
}

- (BOOL)close {
    uint32_t cdOffset = (uint32_t)self.fileData.length;

    // 写入中央目录
    for (NSData *entry in self.centralDirectory) {
        [self.fileData appendData:entry];
    }

    uint32_t cdSize = (uint32_t)(self.fileData.length - cdOffset);

    // --- 中央目录结束记录 ---
    NSMutableData *eocd = [[NSMutableData alloc] init];

    uint32_t eocdSignature = 0x06054b50;
    [eocd appendBytes:&eocdSignature length:4];

    uint16_t diskNum = 0;
    [eocd appendBytes:&diskNum length:2];
    [eocd appendBytes:&diskNum length:2]; // disk where CD starts

    uint16_t totalEntries = (uint16_t)self.centralDirectory.count;
    [eocd appendBytes:&totalEntries length:2];
    [eocd appendBytes:&totalEntries length:2];

    [eocd appendBytes:&cdSize length:4];
    [eocd appendBytes:&cdOffset length:4];

    uint16_t commentLen = 0;
    [eocd appendBytes:&commentLen length:2];

    [self.fileData appendData:eocd];

    // 写入磁盘文件
    return [self.fileData writeToFile:self.outputPath atomically:YES];
}

@end
