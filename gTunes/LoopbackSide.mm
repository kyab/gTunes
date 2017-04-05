//
//  LoopbackSide.m
//  gTunes
//
//  Created by koji on 2017/04/02.
//  Copyright © 2017年 koji. All rights reserved.
//


#import "LoopbackSide.h"
#import <AudioToolbox/AudioToolbox.h>
#include <CoreFoundation/CFPluginCOM.h>

@implementation LoopbackSide
- (id)init
{
    self = [super init];
    _recording = NO;
    _playing = NO;
    return self;
}

OSStatus MyRender(void *inRefCon,
                  AudioUnitRenderActionFlags *ioActionFlags,
                  const AudioTimeStamp      *inTimeStamp,
                  UInt32 inBusNumber,
                  UInt32 inNumberFrames,
                  AudioBufferList *ioData){
    {
//        static UInt32 count = 0;
//        if ((count % 100) == 0){
//            NSLog(@"LoopbackSide outputcallback inNumberFrames = %u", inNumberFrames);
//        }
//        count++;
    }
    
    LoopbackSide *loopback = (__bridge LoopbackSide *)inRefCon;
    return [loopback renderOutput:ioActionFlags inTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:ioData];
    
    return noErr;
}

OSStatus MyRenderIn(void *inRefCon,
                    AudioUnitRenderActionFlags *ioActionFlags,
                    const AudioTimeStamp      *inTimeStamp,
                    UInt32 inBusNumber,
                    UInt32 inNumberFrames,
                    AudioBufferList *ioData){
    {
//        static UInt32 count = 0;
//        if ((count % 100) == 0){
//            NSLog(@"LoopbackSide inputcallback inNumberFrames = %u", inNumberFrames);
//        }
//        count++;
    }
    
    LoopbackSide *loopback = (__bridge LoopbackSide *)inRefCon;
    return [loopback renderInput:ioActionFlags inTimeStamp:inTimeStamp inBusNumber:inBusNumber inNumberFrames:inNumberFrames ioData:ioData];
    
}

- (OSStatus) renderOutput:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData{
    
    
    if (!_playing){
        //zero output
        UInt32 sampleNum = inNumberFrames;
        float *pLeft = (float *)ioData->mBuffers[0].mData;
        float *pRight = (float *)ioData->mBuffers[1].mData;
        bzero(pLeft,sizeof(float)*sampleNum );
        bzero(pRight,sizeof(float)*sampleNum );
        return noErr;
    }
    
    RecordFragment *fragment = &(_fragments[0]);
    if (fragment->playedFrameLen + inNumberFrames <= fragment->storedFrameLen){
        memcpy(ioData->mBuffers[0].mData,
               &(fragment->leftBuf[fragment->playedFrameLen]),
               sizeof(float)*inNumberFrames);
        memcpy(ioData->mBuffers[1].mData,
               &(fragment->rightBuf[fragment->playedFrameLen]),
               sizeof(float)*inNumberFrames);
        fragment->playedFrameLen += inNumberFrames;
    }else{
        //fragment->playedFrameLen = 0;
        NSLog(@"overflow");
        //zero output
        UInt32 sampleNum = inNumberFrames;
        float *pLeft = (float *)ioData->mBuffers[0].mData;
        float *pRight = (float *)ioData->mBuffers[1].mData;
        bzero(pLeft,sizeof(float)*sampleNum );
        bzero(pRight,sizeof(float)*sampleNum );
        fragment->playedFrameLen += inNumberFrames;
        return noErr;
    }
    NSLog(@"ou");
    return noErr;
    
}


- (OSStatus) renderInput:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData{
    
    if (!_recording){
        return noErr;
    }
    
    RecordFragment *fragment = &(_fragments[0]);
    
    AudioBufferList *bufferList = (AudioBufferList *)malloc(sizeof(AudioBufferList) +  sizeof(AudioBuffer)); // for 2 buffers for left and right
    bufferList->mNumberBuffers = 2;
    bufferList->mBuffers[0].mDataByteSize = 32*inNumberFrames;
    bufferList->mBuffers[0].mNumberChannels = 1;
    bufferList->mBuffers[0].mData = &(fragment->leftBuf[fragment->storedFrameLen]);
    bufferList->mBuffers[1].mDataByteSize = 32*inNumberFrames;
    bufferList->mBuffers[1].mNumberChannels = 1;
    bufferList->mBuffers[1].mData = &(fragment->rightBuf[fragment->storedFrameLen]);
    
    OSStatus ret = AudioUnitRender(_inputUnit,
                                   ioActionFlags,
                                   inTimeStamp,
                                   inBusNumber,
                                   inNumberFrames,
                                   bufferList
                                   );
    if (FAILED(ret)){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed AudioUnitRender err=%d(%@)", ret, [err description]);
        
        return ret;
    }
    fragment->storedFrameLen += inNumberFrames;
    NSLog(@"i");
    
    return noErr;
    
}


- (Boolean)initialize{
    
    _numFragments = 2;
    UInt32 size = _numFragments * sizeof(RecordFragment);
    
    _fragments = (RecordFragment *)malloc(_numFragments * sizeof(RecordFragment));
    NSLog(@"allocated : %.2f [MB]", ((float)size)/1024.0/1024.0);
    
    if (![self initializeInput]) return NO;
    if (![self initializeOutput]) return NO;
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

-(Boolean)startOutput{
    OSStatus ret = AUGraphStart(_graph);
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
    
    AudioObjectID *objects = (AudioObjectID *)malloc(propertySize);
    ret = AudioObjectGetPropertyData(kAudioObjectSystemObject, &propAddress, 0, NULL, &propertySize, objects);
    if(FAILED(ret)){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed to set Device for Input = %d(%@)", ret, [err description]);
        free(objects);
        return -1;
    }
    
    for (int i = 0 ; i < num ; i++){
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
        
        //NSLog(@"Device[%02d,0x%02X]:%@", i, (unsigned int)objects[i],name);
        if (name != NULL){
            if (CFStringCompare(name, CFSTR("Background Music Device"),kCFCompareCaseInsensitive) == kCFCompareEqualTo){
                result = objects[i];
            }
            CFRelease(name);
        }
    }
    if (-1 == result){
        NSLog(@"No BGM Device found on system");
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
    
    return YES;
    
}

/*
    Based on : 
 http://qiita.com/MJeeeey/items/6583689e23ac702e31c0

 
*/
-(Boolean)initializeOutput{
    OSStatus ret = noErr;
    
    ret = NewAUGraph(&_graph);
    if (FAILED(ret)) {
        NSLog(@"failed to create AU Graph");
        return NO;
    }
    ret = AUGraphOpen(_graph);
    if (FAILED(ret)) {
        NSLog(@"failed to open AU Graph");
        return NO;
    }
    
    AudioComponentDescription cd;
    
    cd.componentType = kAudioUnitType_FormatConverter;
    cd.componentSubType = kAudioUnitSubType_AUConverter;
    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    AUNode converterNode;
    AUGraphAddNode(_graph, &cd, &converterNode);
    ret = AUGraphNodeInfo(_graph, converterNode, NULL, &_converterUnit);
    if (FAILED(ret)){
        NSLog(@"failed to AUGraphNodeInfo for AUConverter");
        return NO;
    }
    
    cd.componentType = kAudioUnitType_FormatConverter;
    //cd.componentSubType = kAudioUnitSubType_TimePitch;
    cd.componentSubType = kAudioUnitSubType_NewTimePitch;
    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    AUNode newTimePitchNode;
    AUGraphAddNode(_graph, &cd, &newTimePitchNode);
    ret = AUGraphNodeInfo(_graph, newTimePitchNode, NULL, &_newTimePitchUnit);
    if (FAILED(ret)){
        NSLog(@"failed to AUGraphNodeInfo for NewTimePitch");
        return NO;
    }
    
    cd.componentType = kAudioUnitType_Output;
    cd.componentSubType = kAudioUnitSubType_DefaultOutput;
    cd.componentManufacturer = kAudioUnitManufacturer_Apple;
    cd.componentFlags = 0;
    cd.componentFlagsMask = 0;
    AUNode outNode;
    ret = AUGraphAddNode(_graph, &cd, &outNode);
    if (FAILED(ret)){
        NSLog(@"failed to AUGraphAddNode");
        return NO;
    }
    ret = AUGraphNodeInfo(_graph, outNode, NULL, &_outUnit);
    if (FAILED(ret)){
        NSLog(@"failed to AUGraphNodeInfo");
        return NO;
    }
    
    
    //set callback to first unit
    AURenderCallbackStruct callbackInfo;
    callbackInfo.inputProc = MyRender;
    callbackInfo.inputProcRefCon = (__bridge void * _Nullable)(self);
    ret = AUGraphSetNodeInputCallback(_graph, converterNode, 0, &callbackInfo);
    if (FAILED(ret)){
        NSLog(@"failed to set callback for Output");
        return NO;
    }
    
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
    
    ret = AudioUnitSetProperty(_converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, size);
    if (FAILED(ret)){
        NSLog(@"failed to kAudioUnitProperty_StreamFormat for converter(I)");
        return NO;
    }
    
    ret = AudioUnitSetProperty(_outUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &asbd, size);
    if (FAILED(ret)){
        NSLog(@"failed to kAudioUnitProperty_StreamFormat for output(I)");
        return NO;
    }
    
    AudioStreamBasicDescription outputFormatTmp;
    
    ret = AudioUnitGetProperty(_newTimePitchUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &outputFormatTmp, &size);
    if (FAILED(ret)){
        NSLog(@"failed to Get kAudioUnitProperty_StreamFormat(TimePitch in)");
        return NO;
    }
    
    ret = AudioUnitSetProperty(_converterUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Output, 0, &outputFormatTmp, size);
    if (FAILED(ret)){
        NSLog(@"failed to kAudioUnitProperty_StreamFormat for converter(O)");
        return NO;
    }
    
    ret = AUGraphConnectNodeInput(_graph, converterNode,0, newTimePitchNode,0);
    if (FAILED(ret)){
        NSLog(@"failed to connect node (from converter to timepitch)");
        return NO;
    }
    ret = AUGraphConnectNodeInput(_graph, newTimePitchNode, 0, outNode, 0);
    if (FAILED(ret)){
        NSLog(@"failed to connect node (from timepitch to output)");
        return NO;
    }
    
    ret = AUGraphInitialize(_graph);
    if (FAILED(ret)){
        NSLog(@"failed to AUGraphInitialize");
        return NO;
    }
    
    //[self printParameters:_newTimePitchUnit];
    
    return YES;
}

- (void)printParameters:(AudioUnit) au {
    // AudioUnitGetProperty で取得する paramList のサイズを取得
    UInt32 size = sizeof(UInt32);
    AudioUnitGetPropertyInfo(au,
                             kAudioUnitProperty_ParameterList,
                             kAudioUnitScope_Global,
                             0,
                             &size,
                             NULL);
    
    int numOfParams = size / sizeof(AudioUnitParameterID);
    NSLog(@"numOfParams = %d", numOfParams);
    
    // paramList の各IDを取得
    AudioUnitParameterID paramList[numOfParams];
    AudioUnitGetProperty(au,
                         kAudioUnitProperty_ParameterList,
                         kAudioUnitScope_Global,
                         0,
                         paramList,
                         &size);
    
    AudioUnitParameterInfo *_paramInfo = (AudioUnitParameterInfo *)malloc(numOfParams * sizeof(AudioUnitParameterInfo));
    
    for (int i = 0; i < numOfParams; i++) {
        NSLog(@"paramList[%d] = %d", i, (unsigned int)paramList[i]);
        
        // 各IDのパラメータを取得
        size = sizeof(_paramInfo[i]);
        AudioUnitGetProperty(au,
                             kAudioUnitProperty_ParameterInfo,
                             kAudioUnitScope_Global,
                             paramList[i],
                             &_paramInfo[i],
                             &size);
        
        NSLog(@"paramInfo.name = %s", _paramInfo[i].name);
        NSLog(@"paramInfo.minValue = %f", _paramInfo[i].minValue);
        NSLog(@"paramInfo.maxValue = %f", _paramInfo[i].maxValue);
        NSLog(@"paramInfo.defaultValue = %f", _paramInfo[i].defaultValue);
        float value;
        size = sizeof(value);
        AudioUnitGetParameter(au,
                              paramList[i],
                              kAudioUnitScope_Global,
                              0,
                              &value);
        NSLog(@"paramInfo.currentValue = %f", value);
        
    }
}


- (Boolean)startNewRecord:(float)startSec{
    _fragments[0].startSecInSong = startSec;
    _fragments[0].storedFrameLen = 0;
    
    _recording = YES;
    return YES;
}

- (Boolean)stopRecord:(float)endSec{
    if (_recording){
        _fragments[0].endSecInSong = endSec;
        _recording = NO;
        NSLog(@"record stopped. from %f to %f. %f secs",
                        _fragments[0].startSecInSong,
                        _fragments[0].endSecInSong,
              _fragments[0].storedFrameLen/44100.0);
    }
    return YES;
}

- (Boolean)startPlayFrom:(float)sec{

    if (sec < _fragments[0].startSecInSong){
        NSLog(@"not stored <");
        _playing = NO;
        return NO;
    }
    if (_fragments[0].endSecInSong < sec){
        NSLog(@"not stored >");
        _playing = NO;
        return NO;
    }
    
    float offset = sec - _fragments[0].startSecInSong;
    _fragments[0].playedFrameLen = (UInt32)(offset*44100);

    if (_fragments[0].playedFrameLen > _fragments[0].storedFrameLen){
        NSLog(@"something wrong");
        _playing = NO;
        return NO;
    }
    
    _playing = YES;
    return YES;
}

- (Boolean)seekToPosition:(float)sec{

    return [self startPlayFrom:sec];
    
}

- (Boolean)stopPlay{
    _playing = NO;
    return YES;
}

- (Boolean)setPlaybackRate:(float)rate{
    OSStatus ret = AudioUnitSetParameter(_newTimePitchUnit,
                                         kTimePitchParam_Rate,
                                         kAudioUnitScope_Global,
                                         0,
                                         rate,
                                         0);
    if (FAILED(ret)){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed to set Playback rate = %d(%@)", ret, [err description]);
        return NO;
    }
    return YES;
}

- (float)currentPlayPosition{
    return _fragments[0].startSecInSong + (_fragments[0].playedFrameLen/44100.0);
}

@end
