//
// --------------------------------------------------------------------------
// ContextualScrollActions.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Context-aware scroll actions (audio device switch, window cycle)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>

NS_ASSUME_NONNULL_BEGIN

@interface ContextualScrollActions : NSObject

/// Cycle to the next/previous audio output device
+ (void)cycleAudioOutputDevice:(BOOL)forward;

/// Cycle through windows of the frontmost app (Cmd+` / Cmd+Shift+`)
+ (void)cycleAppWindows:(BOOL)forward;

@end

NS_ASSUME_NONNULL_END
