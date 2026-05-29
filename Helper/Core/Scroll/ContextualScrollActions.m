//
// --------------------------------------------------------------------------
// ContextualScrollActions.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Context-aware scroll actions (audio device switch, window cycle)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ContextualScrollActions.h"
#import <CoreAudio/CoreAudio.h>
#import <AppKit/AppKit.h>
#import <ApplicationServices/ApplicationServices.h>
#import "WannabePrefixHeader.h"

@implementation ContextualScrollActions

#pragma mark - Public

+ (BOOL)handleScrollEventIfContextual:(CGEventRef)event
                            deltaAxis1:(int64_t)deltaAxis1
                            deltaAxis2:(int64_t)deltaAxis2 {
    /// Currently returns NO — contextual actions are exposed as scroll effect
    /// modifications (audioDeviceSwitch / windowCycle) assigned to button modifiers,
    /// not as always-on position-based behavior.
    return NO;
}

#pragma mark - Audio Output Device Cycling (called from Scroll.m output)

+ (void)cycleAudioOutputDevice:(BOOL)forward {
    
    AudioObjectPropertyAddress devicesAddr = {
        kAudioHardwarePropertyDevices,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    
    UInt32 dataSize = 0;
    OSStatus status = AudioObjectGetPropertyDataSize(kAudioObjectSystemObject, &devicesAddr, 0, NULL, &dataSize);
    if (status != noErr) return;
    
    UInt32 deviceCount = dataSize / sizeof(AudioDeviceID);
    if (deviceCount == 0) return;
    
    AudioDeviceID *devices = malloc(dataSize);
    status = AudioObjectGetPropertyData(kAudioObjectSystemObject, &devicesAddr, 0, NULL, &dataSize, devices);
    if (status != noErr) { free(devices); return; }
    
    /// Filter to output devices only
    AudioDeviceID outputDevices[64];
    int outputCount = 0;
    
    for (UInt32 i = 0; i < deviceCount && outputCount < 64; i++) {
        AudioObjectPropertyAddress streamsAddr = {
            kAudioDevicePropertyStreams,
            kAudioDevicePropertyScopeOutput,
            kAudioObjectPropertyElementMain
        };
        UInt32 streamSize = 0;
        AudioObjectGetPropertyDataSize(devices[i], &streamsAddr, 0, NULL, &streamSize);
        if (streamSize > 0) {
            outputDevices[outputCount++] = devices[i];
        }
    }
    free(devices);
    
    if (outputCount < 2) return;
    
    /// Get current default output
    AudioObjectPropertyAddress defaultAddr = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioDeviceID currentDevice = kAudioObjectUnknown;
    UInt32 size = sizeof(currentDevice);
    AudioObjectGetPropertyData(kAudioObjectSystemObject, &defaultAddr, 0, NULL, &size, &currentDevice);
    
    /// Find current index
    int currentIndex = -1;
    for (int i = 0; i < outputCount; i++) {
        if (outputDevices[i] == currentDevice) { currentIndex = i; break; }
    }
    if (currentIndex < 0) currentIndex = 0;
    
    /// Cycle
    int newIndex = forward ? (currentIndex + 1) % outputCount
                           : (currentIndex - 1 + outputCount) % outputCount;
    AudioDeviceID newDevice = outputDevices[newIndex];
    
    /// Set new default
    AudioObjectPropertyAddress setAddr = {
        kAudioHardwarePropertyDefaultOutputDevice,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    AudioObjectSetPropertyData(kAudioObjectSystemObject, &setAddr, 0, NULL, sizeof(newDevice), &newDevice);
    
    /// Log
    AudioObjectPropertyAddress nameAddr = {
        kAudioObjectPropertyName,
        kAudioObjectPropertyScopeGlobal,
        kAudioObjectPropertyElementMain
    };
    CFStringRef nameRef = NULL;
    UInt32 nameSize = sizeof(nameRef);
    if (AudioObjectGetPropertyData(newDevice, &nameAddr, 0, NULL, &nameSize, &nameRef) == noErr && nameRef) {
        NSString *name = (__bridge_transfer NSString *)nameRef;
        DDLogInfo(@"ContextualScrollActions: Switched audio output to '%@'", name);
    }
}

#pragma mark - Window Cycling (called from Scroll.m output)

+ (void)cycleAppWindows:(BOOL)forward {
    /// Cycle through windows of the frontmost app using Cmd+` / Cmd+Shift+`
    CGKeyCode backtick = 50;
    CGEventFlags flags = forward ? kCGEventFlagMaskCommand
                                 : (kCGEventFlagMaskCommand | kCGEventFlagMaskShift);
    
    CGEventRef keyDown = CGEventCreateKeyboardEvent(NULL, backtick, true);
    CGEventRef keyUp = CGEventCreateKeyboardEvent(NULL, backtick, false);
    CGEventSetFlags(keyDown, flags);
    CGEventSetFlags(keyUp, flags);
    CGEventPost(kCGSessionEventTap, keyDown);
    CGEventPost(kCGSessionEventTap, keyUp);
    CFRelease(keyDown);
    CFRelease(keyUp);
}

@end
