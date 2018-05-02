//
//  ThroughSide.h
//  gTunes
//
//  Created by kyab on 2018/05/01.
//  Copyright © 2018年 kyab. All rights reserved.
//

//
//  AudioEngine.h
//  MyPlaythrough
//
//  Created by kyab on 2017/05/15.
//  Copyright © 2017年 kyab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "RingBuffer.h"

@protocol ThroughSideDelegate <NSObject>
@optional
- (OSStatus) outCallback:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData;

- (OSStatus) inCallback:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData;

@end


@interface ThroughSide : NSObject{
    AUGraph _graph;
    AudioUnit _outUnit;
    AudioUnit _converterUnit;
    
    AudioUnit _inputUnit;
    
    BOOL _bIsPlaying;
    BOOL _bIsRecording;
    
    RingBuffer *_ring;
    
    id<ThroughSideDelegate> _delegate;
    
    AudioDeviceID _preOutputDeviceID;
    
    
}

-(void)setRenderDelegate:(id<ThroughSideDelegate>)delegate;
-(BOOL)initialize;
-(BOOL)startThrough;

//system output
-(BOOL)changeSystemOutputDeviceToBGM;
-(BOOL)restoreSystemOutputDevice;

-(NSArray *)listDevices:(BOOL)output;
-(BOOL)changeInputDeviceTo:(NSString *)devName;

//called from delegate callback
- (OSStatus) readFromInput:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData;


@end
