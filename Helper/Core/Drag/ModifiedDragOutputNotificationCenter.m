//
// --------------------------------------------------------------------------
// ModifiedDragOutputNotificationCenter.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputNotificationCenter.h"
#import "TouchSimulator.h"
#import "GestureScrollSimulator.h"
#import "Constants.h"
#import "IOHIDEventTypes.h"
#import <AppKit/AppKit.h>

@implementation ModifiedDragOutputNotificationCenter

#pragma mark - Vars

static ModifiedDragState *_drag;
static BOOL _gestureStarted;
static CGPoint _savedCursorPos;

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
    _gestureStarted = NO;
}

+ (void)handleBecameInUse {
    _gestureStarted = NO;
    
    /// Save cursor position and warp to right edge of main screen
    /// NC gesture only triggers from the right edge
    CGEventRef locEvent = CGEventCreate(NULL);
    _savedCursorPos = CGEventGetLocation(locEvent);
    CFRelease(locEvent);
    
    NSScreen *screen = NSScreen.mainScreen;
    CGFloat rightEdge = screen.frame.origin.x + screen.frame.size.width - 1;
    CGFloat cursorY = _savedCursorPos.y;
    CGWarpMouseCursorPosition(CGPointMake(rightEdge, cursorY));
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    /// Use horizontal movement — negative deltaX (moving left) = open NC
    int64_t dx = (int64_t)(-deltaX * 0.8);
    
    if (dx == 0) return;
    
    IOHIDEventPhaseBits phase = _gestureStarted ? kIOHIDEventPhaseChanged : kIOHIDEventPhaseBegan;
    _gestureStarted = YES;
    
    /// Post gesture scroll at the right edge — this is how the trackpad triggers NC
    [GestureScrollSimulator postGestureScrollEventWithDeltaX:dx
                                                      deltaY:0
                                                       phase:phase
                                          autoMomentumScroll:NO
                                          invertedFromDevice:YES];
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    if (_gestureStarted) {
        IOHIDEventPhaseBits endPhase = cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
        [GestureScrollSimulator postGestureScrollEventWithDeltaX:0
                                                          deltaY:0
                                                           phase:endPhase
                                              autoMomentumScroll:NO
                                              invertedFromDevice:YES];
    }
    _gestureStarted = NO;
    
    /// Restore cursor position
    CGWarpMouseCursorPosition(_savedCursorPos);
}

+ (void)suspend {
}

+ (void)unsuspend {
}

@end
