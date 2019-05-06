//
//  SLHEncoderX264Format.m
//  Slash
//
//  Created by Terminator on 2018/12/05.
//  Copyright © 2018年 digital-pers0n. All rights reserved.
//

#import "SLHEncoderX264Format.h"
#import "SLHEncoderX264Options.h"
#import "SLHPreferences.h"
#import "SLHEncoderItem.h"
#import "SLHEncoderItemMetadata.h"
#import "SLHMediaItem.h"
#import "SLHFiltersController.h"
#import "SLHEncoderArgument.h"

extern NSString *const SLHEncoderMediaMapKey;
extern NSString *const SLHEncoderMediaContainerKey;
extern NSString *const SLHEncoderMediaStartTimeKey;
extern NSString *const SLHEncoderMediaEndTimeKey;
extern NSString *const SLHEncoderMediaNoSubtitlesKey;
extern NSString *const SLHEncoderMediaOverwriteFilesKey;
extern NSString *const SLHEncoderVideoBufsizeKey;
extern NSString *const SLHEncoderVideoBitrateKey;
extern NSString *const SLHEncoderVideoMaxBitrateKey;
extern NSString *const SLHEncoderVideoCRFBitrateKey;
extern NSString *const SLHEncoderVideoCodecKey;
extern NSString *const SLHEncoderVideoFiltersKey;
extern NSString *const SLHEncoderVideoScaleSizeKey;
extern NSString *const SLHEncoderVideoMovflagsKey;
extern NSString *const SLHEncoderVideoPixelFormatKey;
extern NSString *const SLHEncoderVideoH264ProfileKey;
extern NSString *const SLHEncoderVideoH264LevelKey;
extern NSString *const SLHEncoderVideoH264PresetKey;
extern NSString *const SLHEncoderVideoH264TuneKey;
extern NSString *const SLHEncoderMediaNoVideoKey ;
extern NSString *const SLHEncoderAudioCodecKey;
extern NSString *const SLHEncoderAudioBitrateKey;
extern NSString *const SLHEncoderAudioQualityKey;
extern NSString *const SLHEncoderAudioFilterKey;
extern NSString *const SLHEncoderAudioSampleRateKey;
extern NSString *const SLHEncoderAudioChannelsKey;
extern NSString *const SLHEncoderMediaNoAudioKey ;

typedef NS_ENUM(NSUInteger, SLHX264AudioSampleRateType) {
    SLHX264AudioSampleRate32000 = 32000,
    SLHX264AudioSampleRate44100 = 44100,
    SLHX264AudioSampleRate48000 = 48000,
};

typedef NS_ENUM(NSUInteger, SLHX264AudioChannelsType) {
    SLHX264AudioChannels1 = 1,
    SLHX264AudioChannels2,
    SLHX264AudioChannels51 = 6,
};

@interface SLHEncoderX264Format () {
    
    SLHFiltersController *_filters;
    SLHEncoderItem *_encoderItem;
    
    IBOutlet NSView *_videoView;
    IBOutlet NSView *_audioView;
    
    // Video
    
    IBOutlet NSPopUpButton *_presetPopUp;
    IBOutlet NSPopUpButton *_encodingTypePopUp;
    IBOutlet NSView *_bitrateView;
    IBOutlet NSView *_maxBitrateView;
    IBOutlet NSView *_crfView;
    IBOutlet NSPopUpButton *_tunePopUp;
    IBOutlet NSPopUpButton *_containerPopUp;
    IBOutlet NSPopUpButton *_profilePopUp;
    IBOutlet NSPopUpButton *_levelPopUp;
    
    
    // Audio
    
    IBOutlet NSPopUpButton *_audioCodecPopUp;
    IBOutlet NSPopUpButton *_audioSampleRatePopUp;
    IBOutlet NSPopUpButton *_audioChannelsPopUp;
    
}

@end

@implementation SLHEncoderX264Format

- (NSString *)nibName {
    return self.className;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    _filters = [SLHFiltersController filtersController];
    [self _initializePopUps];
    
    // Set up _crfView

    _crfView.hidden = YES;
    _crfView.frame = _bitrateView.frame;
    _crfView.autoresizingMask = _bitrateView.autoresizingMask;
    [_videoView addSubview:_crfView];

}

- (NSString *)formatName {
    return @"H264";
}

- (SLHEncoderItem *)encoderItem {
    return _encoderItem;
}

- (void)setEncoderItem:(SLHEncoderItem *)encoderItem {
    _encoderItem = encoderItem;
    SLHEncoderX264Options *videoOptions = (SLHEncoderX264Options *)_encoderItem.videoOptions;
    SLHEncoderItemOptions *audioOptions = _encoderItem.audioOptions;
    
    if (![_encoderItem.videoOptions isKindOfClass:[SLHEncoderX264Options class]]) {
        videoOptions = [[SLHEncoderX264Options alloc] initWithOptions:videoOptions];
        videoOptions.encodingType = SLHX264EncodingSinglePass;
        videoOptions.presetType = SLHX264PresetNone;
        videoOptions.profileType = SLHX264ProfileNone;
        videoOptions.levelType = SLHX264LevelNone;
        videoOptions.tuneType = SLHX264TuneNone;
        videoOptions.containerType = SLHX264ContainerMP4;
        videoOptions.codecName = @"libx264";
        videoOptions.crf = 23;
        videoOptions.faststart = YES;
        _encoderItem.videoOptions = videoOptions;
        _encoderItem.container = @"mp4";
        
        audioOptions.codecName = @"aac";
        audioOptions.bitRate = 128;
        audioOptions.sampleRate = SLHX264AudioSampleRate44100;
        audioOptions.numberOfChannels = SLHX264AudioChannels2;
    }
    
    if (self.view) {
        [_presetPopUp selectItemWithTag:videoOptions.presetType];
        [_encodingTypePopUp selectItemWithTag:videoOptions.encodingType];
        [_tunePopUp selectItemWithTag:videoOptions.tuneType];
        [_containerPopUp selectItemWithTag:videoOptions.containerType];
        [_profilePopUp selectItemWithTag:videoOptions.profileType];
        [_levelPopUp selectItemWithTag:videoOptions.levelType];
        [self _changeEncodingType];
        
        [_audioSampleRatePopUp selectItemWithTag:audioOptions.sampleRate];
        [_audioChannelsPopUp selectItemWithTag:audioOptions.numberOfChannels];
        
        _filters.encoderItem = _encoderItem;
    }
}

- (NSArray *)arguments {
    NSUserDefaults *defs = [NSUserDefaults standardUserDefaults];
    NSString *ffmpegPath = [defs objectForKey:SLHPreferencesFFMpegFilePathKey];
    if (!ffmpegPath) {
        NSLog(@"%s: ffmpeg file path is not set", __PRETTY_FUNCTION__);
        return nil;
    }
    SLHEncoderX264Options *options = (id)_encoderItem.videoOptions;
    NSMutableArray *args = @[
                             ffmpegPath, @"-nostdin", @"-hide_banner",
                             @"-ss", @(_encoderItem.interval.start).stringValue,
                             @"-i", _encoderItem.mediaItem.filePath
                             ].mutableCopy;
    if (_encoderItem.videoStreamIndex >= 0) {
        [args addObject:SLHEncoderMediaMapKey];
        [args addObject:[NSString stringWithFormat:@"0:%li", _encoderItem.videoStreamIndex]];
        [args addObjectsFromArray:[self _videoArguments]];
    } else {
        [args addObject:SLHEncoderMediaNoVideoKey ];
    }
    
    if (_encoderItem.audioStreamIndex >= 0) {
        [args addObject:SLHEncoderMediaMapKey];
        [args addObject:[NSString stringWithFormat:@"0:%li", _encoderItem.audioStreamIndex]];
        [args addObjectsFromArray:[self _audioArguments]];
    } else {
        [args addObject:SLHEncoderMediaNoAudioKey ];
    }
    
    if (_encoderItem.subtitlesStreamIndex == -1) {
        [args addObject:SLHEncoderMediaNoSubtitlesKey];
    } else {
        [args addObject:SLHEncoderMediaMapKey];
        [args addObject:[NSString stringWithFormat:@"0:%li", _encoderItem.subtitlesStreamIndex]];
        [args addObject:@"-c:s"];
        SLHX264ContainerType type = options.containerType;
        if (type == SLHX264ContainerMP4 ||
            type == SLHX264ContainerM4V ||
            type == SLHX264ContainerMOV) {
            
            [args addObject:@"mov_text"];
        } else {
            [args addObject:@"copy"];
        }
    }
    
    [args addObjectsFromArray:_filters.arguments];
    [args addObject:SLHEncoderMediaEndTimeKey];
    [args addObject:@(_encoderItem.interval.end - _encoderItem.interval.start).stringValue];
    [args addObject:SLHEncoderMediaOverwriteFilesKey];
    
    if (options.encodingType == SLHX264EncodingTwoPass) {
        [args addObject:SLHEncoderVideoBufsizeKey];
        [args addObject:@"1024k"];
        NSMutableArray *passOne = args.mutableCopy;
        [passOne addObject:@"/dev/null"];
        [args addObjectsFromArray:_encoderItem.metadata.arguments];
        [args addObject:_encoderItem.outputPath];
        return @[passOne, args];
    }
    [args addObjectsFromArray:_encoderItem.metadata.arguments];
    [args addObject:_encoderItem.outputPath];
    return @[args];
}

#pragma mark - IBActions

- (IBAction)presetDidChange:(NSPopUpButton *)sender {
    ((SLHEncoderX264Options *)_encoderItem.videoOptions).presetType = sender.selectedTag;
}

- (IBAction)encodingTypeDidChange:(NSPopUpButton *)sender {
    ((SLHEncoderX264Options *)_encoderItem.videoOptions).encodingType = sender.selectedTag;
    [self _changeEncodingType];
}

- (IBAction)tuneDidChange:(NSPopUpButton *)sender {
    ((SLHEncoderX264Options *)_encoderItem.videoOptions).tuneType = sender.selectedTag;
}

- (IBAction)containerDidChange:(NSPopUpButton *)sender {
    SLHX264ContainerType tag = sender.selectedTag;
    NSString *outputFileName = _encoderItem.outputFileName;
    
    switch (tag) {
        case SLHX264ContainerMP4:
            outputFileName = [outputFileName stringByDeletingPathExtension];
            outputFileName = [outputFileName stringByAppendingPathExtension:@"mp4"];
            _encoderItem.container = @"mp4";
            break;
        case SLHX264ContainerM4V:
            outputFileName = [outputFileName stringByDeletingPathExtension];
            outputFileName = [outputFileName stringByAppendingPathExtension:@"m4v"];
            _encoderItem.container = @"m4v";
            break;
        case SLHX264ContainerMKV:
            outputFileName = [outputFileName stringByDeletingPathExtension];
            outputFileName = [outputFileName stringByAppendingPathExtension:@"mkv"];
            _encoderItem.container = @"mkv";
            break;
        case SLHX264ContainerMOV:
            outputFileName = [outputFileName stringByDeletingPathExtension];
            outputFileName = [outputFileName stringByAppendingPathExtension:@"mov"];
            _encoderItem.container = @"mov";
            break;
            
        default:
            break;
    }
    _encoderItem.outputFileName = outputFileName;
    ((SLHEncoderX264Options *)_encoderItem.videoOptions).containerType = tag;
}

- (IBAction)profileDidChange:(NSPopUpButton *)sender {
    ((SLHEncoderX264Options *)_encoderItem.videoOptions).profileType = sender.selectedTag;
}

- (IBAction)levelDidChange:(NSPopUpButton *)sender {
    ((SLHEncoderX264Options *)_encoderItem.videoOptions).levelType = sender.selectedTag;
}

- (IBAction)sampleRateDidChange:(NSPopUpButton *)sender {
    _encoderItem.audioOptions.sampleRate = sender.selectedTag;
}

- (IBAction)channelsDidChange:(NSPopUpButton *)sender {
    _encoderItem.audioOptions.numberOfChannels = sender.selectedTag;
}

#pragma mark - Private

- (void)_changeEncodingType {
    SLHEncoderX264Options *options = (SLHEncoderX264Options *)_encoderItem.videoOptions;
    switch (options.encodingType) {
        case SLHX264EncodingSinglePass:
            _crfView.hidden = YES;
            _bitrateView.hidden = NO;
            _maxBitrateView.hidden = YES;
            
            break;
            
        case SLHX264EncodingTwoPass:
            _crfView.hidden = YES;
            _bitrateView.hidden = NO;
            _maxBitrateView.hidden = NO;

            break;
            
        case SLHX264EncodingCRFSinglePass:
            _crfView.hidden = NO;
            _bitrateView.hidden = YES;
            
        default:
            break;
    }
}

- (void)_initializePopUps {
    NSMenuItem *menuItem;
    NSMenu *menu;
    
    // Video
    
    {   // encodingTypePopUp
        menu = _encodingTypePopUp.menu;
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Single Pass" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264EncodingSinglePass;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Two Pass" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264EncodingTwoPass;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"CRF" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264EncodingCRFSinglePass;
        [menu addItem:menuItem];
    }
    
    {   // presetPopUp
        menu = _presetPopUp.menu;
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Ultra Fast" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264PresetUltrafast;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Super Fast" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264PresetSuperfast;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Very Fast" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264PresetVeryfast;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Faster" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264PresetFaster;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Fast" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264PresetFast;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Medium" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264PresetMedium;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Slow" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264PresetSlow;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Slower" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264PresetSlower;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Very Slow" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264PresetVeryslow;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Placebo" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264PresetPlacebo;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"None" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264PresetNone;
        [menu addItem:menuItem];
    }
    
    {   // tunePopUp
        menu = _tunePopUp.menu;
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Film" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264TuneFilm;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Animation" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264TuneAnimation;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Preserve Grain" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264TuneGrain;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Still Image" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264TuneStill;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"PSNR" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264TunePsnr;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"SSIM" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264TuneSsim;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"None" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264TuneNone;
        [menu addItem:menuItem];
    }
    
    {   // containerPopUp
        menu = _containerPopUp.menu;
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"MP4" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264ContainerMP4;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"M4V" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264ContainerM4V;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"MKV" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264ContainerMKV;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"MOV" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264ContainerMOV;
        [menu addItem:menuItem];
    }
    
    {   // profilePopUp
        menu = _profilePopUp.menu;
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Baseline" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264ProfileBaseline;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Main" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264ProfileMain;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"High" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264ProfileHigh;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Auto" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264ProfileNone;
        [menu addItem:menuItem];
    }
    
    {   // levelPopUp
        menu = _levelPopUp.menu;
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"1.0" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level10;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"1.1" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level11;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"1.2" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level12;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"1.3" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level13;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"2.0" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level20;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"2.1" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level21;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"2.2" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level22;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"3.0" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level30;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"3.1" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level31;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"3.2" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level32;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"4.0" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level40;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"4.1" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level41;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"4.2" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level42;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"5.0" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level50;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"5.1" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264Level51;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Auto" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264LevelNone;
        [menu addItem:menuItem];
    }
    
    // Audio
    
    {   // audioCodecPopUp
        // there is only one codec
        menu = _audioCodecPopUp.menu;
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"AAC" action:nil keyEquivalent:@""];
        [menu addItem:menuItem];
    }
    
    {   // audioSampleRatePopUp
        menu = _audioSampleRatePopUp.menu;
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"32000 Hz" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264AudioSampleRate32000;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"441000 Hz" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264AudioSampleRate44100;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"48000 Hz" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264AudioSampleRate48000;
        [menu addItem:menuItem];

    }
    
    {   // audioChannelsPopUp
        menu = _audioChannelsPopUp.menu;
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Mono" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264AudioChannels1;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"Stereo" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264AudioChannels2;
        [menu addItem:menuItem];
        
        menuItem = [[NSMenuItem alloc] initWithTitle:@"5.1" action:nil keyEquivalent:@""];
        menuItem.tag = SLHX264AudioChannels51;
        [menu addItem:menuItem];
        
    }
}

- (NSArray *)_audioArguments {
    SLHEncoderItemOptions *audioOpts = _encoderItem.audioOptions;
    NSArray *args = @[
                      SLHEncoderAudioCodecKey, audioOpts.codecName,
                      SLHEncoderAudioBitrateKey, @(audioOpts.bitRate * 1024).stringValue,
                      SLHEncoderAudioSampleRateKey, @(audioOpts.sampleRate).stringValue,
                      SLHEncoderAudioChannelsKey, @(audioOpts.numberOfChannels).stringValue
                      ];
    return args;
}

- (NSArray *)_videoArguments {
    SLHEncoderX264Options *options = (id)_encoderItem.videoOptions;
    NSMutableArray *args = [NSMutableArray new];
    NSString *value;
    
    [args addObject:SLHEncoderVideoCodecKey];
    [args addObject:options.codecName];
    
    switch (options.encodingType) {
        case SLHX264EncodingSinglePass:
            [args addObject:SLHEncoderVideoBitrateKey];
            [args addObject:@(options.bitRate * 1024).stringValue];
            break;
        case SLHX264EncodingTwoPass:
            [args addObject:SLHEncoderVideoBitrateKey];
            [args addObject:@(options.bitRate * 1024).stringValue];
            [args addObject:SLHEncoderVideoMaxBitrateKey];
            [args addObject:@(options.maxBitrate * 1024).stringValue];
            break;
        case SLHX264EncodingCRFSinglePass:
            [args addObject:SLHEncoderVideoCRFBitrateKey];
            [args addObject:@(options.crf).stringValue];
            break;
            
        default:
            break;
    }
    
    switch (options.presetType) {
        case SLHX264PresetUltrafast:
            value = @"ultrafast";
            break;
        case  SLHX264PresetSuperfast:
            value = @"superfast";
            break;
        case SLHX264PresetVeryfast:
            value = @"veryfast";
            break;
        case SLHX264PresetFaster:
            value = @"faster";
            break;
        case SLHX264PresetFast:
            value = @"fast";
            break;
        case SLHX264PresetMedium:
            value = @"medium";
            break;
        case SLHX264PresetSlow:
            value = @"slow";
            break;
        case SLHX264PresetSlower:
            value = @"slower";
            break;
        case SLHX264PresetVeryslow:
            value = @"veryslow";
            break;
        case SLHX264PresetPlacebo:
            value = @"placebo";
            break;
        case SLHX264PresetNone:
        default:
            value = nil;
            break;
    }
    if (value) {
        [args addObject:SLHEncoderVideoH264PresetKey];
        [args addObject:value];
    }
    
    switch (options.profileType) {
        case SLHX264ProfileBaseline:
            value = @"baseline";
            break;
        case SLHX264ProfileMain:
            value = @"main";
            break;
        case SLHX264ProfileHigh:
            value = @"high";
            break;
        case SLHX264ProfileNone:
        default:
            value = nil;
            break;
    }
    if (value) {
        [args addObject:SLHEncoderVideoH264ProfileKey];
        [args addObject:value];
    }
    
    switch (options.levelType) {
        case SLHX264Level10:
            value = @"1.0";
            break;
        case SLHX264Level11:
            value = @"1.1";
            break;
        case SLHX264Level12:
            value = @"1.2";
            break;
        case SLHX264Level13:
            value = @"1.3";
            break;
        case SLHX264Level20:
            value = @"2.0";
            break;
        case SLHX264Level21:
            value = @"2.1";
            break;
        case SLHX264Level22:
            value = @"2.2";
            break;
        case SLHX264Level30:
            value = @"3.0";
            break;
        case SLHX264Level31:
            value = @"3.1";
            break;
        case SLHX264Level32:
            value = @"3.2";
            break;
        case SLHX264Level40:
            value = @"4.0";
            break;
        case SLHX264Level41:
            value = @"4.1";
            break;
        case SLHX264Level42:
            value = @"4.2";
            break;
        case SLHX264Level50:
            value = @"5.0";
            break;
        case SLHX264Level51:
            value = @"5.1";
            break;
        case SLHX264LevelNone:
        default:
            value = nil;
            break;
    }
    if (value) {
        [args addObject:SLHEncoderVideoH264LevelKey];
        [args addObject:value];
    }
    
    switch (options.containerType) {
        case SLHX264ContainerMP4:
            value = @"mp4";
            break;
        case SLHX264ContainerM4V:
            value = @"m4v";
            break;
        case SLHX264ContainerMKV:
            value = @"matroska";
            break;
        case SLHX264ContainerMOV:
            value = @"mov";
            break;
        case SLHX264ContainerNone:
        default:
            value = nil;
            break;
    }
    if (value) {
        [args addObject:SLHEncoderMediaContainerKey];
        [args addObject:value];
    }
    
    SLHX264TuneType tune = options.tuneType;
    if (tune != SLHX264TuneNone) {
        NSString *tmp = @"";
        switch (tune) {
            case SLHX264TuneFilm:
                tmp = @"film";
                break;
            case SLHX264TuneAnimation:
                tmp = @"animation";
                break;
            case SLHX264TuneGrain:
                tmp = @"grain";
                break;
            case SLHX264TuneStill:
                tmp = @"still";
                break;
            case SLHX264TunePsnr:
                tmp = @"psnr";
                break;
            case SLHX264TuneSsim:
                tmp = @"ssim";
                break;
                
            default:
                break;
        }
        value = [NSString stringWithFormat:@"%@%@%@", tmp,
                    (options.fastdecode) ? @",fastdecode" : @"",
                    (options.zerolatency) ? @",zerolatency" : @""];
    } else {
        if (options.fastdecode) {
            if (options.zerolatency) {
                value = @"fastdecode,zerolatency";
            } else {
                value = @"fastdecode";
            }
        } else if (options.zerolatency) {
            value = @"zerolatency";
        } else {
            value = nil;
        }
    }
    if (value) {
        [args addObject:SLHEncoderVideoH264TuneKey];
        [args addObject:value];
    }
    if (options.scale) {
        value = [NSString stringWithFormat:@"%lux%lu", options.videoWidth, options.videoHeight];
        [args addObject:SLHEncoderVideoScaleSizeKey];
        [args addObject:value];
    }
    if (options.faststart) {
        [args addObject:SLHEncoderVideoMovflagsKey];
        [args addObject:@"+faststart"];
    }
    [args addObject:SLHEncoderVideoPixelFormatKey];
    [args addObject:@"yuv420p"];
    
    return args;
}

#pragma mark - SLHEncoderSettingsDelegate

- (NSView *)encoderSettings:(SLHEncoderSettings *)enc viewForTab:(SLHEncoderSettingsTab) tab {
    NSView *view = nil;
    switch (tab) {
        case SLHEncoderSettingsVideoTab:
            view = _videoView;
            break;
        case SLHEncoderSettingsAudioTab:
            view = _audioView;
            break;
        case SLHEncoderSettingsFiltersTab:
            view = _filters.view;
            break;
            
        default:
            break;
    }
    return view;
}

@end
