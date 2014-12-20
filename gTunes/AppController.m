//
//  AppController.m
//  gTunes
//
//  Created by koji on 2014/09/24.
//  Copyright (c) 2014年 koji. All rights reserved.
//

#import "AppController.h"

@implementation AppController

- (id)init
{
    self = [super init];
    return self;
}

-(void)awakeFromNib
{
    [self loadiTunes:nil];
    //[self updateStatus]; postpone
	
	loopStartTime = -1.0f;
	loopEndTime = -1.0f;
	
	timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:self selector:@selector(ontimer:) userInfo:nil repeats:YES];
	
	//allow timer event to be fired even on moving position slider
	//http://objective-audio.jp/2008/04/post-6.html
	[[NSRunLoop currentRunLoop] addTimer:timer forMode:NSEventTrackingRunLoopMode];
}

-(IBAction)loadiTunes:(id)sender
{
    iTunesApp = [SBApplication applicationWithBundleIdentifier:@"com.apple.iTunes"];
    if ([iTunesApp isRunning]){
        NSLog(@"iTunes running");
    }else{
        NSLog(@"iTunes not running so starting...");
        [iTunesApp run];
    }
    
    //iTunes throw some Disributed Notification.
    //http://stackoverflow.com/questions/9743699/observing-distributed-objects-in-cocoa
    
    NSDistributedNotificationCenter *nc = [NSDistributedNotificationCenter defaultCenter];
    [nc addObserver:self
           selector:@selector(iTunesUpdated:)
               name:@"com.apple.iTunes.playerInfo"
             object:nil];

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
    iTunesFileTrack *fileTrack = (iTunesFileTrack *)[currentTrack get];
    NSLog(@"%@", fileTrack.location);
    

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
	//NSLog(@"cursec = %f", cursec);
	
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
					[iTunesApp setPlayerPosition:loopStartTime];
				}
			}
		}
	}else{
		//NSLog(@"timer on slider moving");
	}
	
	//TODO cancel sliderChanged fired on mouse up of position slider
	
}


-(IBAction)sliderChanged:(id)sender
{
	double posRatio = [sliderPosition doubleValue];
	double totalsec = iTunesApp.currentTrack.duration;
	[iTunesApp setPlayerPosition:totalsec*posRatio];
}

-(IBAction)playPause:(id)sender
{
    [iTunesApp playpause];
}

-(void)iTunesUpdated:(NSNotification *)notification
{
    NSLog(@"iTunes status updated");
    NSLog(@"%@", notification);
	[self updateStatus];
}

-(NSString *)formatSec:(double)sec
{
	NSString *ret = [NSString stringWithFormat:@"%.2d:%.2d:%.3d",
						(int)sec/60,
						((int)sec)%60,
						(int)((sec-(int)(sec))*1000)];
	return ret;
}

-(IBAction)setLoopStartAsNow:(id)sender{
	loopStartTime = iTunesApp.playerPosition;
	[lblLoopStartTime setStringValue:[self formatSec:loopStartTime]];
	
}

-(IBAction)setLoopEndAsNow:(id)sender {
	loopEndTime = iTunesApp.playerPosition;
	[lblLoopEndTime setStringValue:[self formatSec:loopEndTime]];
}

-(IBAction)goToLoopStart:(id)sender{
	[iTunesApp setPlayerPosition:loopStartTime];
}

-(IBAction)goToLoopEnd:(id)sender{
	[iTunesApp setPlayerPosition:loopEndTime];
}


@end
