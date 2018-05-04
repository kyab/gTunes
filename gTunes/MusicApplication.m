//
//  MusicApplication.m
//  gTunes
//
//  Created by kyab on 2018/05/04.
//  Copyright © 2018年 kyab. All rights reserved.
//

#import "MusicApplication.h"

@implementation MusicApplicationiTunes
- (id)init
{
    self = [super init];
    _iTunesApp = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    return self;
}

-(id<MusicTrack>)getCurrentTrack{
    MusicTrackiTunes *ret = [[MusicTrackiTunes alloc ] init];
    [ret setTrack:_iTunesApp.currentTrack];
    
    return ret;
}

-(MusicAppEPLS)getPlayerState{
    return (MusicAppEPLS)_iTunesApp.playerState;
}

-(double)getPlayerPosition{
    return _iTunesApp.playerPosition;
}

-(void)setPlayerPosition:(double)position{
    _iTunesApp.playerPosition = position;
}

-(void)playpause{
    [_iTunesApp playpause];
}

-(void)pause{
    [_iTunesApp pause];
}

-(BOOL)isRunning{
    return [_iTunesApp isRunning];
}

@end

@implementation MusicApplicationSpotify
- (id)init
{
    self = [super init];
    _spotifyApp = [SBApplication applicationWithBundleIdentifier:@"com.spotify.client"];
    return self;
}

-(id<MusicTrack>)getCurrentTrack{
    MusicTrackSpotify *ret = [[MusicTrackSpotify alloc] init];
    [ret setTrack:_spotifyApp.currentTrack];
    return ret;
}
-(MusicAppEPLS)getPlayerState{
    return (MusicAppEPLS)_spotifyApp.playerState;
}

-(double)getPlayerPosition{
    return _spotifyApp.playerPosition;
}

-(void)setPlayerPosition:(double)position{
    _spotifyApp.playerPosition = position;
}

-(void)playpause{
    [_spotifyApp playpause];
}

-(void)pause{
    [_spotifyApp pause];
}

-(BOOL)isRunning{
    return [_spotifyApp isRunning];
}




@end



@implementation MusicTrackiTunes
-(NSString *)getArtist{
//    NSString *ret = @"Some Artist";
    NSString *ret = _iTunesTrack.artist;
    return ret;
}

-(NSString *)getName{
    NSString *ret = _iTunesTrack.name;
    return ret;
}

-(float)getDuration{
    return _iTunesTrack.duration;
}

-(void)setTrack:(iTunesTrack *) track{
    _iTunesTrack = track;
}


@end

@implementation MusicTrackSpotify
-(NSString *)getArtist{
    //    NSString *ret = @"Some Artist";
    NSString *ret = _spotifyTrack.artist;
    return ret;
}

-(NSString *)getName{
    NSString *ret = _spotifyTrack.name;
    return ret;
}

-(float)getDuration{
    return _spotifyTrack.duration / 1000.0;
}

-(void)setTrack:(SpotifyTrack *) track{
    _spotifyTrack = track;
}

@end
