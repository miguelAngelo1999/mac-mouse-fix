//
// --------------------------------------------------------------------------
// ModifiedDragOutputNotificationCenter.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputNotificationCenter.h"
#import "TouchSimulator.h"
#import "Constants.h"
#import "IOHIDEventTypes.h"
#import "Mac_Mouse_Fix_Helper-Swift.h"

/// Private API for posting symbolic hotkeys
extern CGError CGSSetSymbolicHotKeyEnabled(int hotkey, bool enabled);
extern CGError CGSIsSymbolicHotKeyEnabled(int hotkey, bool *enabled);

@implementation ModifiedDragOutputNotificationCenter

#pragma mark - Vars

static ModifiedDragState *_drag;
static BOOL _triggered;

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
    _triggered = NO;
}

+ (void)handleBecameInUse {
    _triggered = NO;
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    /// Only trigger once per drag — on first significant horizontal movement
    if (_triggered) return;
    if (fabs(deltaX) < 2.0) return;
    
    _triggered = YES;
    
    /// Toggle Notification Centre via symbolic hotkey 163
    /// This is the same as the keyboard shortcut or trackpad gesture result
    [SymbolicHotKeys post:163];
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    _triggered = NO;
}

+ (void)suspend {
}

+ (void)unsuspend {
}

@end
