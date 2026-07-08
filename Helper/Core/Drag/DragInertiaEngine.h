//
// DragInertiaEngine.h
// Created for Mac Mouse Fix
//
// Uses the same DragCurve physics as scroll momentum for natural fling feel.
// Also provides precision scaling for fine adjustments.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void(^DragInertiaCallback)(double dx, double dy);

@interface DragInertiaEngine : NSObject

/// Track a drag input delta. Returns precision-scaled values via outDx/outDy.
/// Slow movements are scaled down to allow fine adjustments.
- (void)trackDeltaX:(double)dx deltaY:(double)dy
          outDeltaX:(double *)outDx outDeltaY:(double *)outDy;

/// Flywheel model: call this when drag becomes active.
/// Starts a continuous timer that applies and decays velocity.
/// Each subsequent call to -pedalDeltaX:deltaY: adds force to the flywheel.
/// callback fires at 120Hz with the current velocity (dx, dy) until stopped.
- (void)startFlywheelWithCallback:(DragInertiaCallback)callback;

/// Feed input into the running flywheel (call on every mouse event while in use).
- (void)pedalDeltaX:(double)dx deltaY:(double)dy;

/// Start fling after drag release. Uses DragCurve physics matching scroll momentum.
/// velocityScale: multiplier applied to exit velocity (default 1.0; use <1 for slow-range effects like volume)
- (void)startFlingWithVelocityScale:(double)velocityScale
                           callback:(DragInertiaCallback)callback;

/// Start fling with a pre-computed exit velocity (vx, vy in px/s).
/// Bypasses the internal EMA — use when the EMA timestamp is stale (e.g. after smoothingAnimator delay).
- (void)startFlingWithDirectVx:(double)vx vy:(double)vy
                      callback:(DragInertiaCallback)callback;

/// Cancel any running fling (call on new drag start).
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
