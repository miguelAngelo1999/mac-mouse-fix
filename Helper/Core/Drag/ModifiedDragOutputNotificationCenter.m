//
// --------------------------------------------------------------------------
// ModifiedDragOutputNotificationCenter.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ModifiedDragOutputNotificationCenter.h"
#import "Constants.h"
#import "IOHIDEventTypes.h"

@implementation ModifiedDragOutputNotificationCenter

/// Placeholder — NC interactive drag not feasible without HID-layer injection.
/// Kept as a registered plugin so existing configs referencing it don't crash.

static ModifiedDragState *_drag;

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef { _drag = dragStateRef; }
+ (void)handleBecameInUse {}
+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {}
+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {}
+ (void)suspend {}
+ (void)unsuspend {}

@end
