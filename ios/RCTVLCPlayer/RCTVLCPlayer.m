#import "React/RCTConvert.h"
#import "RCTVLCPlayer.h"
#import "React/RCTBridgeModule.h"
#import "React/RCTEventDispatcher.h"
#import "React/UIView+React.h"
#import <MobileVLCKit/MobileVLCKit.h>
#import <AVFoundation/AVFoundation.h>
#import <React/RCTLog.h>

static NSString *const statusKeyPath = @"status";
static NSString *const playbackLikelyToKeepUpKeyPath = @"playbackLikelyToKeepUp";
static NSString *const playbackBufferEmptyKeyPath = @"playbackBufferEmpty";
static NSString *const readyForDisplayKeyPath = @"readyForDisplay";
static NSString *const playbackRate = @"rate";

@implementation RCTVLCPlayer
{

    /* Required to publish events */
    RCTEventDispatcher *_eventDispatcher;
    VLCMediaPlayer *_player;

    NSDictionary * _source;
    BOOL _paused;
    BOOL _started;

}

- (instancetype)initWithEventDispatcher:(RCTEventDispatcher *)eventDispatcher
{
    if ((self = [super init])) {
        _eventDispatcher = eventDispatcher;

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillResignActive:)
                                                     name:UIApplicationWillResignActiveNotification
                                                   object:nil];

        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(applicationWillEnterForeground:)
                                                     name:UIApplicationWillEnterForegroundNotification
                                                   object:nil];
        

    }

    return self;
}

- (void)applicationWillResignActive:(NSNotification *)notification
{
  
    if (!_paused) {
        [self setPaused:_paused];
    }
}

- (void)applicationWillEnterForeground:(NSNotification *)notification
{
    [self applyModifiers];
}

- (void)applyModifiers
{
    if(!_paused)
        [self play];
}

- (void)setPaused:(BOOL)paused
{
    if(_player){
        if(!paused){
            [self play];
        }else {
            [_player pause];
            _paused =  YES;
            _started = NO;
        }
    }
}

-(void)play
{
    if(_player){
        [_player play];
        _paused = NO;
        _started = YES;
    }
}

-(void)setResume:(BOOL)autoplay
{
    @try{
        char * videoRatio = nil;
        if(_player){
            videoRatio = _player.videoAspectRatio;
            [_player stop];
            _player = nil;
        }
        NSMutableDictionary* mediaOptions = [_source objectForKey:@"mediaOptions"];
        NSArray* options = [_source objectForKey:@"initOptions"];
        NSString* uri    = [_source objectForKey:@"uri"];
        NSInteger initType = [RCTConvert NSInteger:[_source objectForKey:@"initType"]];
        BOOL autoplay = [RCTConvert BOOL:[_source objectForKey:@"autoplay"]];
        BOOL isNetWork   = [RCTConvert BOOL:[_source objectForKey:@"isNetwork"]];
        NSURL* _uri    = [NSURL URLWithString:uri];
        if(uri && uri.length > 0){
            // init player && play
            if(initType == 2){
                _player = [[VLCMediaPlayer alloc] initWithOptions:options];
            }else{
                _player = [[VLCMediaPlayer alloc] init];
            }
            [_player setDrawable:self];
            _player.delegate = self;
            _player.scaleFactor = 0;
            //设置缓存多少毫秒
            // [mediaDictonary setObject:@"1500" forKey:@"network-caching"];
            VLCMedia *media = nil;
            if(isNetWork){
                media = [VLCMedia mediaWithURL:_uri];
            }else{
                media = [VLCMedia mediaWithPath: uri];
            }
            media.delegate = self;
            if(mediaOptions){
                [media addOptions:mediaOptions];
            }
            /*if(videoRatio){
                _player.videoAspectRatio = videoRatio;
            }*/
            [media parseWithOptions:VLCMediaParseLocal|VLCMediaFetchLocal|VLCMediaParseNetwork|VLCMediaFetchNetwork];
            _player.media = media;
            if(autoplay)
                [self play];
            if(self.onVideoLoadStart){
                self.onVideoLoadStart(@{
                                        @"target": self.reactTag
                                        });
            }
        }
    }
    @catch(NSException *exception){
        NSLog(@"%@", exception);
    }
}

-(void)setSource:(NSDictionary *)source
{
    @try{
        if(_player){
            [_player stop];
            _player = nil;
        }
        _source = source;
        NSMutableDictionary* mediaOptions = [source objectForKey:@"mediaOptions"];
        NSArray* options = [source objectForKey:@"initOptions"];
        NSString* uri    = [source objectForKey:@"uri"];
        NSInteger initType = [RCTConvert NSInteger:[source objectForKey:@"initType"]];
        BOOL autoplay = [RCTConvert BOOL:[source objectForKey:@"autoplay"]];
        BOOL isNetWork   = [RCTConvert BOOL:[source objectForKey:@"isNetwork"]];
        NSURL* _uri    = [NSURL URLWithString:uri];
        if(uri && uri.length > 0){
            // init player && play
            if(initType == 2){
                _player = [[VLCMediaPlayer alloc] initWithOptions:options];
            }else{
                _player = [[VLCMediaPlayer alloc] init];
            }
            [_player setDrawable:self];
            _player.delegate = self;
            _player.scaleFactor = 0;
            //设置缓存多少毫秒
            // [mediaDictonary setObject:@"1500" forKey:@"network-caching"];
            VLCMedia *media = nil;
            if(isNetWork){
                media = [VLCMedia mediaWithURL:_uri];
            }else{
                media = [VLCMedia mediaWithPath: uri];
            }
            if(media){
                media.delegate = self;
                if(mediaOptions){
                    [media addOptions:mediaOptions];
                }
                [media parseWithOptions:VLCMediaParseLocal|VLCMediaFetchLocal|VLCMediaParseNetwork|VLCMediaFetchNetwork];
                 _player.media = media;
            }
            if(autoplay)
                [self play];
            if(self.onVideoLoadStart){
                self.onVideoLoadStart(@{
                                       @"target": self.reactTag
                                     });
            }
        }
    }
    @catch(NSException *exception){
          NSLog(@"%@", exception);
    }
}

- (void)mediaPlayerTimeChanged:(NSNotification *)aNotification
{
    [self updateVideoProgress];
}

- (void)onVideoTracks {
    if(_player){
        NSArray *tracksNames = [_player audioTrackNames];
        NSArray *tracksIndexes = [_player audioTrackIndexes];
        int currentTrackIndex = [_player currentAudioTrackIndex];
        
        self.onVideoAudioTracks(@{
            @"target": self.reactTag,
            @"trackNames": tracksNames,
            @"trackIndexes": tracksIndexes,
            @"currentTrackIndex":[NSNumber numberWithInt:currentTrackIndex]
                                });
    }
}

- (void)onSubtitles {
    if(_player){
        NSArray *subtitleNames = [_player videoSubTitlesNames];
        NSArray *subtitleIndexes = [_player videoSubTitlesIndexes];
        int currentSubtitleIndex = [_player currentVideoSubTitleIndex];
        
        self.onVideoSubtitles(@{
            @"target": self.reactTag,
            @"subtitleNames": subtitleNames,
            @"subtitleIndexes": subtitleIndexes,
            @"currentSubtitleIndex":[NSNumber numberWithInt:currentSubtitleIndex]
                                });
    }
}

- (void)mediaPlayerStateChanged:(NSNotification *)aNotification
{

    if(_player){
        BOOL isPlaying = _player.isPlaying;

        VLCMediaPlayerState state = _player.state;
        switch (state) {
            case VLCMediaPlayerStateOpening:
                self.onVideoOpen(@{
                                     @"target": self.reactTag
                                     });
                break;
            case VLCMediaPlayerStatePaused:
                _paused = YES;
                self.onVideoPaused(@{
                                     @"target": self.reactTag
                                     });
                break;
            case VLCMediaPlayerStateStopped:

                self.onVideoStopped(@{
                                      @"target": self.reactTag
                                      });
                break;
            case VLCMediaPlayerStateBuffering:
                self.onVideoBuffering(@{
                                        @"target": self.reactTag,
                                        @"isPlaying": [NSNumber numberWithBool: isPlaying]
                                        });
                [self onVideoTracks];
                [self onSubtitles];
                break;
            case VLCMediaPlayerStatePlaying:
                _paused = NO;
                self.onVideoPlaying(@{
                                      @"target": self.reactTag,
                                      @"seekable": [NSNumber numberWithBool:[_player isSeekable]],
                                      @"duration":[NSNumber numberWithInt:[_player.media.length intValue]]
                                      });
                break;
            case VLCMediaPlayerStateEnded:
                self.onVideoEnded(@{
                                    @"target": self.reactTag,
                                    });
                break;
            case VLCMediaPlayerStateError:
                self.onVideoError(@{
                                    @"target": self.reactTag
                                    });
                [self _release];
                break;
            default:
                break;
        }
    }
}

-(void)updateVideoProgress
{
    if(_player){
        int currentTime   = [[_player time] intValue];
        int remainingTime = [[_player remainingTime] intValue];
        int duration      = [_player.media.length intValue];

        if(duration == 0) {
            duration = -remainingTime;
        }


        if( currentTime >= 0 && currentTime < duration) {
            self.onVideoProgress(@{
                                   @"target": self.reactTag,
                                   @"currentTime": [NSNumber numberWithInt:currentTime],
                                   @"remainingTime": [NSNumber numberWithInt:remainingTime],
                                   @"duration":[NSNumber numberWithInt:duration],
                                   @"position":[NSNumber numberWithFloat:_player.position]
                                   });
        }
    }
}

- (void)jumpBackward:(int)interval
{
    if(interval>=0 && interval <= [_player.media.length intValue])
        [_player jumpBackward:interval];
}

- (void)jumpForward:(int)interval
{
    if(interval>=0 && interval <= [_player.media.length intValue])
        [_player jumpForward:interval];
}

-(void)setSeek:(float)pos
{
    if([_player isSeekable]){
        if(pos>=0 && pos <= 1){
            [_player setPosition:pos];
        }
    }
}

-(void)setSnapshotPath:(NSString*)path
{
    if(_player)
        [_player saveVideoSnapshotAt:path withWidth:0 andHeight:0];
}

-(void)setRate:(float)rate
{
    [_player setRate:rate];
}

-(void)setVideoAspectRatio:(NSString *)ratio{
    char *char_content = [ratio cStringUsingEncoding:NSASCIIStringEncoding];
    [_player setVideoAspectRatio:char_content];
}

- (void)setMuted:(BOOL)value
{
    if (_player) {
        [[_player audio] setMuted:value];
    }
}

- (void)setCurrentAudioTrackIndex:(NSInteger*)index
{
    if(_player){
        [_player setCurrentAudioTrackIndex:index];
    }
}

- (void)setCurrentVideoSubTitleIndex:(NSInteger*)index
{
    if(_player){
        [_player setCurrentVideoSubTitleIndex:index];
    }
}

- (void)_release
{
    if(_player){
        [_player pause];
        [_player stop];
        _player = nil;
        _eventDispatcher = nil;
        [[NSNotificationCenter defaultCenter] removeObserver:self];
    }
}

#pragma mark - Lifecycle
- (void)removeFromSuperview
{
    [self _release];
    [super removeFromSuperview];
}

@end
