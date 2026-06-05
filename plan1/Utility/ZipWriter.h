//
//  ZipWriter.h
//  plan1
//
//  Created by sharon on 2026/5/28.
//

#import <Foundation/Foundation.h>

@interface ZipWriter : NSObject

- (instancetype)initWithPath:(NSString *)path;
- (BOOL)addFileWithName:(NSString *)name data:(NSData *)data;
- (BOOL)close;

@property (nonatomic, readonly) NSUInteger fileCount;

@end
