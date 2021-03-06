//
//  SLHEncoderItem.h
//  Slash
//
//  Created by Terminator on 2018/11/15.
//  Copyright © 2018年 digital-pers0n. All rights reserved.
//

#import <Foundation/Foundation.h>

@class SLHEncoderItemOptions, SLHFilterOptions, SLHEncoderItemMetadata;
@class MPVPlayerItem;

NS_ASSUME_NONNULL_BEGIN

typedef struct time_interval {
    double start;
    double end;
} TimeInterval;

@class SLHMediaItem;

@interface SLHEncoderItem : NSObject <NSCopying>

/** @deprecated Use MPVPlayerItem instead */
- (instancetype)initWithMediaItem:(SLHMediaItem *)item __attribute__((deprecated));

/** @deprecated Use MPVPlayerItem instead */
- (instancetype)initWithMediaItem:(SLHMediaItem *) item outputPath:(NSString *)outputMediaPath __attribute__((deprecated));

/** @deprecated Use MPVPlayerItem instead */
@property SLHMediaItem *mediaItem __attribute__((deprecated));

- (instancetype)initWithPlayerItem:(MPVPlayerItem *)item;
- (instancetype)initWithPlayerItem:(MPVPlayerItem *)item outputPath:(NSString *)outputMediaPath;

@property (nonatomic) MPVPlayerItem *playerItem;

- (void)matchSource;

@property NSString *outputPath;
@property NSString *outputFileName;
@property NSString *container;

@property TimeInterval interval;

@property NSInteger videoStreamIndex;
@property NSInteger audioStreamIndex;
@property NSInteger subtitlesStreamIndex;

@property SLHEncoderItemOptions *videoOptions;
@property SLHEncoderItemOptions *audioOptions;

@property SLHFilterOptions *filters;

@property BOOL twoPassEncoding;

@property SLHEncoderItemMetadata *metadata;

@property (readonly) NSString * summary;

@property NSInteger tag;

@property NSArray <NSArray *> *encoderArguments;

/* Cocoa Bindings */
@property double intervalStart;
@property double intervalEnd;

/** Duration of a segment (seconds) */
@property (readonly, nonatomic) double duration;

/** Estimated output file size (bytes) */
@property (readonly, nonatomic) uint64_t estimatedSize;

@end

NS_ASSUME_NONNULL_END
