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

@implementation ModifiedDragOutputNotificationCenter

#pragma mark - Vars

static ModifiedDragState *_drag;
static BOOL _gestureStarted;

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
    _gestureStarted = NO;
}

+ (void)handleBecameInUse {
    _gestureStarted = NO;
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    /// Use horizontal movement only — left to open NC, right to close
    /// Negative deltaX = moving left = swiping from right edge = open NC
    double delta = -deltaX * 0.01; /// Scale factor for comfortable gesture speed
    
    if (fabs(delta) < 0.001) return;
    
    IOHIDEventPhaseBits phase = _gestureStarted ? kIOHIDEventPhaseChanged : kIOHIDEventPhaseBegan;
    _gestureStarted = YES;
    
    /// Post as horizontal dock swipe — macOS interprets rightward horizontal dock swipes
    /// as Notification Centre when natural scrolling direction is considered
    [TouchSimulator postDockSwipeEventWithDelta:delta
                                          type:kMFDockSwipeTypeHorizontal
                                         phase:phase
                            invertedFromDevice:_drag->naturalDirection];
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    if (_gestureStarted) {
        IOHIDEventPhaseBits endPhase = cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
        [TouchSimulator postDockSwipeEventWithDelta:0.0
                                              type:kMFDockSwipeTypeHorizontal
                                             phase:endPhase
                                invertedFromDevice:_drag->naturalDirection];
    }
    _gestureStarted = NO;
}

+ (void)suspend {
}

+ (void)unsuspend {
}

@end
