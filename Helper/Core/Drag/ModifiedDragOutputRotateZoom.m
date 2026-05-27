//
// --------------------------------------------------------------------------
// ModifiedDragOutputRotateZoom.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputRotateZoom.h"
#import "TouchSimulator.h"
#import "Constants.h"
#import "IOHIDEventTypes.h"
#import <CoreGraphics/CoreGraphics.h>

@implementation ModifiedDragOutputRotateZoom

#pragma mark - Vars

static ModifiedDragState *_drag;
static BOOL _rotateStarted;
static BOOL _zoomStarted;
static double _rotationAccumulator; /// Accumulated rotation for snap mode

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
    _rotateStarted = NO;
    _zoomStarted = NO;
    _rotationAccumulator = 0.0;
}

+ (void)handleBecameInUse {
    _rotateStarted = NO;
    _zoomStarted = NO;
    _rotationAccumulator = 0.0;
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    /// Check if Shift is held (for 90° snap mode)
    CGEventFlags flags = CGEventGetFlags(event);
    BOOL shiftHeld = (flags & kCGEventFlagMaskShift) != 0;
    
    /// --- Zoom: vertical movement (up = zoom in, down = zoom out) ---
    if (fabs(deltaY) > 0) {
        IOHIDEventPhaseBits zoomPhase = _zoomStarted ? kIOHIDEventPhaseChanged : kIOHIDEventPhaseBegan;
        _zoomStarted = YES;
        double magnification = -deltaY / 400.0;
        [TouchSimulator postMagnificationEventWithMagnification:magnification phase:zoomPhase];
    }
    
    /// --- Rotate: horizontal movement (left/right) ---
    if (fabs(deltaX) > 0) {
        double rotation = deltaX / 8.0;
        
        if (shiftHeld) {
            /// Snap mode: accumulate rotation and only fire at 90° boundaries
            _rotationAccumulator += rotation;
            double snapStep = 90.0; /// degrees
            
            if (fabs(_rotationAccumulator) >= snapStep) {
                double snappedRotation = ((_rotationAccumulator > 0) ? snapStep : -snapStep);
                _rotationAccumulator = fmod(_rotationAccumulator, snapStep);
                
                IOHIDEventPhaseBits phase = _rotateStarted ? kIOHIDEventPhaseChanged : kIOHIDEventPhaseBegan;
                _rotateStarted = YES;
                [TouchSimulator postRotationEventWithRotation:snappedRotation phase:phase];
            }
        } else {
            /// Free rotation
            _rotationAccumulator = 0.0;
            IOHIDEventPhaseBits phase = _rotateStarted ? kIOHIDEventPhaseChanged : kIOHIDEventPhaseBegan;
            _rotateStarted = YES;
            [TouchSimulator postRotationEventWithRotation:rotation phase:phase];
        }
    }
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    
    IOHIDEventPhaseBits endPhase = cancel ? kIOHIDEventPhaseCancelled : kIOHIDEventPhaseEnded;
    
    if (_zoomStarted) {
        [TouchSimulator postMagnificationEventWithMagnification:0 phase:endPhase];
    }
    if (_rotateStarted) {
        [TouchSimulator postRotationEventWithRotation:0 phase:endPhase];
    }
    
    _rotateStarted = NO;
    _zoomStarted = NO;
    _rotationAccumulator = 0.0;
}

+ (void)suspend {
}

+ (void)unsuspend {
}

@end
