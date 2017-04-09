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
    
    _lockForRec = [[NSRecursiveLock alloc] init];
    _lockForPlay = [[NSRecursiveLock alloc] init];
    
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
    
    RecordFragment *fragment = _cfPlay;
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
        _overflowPlaying = YES;
        //zero output
        UInt32 sampleNum = inNumberFrames;
        float *pLeft = (float *)ioData->mBuffers[0].mData;
        float *pRight = (float *)ioData->mBuffers[1].mData;
        bzero(pLeft,sizeof(float)*sampleNum );
        bzero(pRight,sizeof(float)*sampleNum );
        fragment->playedFrameLen += inNumberFrames;
        return noErr;
    }
    return noErr;
    
}


- (OSStatus) renderInput:(AudioUnitRenderActionFlags *)ioActionFlags inTimeStamp:(const AudioTimeStamp *) inTimeStamp inBusNumber:(UInt32) inBusNumber inNumberFrames:(UInt32)inNumberFrames ioData:(AudioBufferList *)ioData{
    
    [_lockForRec lock];
    if (!_recording){
        [_lockForRec unlock];
        return noErr;
    }
    
    RecordFragment *fragment = _cfRec;
    
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
        [_lockForRec unlock];
        return ret;
    }
    fragment->storedFrameLen += inNumberFrames;
    
    [_lockForRec unlock];
    return noErr;
    
}


- (Boolean)initialize{
    
    _numFragments = 20;
    UInt32 size = _numFragments * sizeof(RecordFragment);
    
    _fragments = (RecordFragment *)malloc(_numFragments * sizeof(RecordFragment));
    NSLog(@"allocated : %.2f [MB]", ((float)size)/1024.0/1024.0);
    
    for (int i = 0 ; i < _numFragments; i++){
        _fragments[i].no = i;
        _fragments[i].bUsed = false;
    }
    
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
    cd.componentSubType = kAudioUnitSubType_TimePitch;
    //cd.componentSubType = kAudioUnitSubType_NewTimePitch; //low quality slightly lower volume , low cpu usage.
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

- (Boolean)setBypass:(Boolean)bypass{
    UInt32 val = (UInt32)bypass;
    

    OSStatus ret = AudioUnitSetProperty(_newTimePitchUnit,
                                         kAudioUnitProperty_BypassEffect,
                                         kAudioUnitScope_Global,
                                         0,
                                         &val,
                                         sizeof(UInt32));
    if (FAILED(ret)){
        NSError *err = [NSError errorWithDomain:NSOSStatusErrorDomain code:ret userInfo:nil];
        NSLog(@"Failed to set Playback rate = %d(%@)", ret, [err description]);
        return NO;
    }
    
    
    return YES;
}

-(NSString *)formatSec:(double)sec
{
    NSString *ret = [NSString stringWithFormat:@"%.2d:%.2d:%.2d",
                     (int)sec/60,
                     ((int)sec)%60,
                     (int)((sec-(int)(sec))*100)];
    return ret;
}


- (Boolean)startNewRecord:(float)startSec{

    [_lockForRec lock];
    
    if (_recording){
        NSLog(@"Still recording");
        [_lockForRec unlock];
        return NO;
    }
    
    //find slot
    bool found = false;
    for(int i = 0; i < _numFragments ; i++){
        if (!_fragments[i].bUsed){
            found = true;
            _cfRec = &(_fragments[i]);
            break;
        }
    }
    if (!found){
        NSLog(@"[loopback]startNewRecord failed. All buffer used...");
        [_lockForRec unlock];
        return NO;
    }
    _cfRec->bUsed = true;
    _cfRec->startSecInSong = startSec;
    _cfRec->endSecInSong = startSec;
    _cfRec->storedFrameLen = 0;
    
    NSLog(@"Started new record from %@",[self formatSec:startSec]);
    
    _recording = YES;
    [_lockForRec unlock];
    return YES;
}

- (void)garbageCollect{
    
    //remove j-th fragments if i-th fragments cover.
    
    for (int i = 0 ; i < _numFragments ; i++){
        if (!_fragments[i].bUsed){
            continue;
        }
        
        float start = _fragments[i].startSecInSong;
        float end = _fragments[i].endSecInSong;
        for(int j = 0; j < _numFragments; j++){
            if (i ==j) {
                continue;
            }
            if (!_fragments[j].bUsed){
                continue;
            }
            if ((start <= _fragments[j].startSecInSong) &&
                (end >= _fragments[j].endSecInSong)){
                _fragments[j].bUsed = false;
            }
            
        }
    }
    [self dumpFragments];
}

- (void)dumpFragments{
    for (int i = 0 ; i < _numFragments; i++){
        if(_fragments[i].bUsed){
            NSLog(@"fragment[%02d] %@ - %@ (%.2f[%.2f])",i,
                  [self formatSec:_fragments[i].startSecInSong],
                  [self formatSec:_fragments[i].endSecInSong],
                  _fragments[i].endSecInSong - _fragments[i].startSecInSong,
                  _fragments[i].storedFrameLen / 44100.0f);
        }else{
            NSLog(@"fragment[%02d] unused",i);
        }
    }
}

- (Boolean)stopRecord{
    [_lockForRec lock];
    if (_recording){
        if (_cfRec->storedFrameLen <= 44100){
            NSLog(@"trash too short record");
            _cfRec->bUsed = false;
        }else{
            _cfRec->endSecInSong = _cfRec->startSecInSong + _cfRec->storedFrameLen/44100.0f;
            [self garbageCollect];
            NSLog(@"record stopped. as %@ to %@  %f[%f] secs",
                  [self formatSec:_cfRec->startSecInSong],
                  [self formatSec:_cfRec->endSecInSong],
                  _cfRec->endSecInSong - _cfRec->startSecInSong,
                  _cfRec->storedFrameLen/44100.0
                  );
        }
    }
    _recording = NO;

    [_lockForRec unlock];
    return YES;
}

- (Boolean)canStartPlayFrom:(float)sec{
    int index = [self findLongestFragmentsStartFrom:sec];
    if (-1 == index){
        return NO;
    }else{
        return YES;
    }
}

- (int)findLongestFragmentsStartFrom:(float)sec{
    int ret = -1;
    float length = 0.0f;
    for (int i = 0 ; i < _numFragments; i++){
        if (!_fragments[i].bUsed){
            continue;
        }
        if ( (_fragments[i].startSecInSong <= sec) &&
            (_fragments[i].endSecInSong >=sec)){
            float l = _fragments[i].endSecInSong - sec;
            if (length < l){
                ret = i;
                length = l;
            }
        }
    }
    return ret;
}

- (Boolean)startPlayFrom:(float)sec{

    int index = [self findLongestFragmentsStartFrom:sec];
    if (-1 == index){
        NSLog(@"[loopback]startPlayFrom failed. no available record");
        _playing = NO;
        return NO;
    }
    
    float offset = sec - _fragments[index].startSecInSong;
    _fragments[index].playedFrameLen = (UInt32)(offset*44100);

    if (_fragments[index].playedFrameLen > _fragments[index].storedFrameLen){
        NSAssert(false, @"something wrong");
    }

    _cfPlay = &(_fragments[index]);
    
    _overflowPlaying = NO;
    _playing = YES;
    return YES;
}

- (Boolean)seekToPosition:(float)sec{

    //TODO use currentFragments for Playing as possible.
    return [self startPlayFrom:sec];
    
}

- (Boolean)stopPlay{
    _playing = NO;
    return YES;
}


- (float)currentPlayPosition{
    if (_cfPlay){
        return _cfPlay->startSecInSong + ((_cfPlay->playedFrameLen)/44100.0);
    }else{
        return 0.0f;
    }
}

- (Boolean)isPlaying{
    return _playing;
}

- (Boolean)isOverflowPlaying{
    return _overflowPlaying;
}

@end
