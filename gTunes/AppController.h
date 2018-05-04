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
#import "Spotify.h"
#import "LoopbackSide.h"
#import "CompTableViewController.h"
#import "ThroughSide.h"
#import "MusicApplication.h"

@interface AppController : NSObject
{

    id<MusicApplication> musicApp;
    
    LoopbackSide *loopback;
    ThroughSide *through;
    __weak IBOutlet NSTextField *lblArtist;
    __weak IBOutlet NSTextField *lblTitle;
    __weak IBOutlet NSButton *btnPlayPause;
    __weak IBOutlet NSSlider *sliderPosition;
	__weak IBOutlet NSTextField *lblPosition;
	NSTimer *timer;
	__weak IBOutlet NSButton *chkLoop;
	__weak IBOutlet NSTextField *lblLoopStartTime;
	__weak IBOutlet NSTextField *lblLoopEndTime;
    __weak IBOutlet NSButton *btnGotoStart;
    __weak IBOutlet NSImageView *imageArtwork;
	double loopStartTime;
	double loopEndTime;
	IBOutlet NSWindow *window;
    __weak IBOutlet NSTextField *lblPlaybackRate;
    __weak IBOutlet NSSlider *sliderPlaybackRate;
    Boolean switched;
    __weak IBOutlet NSTextField *lblSelfMode;
    __weak IBOutlet NSButton *chkBypass;
    __weak IBOutlet NSMenuItem *menuFlipLR;
    
    __weak IBOutlet NSMenuItem *menuRevealInFinder;
    __weak IBOutlet NSTableView *compTableView;
    CompTableViewController *compTableDataSource;
    Boolean seekedBySelf;
    
    
    double prevPlaybackPosition;
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

- (IBAction)forwardLoopStart:(id)sender;
- (IBAction)forwardLoopStartLittle:(id)sender;
- (IBAction)backLoopStart:(id)sender;
- (IBAction)backLoopStartLittle:(id)sender;


- (IBAction)goToLoopStart:(id)sender;

- (void)notifyDD:(NSURL *)fileURL;

@end
