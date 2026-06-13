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

/// Start fling after drag release. Uses DragCurve physics matching scroll momentum.
/// velocityScale: multiplier applied to exit velocity (default 1.0; use <1 for slow-range effects like volume)
- (void)startFlingWithVelocityScale:(double)velocityScale
                           callback:(DragInertiaCallback)callback;

/// Cancel any running fling (call on new drag start).
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
