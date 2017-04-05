//
//  LoopbackSide.h
//  gTunes
//
//  Created by koji on 2017/04/02.
//  Copyright © 2017年 koji. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>


#define FRAGMENT_FRAME_LEN 44100*60*10      //10 minutes

typedef struct RecordFragment{
    float leftBuf[FRAGMENT_FRAME_LEN];
    float rightBuf[FRAGMENT_FRAME_LEN];
    float startSecInSong;
    float endSecInSong;
    UInt32 storedFrameLen;
    UInt32 playedFrameLen;
}RecordFragment;

@interface LoopbackSide : NSObject {
    AUGraph _graph;
    AudioUnit _outUnit;
    AudioUnit _converterUnit;
    AudioUnit _newTimePitchUnit;
    AudioUnit _inputUnit;
    
    RecordFragment *_fragments;
    UInt32 _numFragments;
    Boolean _recording;
    Boolean _playing;
}

- (Boolean)startNewRecord:(float)startSec;
- (Boolean)stopRecord:(float)endSec;
- (Boolean)startPlayFrom:(float)sec;
- (Boolean)stopPlay;
- (Boolean)seekToPosition:(float)sec;
- (Boolean)setPlaybackRate:(float)rate;
- (Boolean)initialize;
- (Boolean)startInput;
- (Boolean)startOutput;
- (float)currentPlayPosition;

@end
