//
//  SLHCropEditor.m
//  Slash
//
//  Created by Terminator on 2019/03/26.
//  Copyright © 2019年 digital-pers0n. All rights reserved.
//

#import "SLHCropEditor.h"
#import "SLHImageView.h"
#import "SLHEncoderItem.h"
#import "SLHMediaItem.h"
#import "SLHFilterOptions.h"

extern NSString *const SLHPreferencesFFMpegFilePathKey;

@interface SLHCropEditor () <SLHImageViewDelegate, NSWindowDelegate> {
    
    IBOutlet SLHImageView *_imageView;
    SLHEncoderItem *_encoderItem;
    NSString *_ffmpegPath;
    dispatch_queue_t _bg_queue;
    dispatch_queue_t _main_queue;
    
    BOOL _zoomed;
}

@property double startTime;

@end

@implementation SLHCropEditor

- (NSString *)windowNibName {
    return self.className;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    NSString *ffmpegPath = [[NSUserDefaults standardUserDefaults] objectForKey:SLHPreferencesFFMpegFilePathKey];
    if (!ffmpegPath) {
        ffmpegPath = @"/usr/local/bin/ffmpeg";
    }
    _ffmpegPath = ffmpegPath;
    _bg_queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0);
    _main_queue = dispatch_get_main_queue();
    _imageView.currentToolMode = IKToolModeSelect;
}

#pragma mark - IBActions

- (IBAction)xDidChange:(id)sender {
    NSRect r = _imageView.selectionRect;
    r.origin.x = _encoderItem.filters.videoCropX;
    _imageView.selectionRect = r;
}

- (IBAction)yDidChange:(id)sender {
    NSRect r = _imageView.selectionRect;
    r.origin.y = _encoderItem.filters.videoCropY;
    _imageView.selectionRect = r;
}

- (IBAction)widthDidChange:(id)sender {
    NSRect r = _imageView.selectionRect;
    r.size.width = _encoderItem.filters.videoCropWidth;
    _imageView.selectionRect = r;
}

- (IBAction)heightDidChange:(id)sender {
    NSRect r = _imageView.selectionRect;
    r.size.height = _encoderItem.filters.videoCropHeight;
    _imageView.selectionRect = r;
}

- (NSRect)cropArea {
    NSRect r = NSZeroRect;
    char *cmd;
    asprintf(&cmd, "%s -ss %.3f -i \"%s\" -vf cropdetect -t 3 -f null - 2>&1"
             " | awk '/crop/ { print $NF }' | tail -1",
             _ffmpegPath.UTF8String, _startTime, _encoderItem.mediaItem.filePath.UTF8String);
    FILE *pipe = popen(cmd, "r");
    const int len = 64;
    char str[len];
    if (fgets(str, len, pipe)) {
        char *start = strchr(str, '=');
        char *end = strchr(str, ':');
        long result[4] = {0, 0, 0, 0};
        _get_coordinates(++start, end, 0, result);
        r = NSMakeRect(result[2], result[3], result[0], result[1]);
    }
    free(cmd);
    pclose(pipe);
    
    return r;
}

- (IBAction)detectCropArea:(NSButton *)sender {
    sender.enabled = NO;
    dispatch_async(_bg_queue, ^{
        NSRect rect = [self cropArea];
        SLHFilterOptions *options = _encoderItem.filters;
        options.videoCropX = rect.origin.x;
        options.videoCropY = rect.origin.y;
        options.videoCropWidth = rect.size.width;
        options.videoCropHeight = rect.size.height;
        dispatch_sync(_main_queue, ^{
            sender.enabled = YES;
            _imageView.selectionRect = rect;
        });
    });
}

- (IBAction)zoom:(NSButton *)sender {
    NSRect rect = _imageView.selectionRect;
    if (_zoomed) {
        [_imageView zoomImageToFit:nil];
        _zoomed = NO;
        _imageView.autoresizes = YES;
        sender.image = [NSImage imageNamed:NSImageNameEnterFullScreenTemplate];
    } else {
        [_imageView zoomImageToActualSize:nil];
        _zoomed = YES;
        sender.image = [NSImage imageNamed:NSImageNameExitFullScreenTemplate];
    }
    _imageView.selectionRect = rect;
}

- (IBAction)preview:(id)sender {
}

// Problems (Tested under macOS 10.11)
// When the IKImageView.currentToolMode property is set to IKToolModeSelect and a new image is loaded :
// 1. The coordinates of the selection layer are all messed up.
//    The layer doesn't auto scale with the view. The selection rect doesn't appear under the mouse pointer.
//
// 2. The IKImageView setImage:imageProperties: method crashes the application.
//
// Solution
// Assign the IKImageView.currentToolMode property to IKToolModeNone before loading a new image

- (IBAction)reloadFrame:(id)sender {
    _zoomed = NO;
    NSRect rect = _imageView.selectionRect;
    _imageView.currentToolMode = IKToolModeNone;
    [self _extractFrame];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), _main_queue, ^{
        _imageView.selectionRect = rect;

    });
    
}

#pragma mark - Properties

- (void)setEncoderItem:(SLHEncoderItem *)encoderItem {
    _imageView.currentToolMode = IKToolModeNone;
    _encoderItem = encoderItem;
    self.startTime = _encoderItem.interval.start;
    SLHFilterOptions *options = encoderItem.filters;
    _zoomed = NO;
    [self _extractFrame];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), _main_queue, ^{
        NSRect rect = NSMakeRect(options.videoCropX, options.videoCropY, options.videoCropWidth, options.videoCropHeight);
        _imageView.selectionRect = rect;

    });

}

- (SLHEncoderItem *)encoderItem {
    return _encoderItem;
}

#pragma mark - NSWindowDelegate

- (void)windowDidBecomeMain:(NSNotification *)notification {
    _hasWindow = YES;
}

- (void)windowWillClose:(NSNotification *)notification {
    _hasWindow = NO;
}

#pragma mark - SLHImageViewDelegate

- (void)imageView:(SLHImageView *)view didUpdateSelection:(NSRect)rect {
    SLHFilterOptions *options = _encoderItem.filters;
    options.videoCropX = rect.origin.x;
    options.videoCropY = rect.origin.y;
    options.videoCropWidth = rect.size.width;
    options.videoCropHeight = rect.size.height;
}

#pragma mark - Private

/**
 Extract coordinates from a char array and store them in the result array.
 
 @param result - [0] - width, [1] - height, [2] - x, [3] - y
 */
static void _get_coordinates(char *start, char *end, int n, long *result) {
    char value[6];
    int i = 0;
    while (start < end) {
        value[i] = *start;
        start++;
        i++;
    }
    long r = atol(value);
    result[n] = r;
    n++;
    start++;
    end = strchr(start, ':');
    if (!end) {
        r = atol(start);
        result[n] = r;
        return;
    }
    _get_coordinates(start, end, n, result);
}

static inline void _safeCFRelease(CFTypeRef ref) {
    if (ref) {
        CFRelease(ref);
    }
}

- (void)_extractFrame {
    dispatch_async(_bg_queue, ^{
        char *cmd;
        asprintf(&cmd, "%s -loglevel 0 -ss %.3f -i \"%s\""
                 " -vf \"rotate=PI,hflip\" -vframes 1 -q:v 2 -f image2pipe -",
                 _ffmpegPath.UTF8String, _startTime, _encoderItem.mediaItem.filePath.UTF8String);
        FILE *pipe = popen(cmd, "r");
        const size_t block_length = 4096;
        size_t bytes_total = 0;
        size_t bytes_read = 0;
        char *output = malloc(block_length * sizeof(char));
        while ((bytes_read = fread(output + bytes_total, sizeof(char), block_length, pipe)) > 0) {
            bytes_total += bytes_read;
            char *tmp = realloc(output, bytes_total * sizeof(char) + block_length);
            if (!tmp) {
                exit(EXIT_FAILURE);
            }
            output = tmp;
        }
        CFDataRef cfdata_ref = CFDataCreate(NULL, (UInt8 *)output, bytes_total);
        CGImageSourceRef cfimage_source_ref = CGImageSourceCreateWithData(cfdata_ref, NULL);
        CGImageRef cfimage_ref = CGImageSourceCreateImageAtIndex(cfimage_source_ref, 0, NULL);
        if (cfimage_ref) {
           
            dispatch_sync(_main_queue, ^{
                // Hide the view to disable its annoying flip animtion
                 _imageView.hidden = YES;
                [_imageView setImage:cfimage_ref imageProperties:0];
                // Rotate and flip the frame because ffmpeg and Cocoa are using different coordinates
                
                _imageView.rotationAngle = M_PI;
                [_imageView flipImageHorizontal:nil];
                [_imageView zoomImageToFit:nil];
                
                _imageView.autoresizes = YES;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), _main_queue, ^{
                    _imageView.hidden = NO;
                });
            });

        } else {
            NSLog(@"%s Error: invalid data", __PRETTY_FUNCTION__);
        }
        free(cmd);
        pclose(pipe);
        free(output);
        _safeCFRelease(cfimage_ref);
        _safeCFRelease(cfimage_source_ref);
        _safeCFRelease(cfdata_ref);
    });
}

@end
