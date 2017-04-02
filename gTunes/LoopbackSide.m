//
//  LoopbackSide.m
//  gTunes
//
//  Created by koji on 2017/04/02.
//  Copyright © 2017年 koji. All rights reserved.
//


#import "LoopbackSide.h"
#import <AudioToolbox/AudioToolbox.h>

@implementation LoopbackSide
- (id)init
{
    self = [super init];
    return self;
}


OSStatus MyRenderIn(void *inRefCon,
                    AudioUnitRenderActionFlags *ioActionFlags,
                    const AudioTimeStamp      *inTimeStamp,
                    UInt32 inBusNumber,
                    UInt32 inNumberFrames,
                    AudioBufferList *ioData){
    {
        static UInt32 count = 0;
        if ((count % 100) == 0){
            NSLog(@"LoopbackSide inputcallback inNumberFrames = %u", inNumberFrames);
        }
        count++;
    }
    
    LoopbackSide *loopback = (__bridge LoopbackSide *)inRefCon;
    return [loopback renderInput:ioActionFlags inTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:ioData];
    
}

- (OSStatus) renderInput:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData{
    

    return noErr;
    
}


- (Boolean)initialize{
    if (![self initializeInput]) return NO;
    return true;
}

-(Boolean)initializeInput{
    OSStatus ret = noErr;
    
    AudioComponent component;
    AudioComponentDescription cd;
    cd.componentType = kAudioUnitType_Output;
    cd.componentSubType = kAudioUnitSubType_HALOutput;
    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    component = AudioComponentFindNext(NULL, &cd);
    AudioComponentInstanceNew(component, &_inputUnit);
    ret = AudioUnitInitialize(_inputUnit);
    if (FAILED(ret)){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed to get input AU. err=%d(%@)", ret, [err description]);
        return NO;
    }
    
    if(![self setInputDevice]) return NO;
    if(![self setInputFormat]) return NO;
    if(![self setInputCallback]) return NO;
    
    NSLog(@"initializeInput success");
    return YES;
}

-(Boolean)startInput{
    OSStatus ret = AudioOutputUnitStart(_inputUnit);
    if (FAILED(ret)){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed to get start input. err=%d(%@)", ret, [err description]);
        return NO;
    }
    return YES;
}

- (Boolean)setInputDevice{
    OSStatus ret = noErr;
    
    //we should enable input and disable output at first.. shit! see TN2091.
    {
        UInt32 enableIO = 1;
        ret = AudioUnitSetProperty(_inputUnit,
                                   kAudioOutputUnitProperty_EnableIO,
                                   kAudioUnitScope_Input,
                                   1,   //input element
                                   &enableIO,
                                   sizeof(enableIO));
        if(FAILED(ret)){
            NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
            NSLog(@"Failed to kAudioOutputUnitProperty_EnableIO=%d(%@)", ret, [err description]);
            return NO;
        }
        
        enableIO = 0;
        ret = AudioUnitSetProperty(_inputUnit,
                                   kAudioOutputUnitProperty_EnableIO,
                                   kAudioUnitScope_Output,
                                   0,
                                   &enableIO,
                                   sizeof(enableIO));
        if(FAILED(ret)){
            NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
            NSLog(@"Failed to kAudioOutputUnitProperty_EnableIO=%d(%@)", ret, [err description]);
            return NO;
        }
    }
    AudioObjectShow(kAudioObjectSystemObject);
    
    AudioDeviceID inDevID = [self getBGMDevice];
    //AudioDeviceID inDevID = -1;
    ret = AudioUnitSetProperty(_inputUnit,
                               kAudioOutputUnitProperty_CurrentDevice,
                               kAudioUnitScope_Global,
                               0,
                               &inDevID,
                               sizeof(AudioDeviceID));
    if(FAILED(ret)){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed to set Device for Input = %d(%@)", ret, [err description]);
        return NO;
    }
    
    NSLog(@"Success to input device to BGB");
    return YES;
    
}
- (AudioDeviceID)getBGMDevice{
    OSStatus ret = noErr;
    UInt32 propertySize = 0;
    UInt32 num = 0;
    AudioDeviceID result = -1;
    
    AudioObjectPropertyAddress propAddress;
    propAddress.mSelector = kAudioHardwarePropertyDevices;
    propAddress.mScope = kAudioObjectPropertyScopeGlobal;
    propAddress.mElement = kAudioObjectPropertyElementMaster;
    
    ret = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &propAddress, 0, NULL, &propertySize);
    
    if(FAILED(ret)){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed to set Device for Input = %d(%@)", ret, [err description]);
        return -1;
    }
    num = propertySize / sizeof(AudioObjectID);
    NSLog(@"Number of devices = %u", (unsigned int)num);
    
    AudioObjectID *objects = malloc(propertySize);
    ret = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propAddress, 0, NULL, &propertySize, objects);
    if(FAILED(ret)){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed to set Device for Input = %d(%@)", ret, [err description]);
        free(objects);
        return -1;
    }
    
    for (int i = 0 ; i < num ; i++){
        //NSLog(@"Device : %2d, 0x%2X", i, objects[i]);
        //kAudioObjectPropertyName;
        CFStringRef name = NULL;
        propAddress.mSelector = kAudioObjectPropertyName;
        UInt32 size = sizeof(CFStringRef);
        ret = AudioObjectGetPropertyData(objects[i], &propAddress, 0, NULL,
                                         &size, &name);
        if(FAILED(ret)){
            NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
            NSLog(@"Failed to Get Name = %d(%@)", ret, [err description]);
            free(objects);
            return -1;
        }
        NSLog(@"Device[%02d,0x%02X]:%@", i, (unsigned int)objects[i],name);
        if (name != NULL){
            if (CFStringCompare(name, CFSTR("Background Music Device"),kCFCompareCaseInsensitive) == kCFCompareEqualTo){
                NSLog(@"BGM Device found");
                result = objects[i];
            }
            CFRelease(name);
        }
    }
    
    free(objects);
    return result;
}

-(Boolean)setInputFormat {
    AudioStreamBasicDescription asbd = {0};
    UInt32 size = sizeof(asbd);
    asbd.mSampleRate = 44100.0;
    asbd.mFormatID = kAudioFormatLinearPCM;
    asbd.mFormatFlags = kAudioFormatFlagIsFloat | kAudioFormatFlagIsPacked | kAudioFormatFlagIsNonInterleaved;
    asbd.mBytesPerPacket = 4;
    asbd.mFramesPerPacket = 1;
    asbd.mBytesPerFrame = 4;
    asbd.mChannelsPerFrame = 2;
    asbd.mBitsPerChannel = 32;
    
    OSStatus ret = AudioUnitSetProperty(_inputUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 1, &asbd, size);
    if(FAILED(ret)){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed to Set Format for Input side = %d(%@)", ret, [err description]);
        return NO;
    }
    NSLog(@"success to set format");
    return YES;
}

-(Boolean)setInputCallback{
    AURenderCallbackStruct callback;
    callback.inputProc = MyRenderIn;
    callback.inputProcRefCon = (__bridge void * _Nullable)(self);
    
    OSStatus ret = AudioUnitSetProperty(
                                        _inputUnit,
                                        kAudioOutputUnitProperty_SetInputCallback,
                                        kAudioUnitScope_Global,
                                        0,
                                        &callback,
                                        sizeof(callback));
    if(FAILED(ret)){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed to Set Input side callback = %d(%@)", ret, [err description]);
        return NO;
    }
    
    NSLog(@"Set input callback OK");
    return YES;
    
}




@end
