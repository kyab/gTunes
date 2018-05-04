//
//  MusicApplication.h
//  gTunes
//
//  Created by kyab on 2018/05/04.
//  Copyright © 2018年 kyab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "iTunes.h"
#import "Spotify.h"

enum MusicAppEPLS {
    MusicAppEPLSStopped = 'kPSS',
    MusicAppEPLSPlaying = 'kPSP',
    MusicAppEPLSPaused = 'kPSp'
};
typedef enum MusicAppEPLS MusicAppEPLS;

@protocol MusicTrack <NSObject>
@property (copy, readonly, getter=getArtist) NSString *artist;
@property (copy, readonly, getter=getName) NSString *name;
@property (readonly, getter=getDuration) float duration;
@end

@protocol MusicApplication <NSObject>
@property (copy, readonly, getter=getCurrentTrack) id<MusicTrack> currentTrack;
@property (readonly, getter=getPlayerState) MusicAppEPLS playerState;
@property (getter=getPlayerPosition,setter=setPlayerPosition:) double playerPosition;
-(void) playpause;
-(void) pause;
-(BOOL) isRunning;

@end


//iTunes App
@interface MusicApplicationiTunes : NSObject <MusicApplication>{
    iTunesApplication *_iTunesApp;
}
@property (copy, readonly, getter=getCurrentTrack) id<MusicTrack> currentTrack;
@property (readonly, getter=getPlayerState) MusicAppEPLS playerState;
@property (getter=getPlayerPosition,setter=setPlayerPosition:) double playerPosition;
- (void) playpause;
- (void) pause;
-(BOOL) isRunning;
@end

//iTunes Track
@interface MusicTrackiTunes : NSObject <MusicTrack>{
    iTunesTrack *_iTunesTrack;
}
@property (copy, readonly, getter=getArtist) NSString *artist;
@property (copy, readonly, getter=getName) NSString *name;
@property (readonly, getter=getDuratoin) float duration;
-(void)setTrack:(iTunesTrack *)track;
@end

//Spotify App
@interface MusicApplicationSpotify : NSObject <MusicApplication>{
    SpotifyApplication *_spotifyApp;
}
@property (copy, readonly, getter=getCurrentTrack) id<MusicTrack> currentTrack;
@property (readonly, getter=getPlayerState) MusicAppEPLS playerState;
@property (getter=getPlayerPosition,setter=setPlayerPosition:)double playerPosition;
- (void) playpause;
- (void) pause;
-(BOOL) isRunning;
@end

//Spotify Track
@interface MusicTrackSpotify: NSObject <MusicTrack>{
    SpotifyTrack *_spotifyTrack;
}
@property (copy, readonly, getter=getArtist) NSString *artist;
@property (copy, readonly, getter=getName) NSString *name;
@property (readonly, getter=getDuratoin) float duration;
-(void)setTrack:(SpotifyTrack *)track;
@end




