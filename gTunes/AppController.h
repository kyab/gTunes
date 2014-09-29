//
//  AppController.h
//  gTunes
//
//  Created by koji on 2014/09/24.
//  Copyright (c) 2014年 koji. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "iTunes.h"

@interface AppController : NSObject
{

    iTunesApplication *iTunesApp;
    __weak IBOutlet NSTextField *lblArtist;
    __weak IBOutlet NSTextField *lblTitle;
    __weak IBOutlet NSButton *btnPlayPause;
    __weak IBOutlet NSSlider *sliderPosition;
	__weak IBOutlet NSTextField *lblPosition;
	NSTimer *timer;
	__weak IBOutlet NSButton *chkLoop;
	__weak IBOutlet NSTextField *lblLoopStartTime;
	__weak IBOutlet NSTextField *lblLoopEndTime;
	double loopStartTime;
	double loopEndTime;
	IBOutlet NSWindow *window;
}

- (IBAction)loadiTunes:(id)sender;
- (IBAction)playPause:(id)sender;
- (IBAction)sliderChanged:(id)sender;
- (void)iTunesUpdated:(NSNotification *)notification;
-(void)updateStatus;
-(void)awakeFromNib;
-(void)ontimer:(NSTimer *)t;

- (IBAction)setLoopStartAsNow:(id)sender;
- (IBAction)setLoopEndAsNow:(id)sender;

- (IBAction)goToLoopStart:(id)sender;
- (IBAction)goToLoopEnd:(id)sender;

@end
