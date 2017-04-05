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
	
	loopStartTime = -1.0f;
	loopEndTime = -1.0f;
	
	timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(ontimer:) userInfo:nil repeats:YES];
	
	//allow timer event to be fired even on moving position slider
	//http://objective-audio.jp/2008/04/post-6.html
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSEventTrackingRunLoopMode];
    
    ////http://d.hatena.ne.jp/zariganitosh/20120918/notification_driven_applescript
    //look any distribution
//    NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
//    [nc addObserver:self selector:@selector(onAnyNotification:) name:nil object:nil];
    
    
    loopback = [[LoopbackSide alloc] init];
    [loopback initialize];
    [loopback startInput];
    [loopback startOutput];
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

    //http://d.hatena.ne.jp/zariganitosh/20120918/notification_driven_applescript
}

-(void)iTunesUpdated:(NSNotification *)notification
{
    NSLog(@"iTunes status updated");
    //NSLog(@"%@", notification);
    [self updateStatus];
}

-(void)updateStatus
{
	if([iTunesApp playerState] == iTunesEPlSPlaying){
        [self onStopRecord:self];
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
    
//    //Show artwork (maybe not required)
//    SBElementArray *artworks = [currentTrack artworks];
//    if (artworks && artworks.count != 0){
//        iTunesArtwork *artwork = [artworks objectAtIndex:0];
//        [imageArtwork setImage:artwork.data];
//    }else{
//        [imageArtwork setImage:nil];
//    }
    
}

-(void)ontimer:(NSTimer *)t
{
	static bool firstcall = true;
	if (firstcall){
		[self updateStatus];
		firstcall = false;
		
		//without this, gTunes goes background if launched from iTunes Script menu.
		//should be in applicationDidFinishLaunching?
		[NSApp activateIgnoringOtherApps:YES];
		[window makeKeyAndOrderFront:nil];
		
	}

	iTunesTrack *currentTrack = [iTunesApp currentTrack];
	double cursec = [iTunesApp playerPosition];	//not updated in msec...
	double totalsec = [currentTrack duration];
//	NSLog(@"cursec = %f", cursec);
    
    if(switched){
        cursec = [loopback currentPlayPosition];
    }
	
	NSString *positionText = [NSString stringWithFormat:@"%.2d:%.2d/%.2d:%.2d",
				(int)cursec/60, ((int)cursec) % 60,
				(int)totalsec/60, ((int)totalsec) % 60];
	[lblPosition setStringValue:positionText];
	
	if (![[sliderPosition cell] mouseDownFlags]){
		//NSLog(@"mouse upped");
		[sliderPosition setDoubleValue:cursec/totalsec];
		
		//Loop
		if (chkLoop.state == NSOnState){
			if (loopStartTime >= 0.0f && loopEndTime >= 1.0f){
				if (cursec > loopEndTime){
					NSLog(@"Loop back!!");
                    if(switched){
                        [loopback seekToPosition:loopStartTime];
                    }else{
                        [self onStopRecord:self];
                        [iTunesApp setPlayerPosition:loopStartTime];
                    }
				}
			}
		}
	}else{
	}
	
	//TODO cancel sliderChanged fired on mouse up of position slider
	
}


-(IBAction)sliderChanged:(id)sender
{
	double posRatio = [sliderPosition doubleValue];
	double totalsec = iTunesApp.currentTrack.duration;
	[iTunesApp setPlayerPosition:totalsec*posRatio];
    
    [self onStopRecord:self];
    
    NSLog(@"position changed(slider changed)");
}

-(IBAction)playPause:(id)sender
{
    [self onStopRecord:self];
    [iTunesApp playpause];
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
    
    double currentPosition = iTunesApp.playerPosition;
    [iTunesApp setPlayerPosition:currentPosition + 3.0];
    
    iTunesTrack *currentTrack = [iTunesApp currentTrack];
    double cursec = [iTunesApp playerPosition];
    double totalsec = [currentTrack duration];
    
    [sliderPosition setDoubleValue:cursec/totalsec];
    
    [self onStopRecord:self];
    
    NSLog(@"position changed(fast forward)");
    
}

- (IBAction)rewind:(id)sender {
    double currentPosition = iTunesApp.playerPosition;
    if (currentPosition - 3.0 > 0.0){
        [iTunesApp setPlayerPosition:currentPosition-3.0];
    }else{
        [iTunesApp setPlayerPosition:0.0];
    }

    iTunesTrack *currentTrack = [iTunesApp currentTrack];
    double cursec = [iTunesApp playerPosition];
    double totalsec = [currentTrack duration];
    
    [sliderPosition setDoubleValue:cursec/totalsec];
    
     [self onStopRecord:self];
    
    NSLog(@"position changed(rewind)");
    
}

-(IBAction)setLoopStartAsNow:(id)sender{
	loopStartTime = iTunesApp.playerPosition;
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
	loopEndTime = iTunesApp.playerPosition;
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
    [self onStopRecord:self];
	[iTunesApp setPlayerPosition:loopStartTime];
    if([iTunesApp playerState] != iTunesEPlSPlaying){
        [iTunesApp playpause];
    }
    
}

-(IBAction)clearLoopEnd:(id)sender{
    loopEndTime = -1.0f;
    [lblLoopEndTime setStringValue:@"10:00:00"];
}


- (IBAction)onStartRecord:(id)sender {
    double cursec = [iTunesApp playerPosition];	//not updated in msec...
    [loopback startNewRecord:(float)cursec];
    
}

- (IBAction)onStopRecord:(id)sender {
    double cursec = [iTunesApp playerPosition];	//not updated in msec...
    [loopback stopRecord:(float)cursec];
}

- (IBAction)onSwitch:(id)sender {
    if (switched == NO){
        switched = YES;
        [lblSelfMode setStringValue:@"self mode"];

        [loopback setPlaybackRate:[sliderPlaybackRate doubleValue]];
        
        [iTunesApp setMute:TRUE];
        [loopback startPlayFrom:[iTunesApp playerPosition]];
        
    }else{
        switched = NO;
        [lblSelfMode setStringValue:@"iTunes"];
        [loopback stopPlay];
        [iTunesApp setPlayerPosition:[loopback currentPlayPosition]];

        [iTunesApp setMute:FALSE];
    }
    
    
}

- (IBAction)sliderPlaybackRateChanged:(id)sender {

    double rate = [sliderPlaybackRate doubleValue];
    [lblPlaybackRate setStringValue:[NSString stringWithFormat:@"x%.02f", rate]];
    [loopback setPlaybackRate:rate];

}

@end
