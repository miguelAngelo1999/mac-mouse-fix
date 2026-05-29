//
// --------------------------------------------------------------------------
// ModifiedDragOutputVolumeBrightness.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created for volume and brightness drag control
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputVolumeBrightness.h"
#import "ScrollOutputUtility.h"
#import "PointerFreeze.h"
#import "Constants.h"

@implementation ModifiedDragOutputVolumeBrightness

#pragma mark - Vars

static ModifiedDragState *_drag;

#pragma mark - Interface

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
}

+ (void)handleBecameInUse {
    /// Freeze pointer so it doesn't move while adjusting volume/brightness
    [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    /// Scale: ~400px of mouse movement = full range (0.0 to 1.0)
    /// Vertical: up (negative deltaY) = increase, down = decrease
    /// Horizontal: right (positive deltaX) = increase, left = decrease
    
    BOOL isHorizontal = [_drag->type isEqualToString:kMFModifiedDragTypeVolumeHorizontal]
                     || [_drag->type isEqualToString:kMFModifiedDragTypeBrightnessHorizontal];
    
    double delta = isHorizontal ? (deltaX / 250.0) : (-deltaY / 250.0);
    
    BOOL isVolume = [_drag->type isEqualToString:kMFModifiedDragTypeVolume]
                 || [_drag->type isEqualToString:kMFModifiedDragTypeVolumeHorizontal];
    
    if (isVolume) {
        float newVolume = [ScrollOutputUtility getSystemVolume] + (float)delta;
        [ScrollOutputUtility setSystemVolume:newVolume];
    } else {
        [ScrollOutputUtility adjustBrightnessByDelta:(float)delta];
    }
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    /// Unfreeze pointer
    [PointerFreeze unfreeze];
}

+ (void)suspend {
}

+ (void)unsuspend {
}

@end
