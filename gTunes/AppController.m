//
//  AppController.m
//  gTunes
//
//  Created by koji on 2014/09/24.
//  Copyright (c) 2014年 koji. All rights reserved.
//

#import <CoreFoundation/CoreFoundation.h>
#import "AppController.h"
#import "LoopbackSide.h"

@implementation AppController

- (id)init
{
    self = [super init];
    return self;
}

-(void)awakeFromNib
{
    [self loadiTunes:nil];
    
	loopStartTime = 0.0f;
	loopEndTime = -1.0f;
    prevPlaybackPosition = -1.0f;

    loopback = [[LoopbackSide alloc] init];
    [loopback initialize];
    [loopback startInput];
    [loopback startOutput];
    
    [self clearLoopEnd:self];
    
    
	timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(ontimer:) userInfo:nil repeats:YES];
	
	//allow timer event to be fired even on moving position slider
	//http://objective-audio.jp/2008/04/post-6.html
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSEventTrackingRunLoopMode];
    
    ////http://d.hatena.ne.jp/zariganitosh/20120918/notification_driven_applescript
    //listen any distribution from any app.
//    NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
//    [nc addObserver:self selector:@selector(onAnyNotification:) name:nil object:nil];
    
    

}

- (void)windowWillClose:(NSNotification *)aNotification{
    if(iTunesApp){
        if (iTunesApp.playerState != iTunesEPlSPlaying){
            //[iTunesApp playpause];
        }
    }

}

-(void)onAnyNotification:(NSNotification *)notification
{
    //ignore some messy notification
    if (NSOrderedSame == [notification.name compare:@"com.apple.Carbon.TISNotifySelectedKeyboardInputSourceChanged"]){
        return;
    }
    if (NSOrderedSame ==[notification.name compare:@"AppleSelectedInputSourcesChangedNotification"]){
        return;
    }
    
//    NSLog(@"[%@] -- %@",notification.name, notification.object);
//    NSLog(@"%@",notification.userInfo);
}

-(IBAction)loadiTunes:(id)sender
{
    iTunesApp = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    if ([iTunesApp isRunning]){

    }else{
        [iTunesApp run];
    }
    
    //iTunes throw some Disributed Notification.
    //http://stackoverflow.com/questions/9743699/observing-distributed-objects-in-cocoa
    
    NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(iTunesUpdated:)
               name:@"com.apple.iTunes.playerInfo"
             object:nil];
    
    //tracking song name etc. changes.
    [nc addObserver:self
           selector:@selector(iTunesUpdated:)
               name:@"com.apple.iTunes.sourceSaved"
             object:nil];

}

-(IBAction)loadSpotify:(id)sender
{
    spotifyApp = [SBApplication applicationWithBundleIdentifier:@"com.spotify.client"];
    if ([spotifyApp isRunning]){
        NSLog(@"Spotify already runnning");
    }else{
        [spotifyApp playpause];
    }
    
    //https://gist.github.com/kwylez/5337918
//    NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
//    [nc addObserver:self
//           selector:@selector(spotifyUpdated:)
//               name:@"com.spotify.client.PlaybackStateChanged"
//             object:nil];
}

-(void)iTunesUpdated:(NSNotification *)notification
{
    //NSLog(@"iTunes status updated");
    //NSLog(@"%@", notification);
    [self updateStatus];
}


-(void)updateStatus
{
	if([iTunesApp playerState] == iTunesEPlSPlaying){
		[btnPlayPause setTitle:@"Pause"];
	}else{
		[btnPlayPause setTitle:@"Play"];
	}
	
    iTunesTrack *currentTrack = [iTunesApp currentTrack];
	if (!currentTrack){
		return;
	}
	if (currentTrack.artist){
		[lblArtist setStringValue:[currentTrack artist]];
	}
	if (currentTrack.name){
		[lblTitle setStringValue:[currentTrack name]];
	}

    
    //somehow we should call "get"
    //http://www.cocoabuilder.com/archive/cocoa/200195-problems-with-scriptingbridge-and-itunes.html
    iTunesTrack *track = [currentTrack get];
    if ([[track className] isEqualToString:@"iTunesFileTrack"]){
        NSLog(@"fileTrack : %@", ((iTunesFileTrack *)track).location);
    }
    
}

-(void)ontimer:(NSTimer *)t
{
    Boolean seekbyme = seekedBySelf;
    seekedBySelf = NO;
	static bool firstcall = true;
	if (firstcall){
		[self updateStatus];
		firstcall = false;
		
		//without this, gTunes goes background if launched from iTunes Script menu.
		//should be in applicationDidFinishLaunching?
		[NSApp activateIgnoringOtherApps:YES];
		[window makeKeyAndOrderFront:nil];
        
        if(iTunesApp.playerState == iTunesEPlSPlaying){
            [loopback startNewRecord:iTunesApp.playerPosition];
        }
	}

    iTunesTrack *currentTrack = [iTunesApp currentTrack];
    double cursec = [iTunesApp playerPosition];	//not updated in msec...
    double totalsec = [currentTrack duration];
    
    if(switched){
        cursec = [loopback currentPlayPosition];
        if ([loopback isOverflowPlaying]){
            switched = NO;
            [loopback stopPlay];
            [iTunesApp setPlayerPosition:cursec];
            [iTunesApp playpause];
            [loopback startNewRecord:iTunesApp.playerPosition];
            [lblSelfMode setStringValue:@"iTunes"];
            [sliderPlaybackRate setDoubleValue:1.0];
            [sliderPlaybackRate setEnabled:NO];
            [lblPlaybackRate setStringValue:@"x1.00"];
        }
    }else{
        if([loopback canStartPlayFrom:cursec]){
            [sliderPlaybackRate setEnabled:YES];
        }else{
            [sliderPlaybackRate setEnabled:NO];
        }
    }
	
	NSString *positionText = [NSString stringWithFormat:@"%.2d:%.2d/%.2d:%.2d",
				(int)cursec/60, ((int)cursec) % 60,
				(int)totalsec/60, ((int)totalsec) % 60];
	[lblPosition setStringValue:positionText];
	
	if (![[sliderPosition cell] mouseDownFlags]){
		//NSLog(@"mouse upped");
        //NSLog(@".");
        
		[sliderPosition setDoubleValue:cursec/totalsec];
		
		//Loop
		if (chkLoop.state == NSOnState){
			if (loopStartTime >= 0.0f && loopEndTime > 0.0f){
				if (cursec > loopEndTime){
                    if(switched){
                        [loopback seekTo:loopStartTime];
                        seekedBySelf = YES;
                    }else{
                        [loopback stopRecord];
                        [iTunesApp setPlayerPosition:loopStartTime];
                        [loopback startNewRecord:iTunesApp.playerPosition];
                        seekedBySelf = YES;
                    }
                    [sliderPosition setDoubleValue:loopStartTime/totalsec];
                    return;
				}
			}
		}
	}else{
        NSLog(@"^");
	}
	
	//TODO cancel sliderChanged fired on mouse up of position slider
    
    //detect seek by iTunes or other app
    if (prevPlaybackPosition < 0.0f){
        prevPlaybackPosition = cursec;
    }else{
        double delta = cursec - prevPlaybackPosition;
        if (fabs(delta) < 0.001){
            //not playing
        }else{
            if ((delta > 0.001) & (delta < 0.4)){
                prevPlaybackPosition = cursec;
            }else{
                if (!seekbyme){
                    NSLog(@"outside seek detected. delta = %f", delta);
                }
                prevPlaybackPosition = cursec;
            }
        }
    }
    
}


-(IBAction)sliderChanged:(id)sender
{
	double posRatio = [sliderPosition doubleValue];
	double totalsec = iTunesApp.currentTrack.duration;
    
    if(switched){
        Boolean playing = [loopback isPlaying];
        if (![loopback seekTo:totalsec*posRatio]){
            //back to iTunes
            switched = NO;
            [lblSelfMode setStringValue:@"iTunes"];
            [sliderPlaybackRate setDoubleValue:1.0];
            [sliderPlaybackRate setEnabled:NO];
            [lblPlaybackRate setStringValue:@"x1.00"];
            [iTunesApp setPlayerPosition:totalsec*posRatio];
            seekedBySelf = YES;
            if (playing){
                [iTunesApp playpause];
                [loopback startNewRecord:iTunesApp.playerPosition];
            }
        }else{
            seekedBySelf = YES;
        }
        
    }else{
        [loopback stopRecord];
        [iTunesApp setPlayerPosition:totalsec*posRatio];
        seekedBySelf = YES;
        if (iTunesApp.playerState == iTunesEPlSPlaying){
            [loopback startNewRecord:[iTunesApp playerPosition]];
        }
    }
    
    NSLog(@"position changed(slider changed)");
}

-(IBAction)playPause:(id)sender
{
    
    if (switched){
        if ([loopback isPlaying]){
            [loopback stopPlay];
            [btnPlayPause setTitle:@"Play"];
        }else{
            [loopback startPlayFrom:[loopback startPlay]];
            [btnPlayPause setTitle:@"Pause"];
        }
    }else{
        if (iTunesApp.playerState == iTunesEPlSPlaying){
            [loopback stopRecord];
            [iTunesApp pause];
            [btnPlayPause setTitle:@"Play"];
        }else{
            [iTunesApp playpause];
            [loopback startNewRecord:iTunesApp.playerPosition];
            [btnPlayPause setTitle:@"Pause"];
        }
    }
}



-(NSString *)formatSec:(double)sec
{
	NSString *ret = [NSString stringWithFormat:@"%.2d:%.2d:%.3d",
						(int)sec/60,
						((int)sec)%60,
						(int)((sec-(int)(sec))*1000)];
	return ret;
}

- (IBAction)fastForward:(id)sender {
    
    if(switched){
        Boolean playing = [loopback isPlaying];
        double cursec = [loopback currentPlayPosition];
        if (![loopback seekTo:cursec + 3.0]){
            //back to iTunes
            switched = NO;
            [lblSelfMode setStringValue:@"iTunes"];
            [sliderPlaybackRate setDoubleValue:1.0];
            [sliderPlaybackRate setEnabled:NO];
            [lblPlaybackRate setStringValue:@"x1.00"];
            [iTunesApp setPlayerPosition:cursec + 3.0];
            seekedBySelf = YES;
            if (playing){
                [iTunesApp playpause];
                [loopback startNewRecord:iTunesApp.playerPosition];
            }
            double totalsec = iTunesApp.currentTrack.duration;
            cursec = iTunesApp.playerPosition;
            [sliderPosition setDoubleValue:cursec/totalsec];
            seekedBySelf = YES;
        }else{
            double totalsec = iTunesApp.currentTrack.duration;
            cursec = [loopback currentPlayPosition];
            [sliderPosition setDoubleValue:cursec/totalsec];
            seekedBySelf = YES;
        }
        
    }else{
        [loopback stopRecord];
        [iTunesApp setPlayerPosition:iTunesApp.playerPosition+3.0];
        seekedBySelf = YES;
        if (iTunesApp.playerState == iTunesEPlSPlaying){
            [loopback startNewRecord:[iTunesApp playerPosition]];
        }
        double cursec = iTunesApp.playerPosition;
        double totalsec = iTunesApp.currentTrack.duration;
        [sliderPosition setDoubleValue:cursec/totalsec];
    }
    
}

- (IBAction)rewind:(id)sender {
    if(switched){
        Boolean playing = [loopback isPlaying];
        double cursec = [loopback currentPlayPosition];
        if (![loopback seekTo:cursec - 3.0]){
            //back to iTunes
            switched = NO;
            [lblSelfMode setStringValue:@"iTunes"];
            [sliderPlaybackRate setDoubleValue:1.0];
            [sliderPlaybackRate setEnabled:NO];
            [lblPlaybackRate setStringValue:@"x1.00"];
            [iTunesApp setPlayerPosition:cursec - 3.0];
            seekedBySelf = YES;
            [iTunesApp playpause];
            [loopback startNewRecord:iTunesApp.playerPosition];
            if (playing){
                [iTunesApp playpause];
                [loopback startNewRecord:iTunesApp.playerPosition];
            }
            double totalsec = iTunesApp.currentTrack.duration;
            cursec = iTunesApp.playerPosition;
            [sliderPosition setDoubleValue:cursec/totalsec];
            seekedBySelf = YES;
        }else{
            double totalsec = iTunesApp.currentTrack.duration;
            cursec = [loopback currentPlayPosition];
            [sliderPosition setDoubleValue:cursec/totalsec];
            seekedBySelf = YES;
        }
        
    }else{
        [loopback stopRecord];
        [iTunesApp setPlayerPosition:iTunesApp.playerPosition-3.0];
        seekedBySelf = YES;
        if (iTunesApp.playerState == iTunesEPlSPlaying){
            [loopback startNewRecord:[iTunesApp playerPosition]];
        }
        double cursec = iTunesApp.playerPosition;
        double totalsec = iTunesApp.currentTrack.duration;
        [sliderPosition setDoubleValue:cursec/totalsec];
    }
    
   
}

-(IBAction)setLoopStartAsNow:(id)sender{
    if (switched){
        loopStartTime = [loopback currentPlayPosition];
    }else{
        loopStartTime = iTunesApp.playerPosition;
    }
	[lblLoopStartTime setStringValue:[self formatSec:loopStartTime]];
	
}
- (IBAction)backLoopStart:(id)sender {
    if (loopStartTime - 1.0 > 0.0){
        loopStartTime -= 1.0;
    }else{
        loopStartTime = 0.0;
    }
    [lblLoopStartTime setStringValue:[self formatSec:loopStartTime]];
    
}
- (IBAction)backLoopStartLittle:(id)sender {
    if (loopStartTime - 0.2 > 0.0){
        loopStartTime -= 0.2;
    }else{
        loopStartTime = 0.0;
    }
    [lblLoopStartTime setStringValue:[self formatSec:loopStartTime]];
}
- (IBAction)forwardLoopStart:(id)sender {
    loopStartTime += 1.0;
    [lblLoopStartTime setStringValue:[self formatSec:loopStartTime]];
}

- (IBAction)forwardLoopStartLittle:(id)sender {
    loopStartTime += 0.2;
    [lblLoopStartTime setStringValue:[self formatSec:loopStartTime]];
}

-(IBAction)setLoopEndAsNow:(id)sender {
    if (switched){
        loopEndTime = [loopback currentPlayPosition];
    }else{
        loopEndTime = iTunesApp.playerPosition;
    }
	[lblLoopEndTime setStringValue:[self formatSec:loopEndTime]];
}

- (IBAction)backLoopEnd:(id)sender {
    if (loopEndTime - 1.0 > 0.0){
        loopEndTime -= 1.0;
    }else{
        loopEndTime = 0.0;
    }
    [lblLoopEndTime setStringValue:[self formatSec:loopEndTime]];
    
}
- (IBAction)backLoopEndLittle:(id)sender {
    if (loopEndTime - 0.2 > 0.0){
        loopEndTime -= 0.2;
    }else{
        loopEndTime = 0.0;
    }
    [lblLoopEndTime setStringValue:[self formatSec:loopEndTime]];
}
- (IBAction)forwardLoopEnd:(id)sender {
    loopEndTime += 1.0;
    [lblLoopEndTime setStringValue:[self formatSec:loopEndTime]];
}

- (IBAction)forwardLoopEndStartLittle:(id)sender {
    loopEndTime += 0.2;
    [lblLoopEndTime setStringValue:[self formatSec:loopEndTime]];
}

- (IBAction)Bpressed:(id)sender {
    [btnGotoStart performClick:sender];
}

-(IBAction)goToLoopStart:(id)sender{

    if (switched){
        [loopback startPlayFrom:loopStartTime];
        seekedBySelf = YES;
    }else{
        [loopback stopRecord];
        [iTunesApp setPlayerPosition:loopStartTime];
        [loopback startNewRecord:iTunesApp.playerPosition];
        seekedBySelf = YES;
        
        //start play if paused
        if([iTunesApp playerState] != iTunesEPlSPlaying){
            [iTunesApp playpause];
        }
    }
    
    iTunesTrack *currentTrack = [iTunesApp currentTrack];
    double totalsec = [currentTrack duration];
    
    [sliderPosition setDoubleValue:loopStartTime/totalsec];
    
    seekedBySelf = YES;
    
}

-(IBAction)clearLoopEnd:(id)sender{
    loopEndTime = -1.0f;
    [lblLoopEndTime setStringValue:@"--:--:--"];
}


- (IBAction)sliderPlaybackRateChanged:(id)sender {

    double rate = [sliderPlaybackRate doubleValue];
    
    Boolean rate_is_1 = NO;
    //snap to 1.0
    if ((0.96 <= rate) & (rate <= 1.04)){
        rate_is_1 = YES;
        rate = 1.0f;
        [sliderPlaybackRate setDoubleValue:rate];
    }
    
    if (switched){
        [lblPlaybackRate setStringValue:[NSString stringWithFormat:@"x%.02f", rate]];
        [loopback setPlaybackRate:rate];
    }else{
        if (!rate_is_1){
            double cursec = iTunesApp.playerPosition;
            if ([loopback canStartPlayFrom:cursec]){
                [loopback stopRecord];
                switched = YES;
                [lblSelfMode setStringValue:@"self mode"];
                [iTunesApp pause];
                [loopback setPlaybackRate:rate];
                [loopback startPlayFrom:cursec];
                
                [lblPlaybackRate setStringValue:[NSString stringWithFormat:@"x%.02f", rate]];
            }else{
                [sliderPlaybackRate setDoubleValue:1.0];
            }
        }
        
    }

}

- (IBAction)onCompanion:(id)sender {


}


- (IBAction)onBypassChanged:(id)sender {
    if ([chkBypass state] == NSOnState){
        [loopback setBypass:YES];
    }else{
        [loopback setBypass:NO];
    }
}

- (IBAction)onDumpClicked:(id)sender {
    [loopback dumpFragments];
}

@end
