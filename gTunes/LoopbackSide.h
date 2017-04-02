//
//  LoopbackSide.h
//  gTunes
//
//  Created by koji on 2017/04/02.
//  Copyright © 2017年 koji. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AudioToolbox/AudioToolbox.h>


@interface LoopbackSide : NSObject {
    AUGraph _graph;
    AudioUnit _outUnit;
    AudioUnit _converterUnit;
    AudioUnit _newTimePitchUnit;
    AudioUnit _inputUnit;
    
    
}

- (Boolean)initialize;
- (Boolean)startInput;

@end
