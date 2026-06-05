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
#import "PointerFreeze.h"
#import "WannabePrefixHeader.h"
#import "MFHIDEventImports.h"
#import <AppKit/AppKit.h>
#import <CoreGraphics/CoreGraphics.h>
#import <IOKit/hidsystem/IOHIDEventSystemClient.h>
#import <dlfcn.h>

/// IOHIDEvent NavigationSwipe creation — dispatch at HID layer for smooth rendering
/// This bypasses CGEvent entirely and sends events the same way real trackpad hardware does.

typedef IOHIDEventRef (*IOHIDEventCreateNavigationSwipeEventFunc)(
    CFAllocatorRef allocator,
    uint64_t timeStamp,
    IOHIDSwipeMask swipeMask,
    IOHIDEventOptionBits options
);

typedef IOReturn (*IOHIDEventSystemClientDispatchEventFunc)(
    IOHIDEventSystemClientRef client,
    IOHIDEventRef event
);

typedef IOHIDEventSystemClientRef (*IOHIDEventSystemClientCreateFunc)(
    CFAllocatorRef allocator
);

typedef void (*IOHIDEventSetFloatValueFunc)(
    IOHIDEventRef event,
    IOHIDEventField field,
    IOHIDFloat value
);

typedef void (*IOHIDEventSetIntegerValueFunc)(
    IOHIDEventRef event,
    IOHIDEventField field,
    CFIndex value
);

static IOHIDEventCreateNavigationSwipeEventFunc _IOHIDEventCreateNavigationSwipeEvent = NULL;
static IOHIDEventSystemClientDispatchEventFunc  _IOHIDEventSystemClientDispatchEvent  = NULL;
static IOHIDEventSystemClientCreateFunc         _IOHIDEventSystemClientCreate         = NULL;
static IOHIDEventSetFloatValueFunc              _IOHIDEventSetFloatValue              = NULL;
static IOHIDEventSetIntegerValueFunc            _IOHIDEventSetIntegerValue            = NULL;
static IOHIDEventSystemClientRef                _hidClient                            = NULL;

static void loadHIDSymbols(void) {
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        void *handle = dlopen("/System/Library/Frameworks/IOKit.framework/IOKit", RTLD_LAZY);
        if (!handle) handle = RTLD_DEFAULT;
        _IOHIDEventCreateNavigationSwipeEvent = dlsym(handle, "IOHIDEventCreateNavigationSwipeEvent");
        _IOHIDEventSystemClientDispatchEvent  = dlsym(handle, "IOHIDEventSystemClientDispatchEvent");
        _IOHIDEventSystemClientCreate         = dlsym(handle, "IOHIDEventSystemClientCreate");
        _IOHIDEventSetFloatValue              = dlsym(handle, "IOHIDEventSetFloatValue");
        _IOHIDEventSetIntegerValue            = dlsym(handle, "IOHIDEventSetIntegerValue");
        
        if (_IOHIDEventSystemClientCreate) {
            _hidClient = _IOHIDEventSystemClientCreate(kCFAllocatorDefault);
        }
        
        DDLogInfo(@"NC Drag: HID symbols loaded. NavSwipe=%p Dispatch=%p Client=%p",
                  _IOHIDEventCreateNavigationSwipeEvent,
                  _IOHIDEventSystemClientDispatchEvent,
                  _hidClient);
    });
}

@implementation ModifiedDragOutputNotificationCenter

static ModifiedDragState *_drag;
static BOOL _gestureStarted;
static double _originOffset;
static double _lastDelta;
static double _velocityBuffer[5]; /// Last 5 deltas for velocity averaging
static int _velocityIndex;

+ (void)initializeWithDragState:(ModifiedDragState *)dragStateRef {
    _drag = dragStateRef;
    loadHIDSymbols();
}

+ (void)handleBecameInUse {
    _gestureStarted = NO;
    _originOffset = 0.0;
    _lastDelta = 0.0;
    _velocityIndex = 0;
    memset(_velocityBuffer, 0, sizeof(_velocityBuffer));
    
    /// Warp cursor to right edge — NC gesture requires edge position
    CGEventRef locEvent = CGEventCreate(NULL);
    CGPoint cursorPos = CGEventGetLocation(locEvent);
    CFRelease(locEvent);
    
    NSPoint mouse = [NSEvent mouseLocation];
    for (NSScreen *screen in [NSScreen screens]) {
        if (NSPointInRect(mouse, screen.frame)) {
            CGDirectDisplayID displayID = [[[screen deviceDescription] objectForKey:@"NSScreenNumber"] unsignedIntValue];
            CGRect bounds = CGDisplayBounds(displayID);
            CGPoint edgePoint = CGPointMake(bounds.origin.x + bounds.size.width - 2, cursorPos.y);
            CGWarpMouseCursorPosition(edgePoint);
            break;
        }
    }
    
    CGDisplayHideCursor(kCGNullDirectDisplay);
    [PointerFreeze freezePointerAtPosition:_drag->usageOrigin];
}

+ (void)handleMouseInputWhileInUseWithDeltaX:(double)deltaX deltaY:(double)deltaY event:(CGEventRef)event {
    
    CGSize screenSize = NSScreen.mainScreen.frame.size;
    double scale = 1.8 / screenSize.width;
    double delta = deltaX * scale;
    
    /// Skip initialization artifacts
    if (fabs(deltaX) > 80) return;
    
    if (!_gestureStarted) {
        /// Start at high offset (NC "already fully out"), then user drags to control
        _gestureStarted = YES;
        _originOffset = 1.5;
        [self postNCSwipeWithOffset:_originOffset phase:kIOHIDEventPhaseBegan];
        _originOffset = 1.4;
        [self postNCSwipeWithOffset:_originOffset phase:kIOHIDEventPhaseChanged];
        return;
    }
    
    _originOffset += delta;
    _originOffset = fmax(0.0, fmin(2.0, _originOffset));
    _lastDelta = delta;
    _velocityBuffer[_velocityIndex % 5] = delta;
    _velocityIndex++;
    
    [self postNCSwipeWithOffset:_originOffset phase:kIOHIDEventPhaseChanged];
}

+ (void)handleDeactivationWhileInUseWithCancel:(BOOL)cancel {
    
    if (_gestureStarted) {
        /// Calculate average velocity from last 5 frames
        double avgVelocity = 0;
        int count = MIN(_velocityIndex, 5);
        for (int i = 0; i < count; i++) avgVelocity += _velocityBuffer[i];
        if (count > 0) avgVelocity /= count;
        
        /// Use velocity direction for snap decision (fling support)
        IOHIDEventPhaseBits phase;
        if (fabs(avgVelocity) > 0.002) {
            /// Fling detected — use direction
            phase = (avgVelocity > 0) ? kIOHIDEventPhaseEnded : kIOHIDEventPhaseCancelled;
        } else {
            /// No fling — use position
            phase = (_originOffset >= 0.5) ? kIOHIDEventPhaseEnded : kIOHIDEventPhaseCancelled;
        }
        
        /// Boost exit speed for stronger fling effect
        _lastDelta = avgVelocity * 8.0;
        
        [self postNCSwipeWithOffset:_originOffset phase:phase];
    }
    
    CGDisplayShowCursor(kCGNullDirectDisplay);
    [PointerFreeze unfreeze];
}

+ (void)postNCSwipeWithOffset:(double)offset phase:(IOHIDEventPhaseBits)phase {
    
    /// CGEvent path — posts NavigationSwipe events (slightly choppy but functional)
    CGEventRef e29 = CGEventCreate(NULL);
    CGEventSetDoubleValueField(e29, 55, 29);
    CGEventSetIntegerValueField(e29, 45, 1);
    CGEventSetIntegerValueField(e29, 53, 3);
    CGEventSetIntegerValueField(e29, 101, 28);
    CGEventSetIntegerValueField(e29, 107, 848);
    
    CGEventRef e31 = CGEventCreate(NULL);
    CGEventSetDoubleValueField(e31, 55, 31);
    CGEventSetIntegerValueField(e31, 45, 1);
    CGEventSetIntegerValueField(e31, 53, 3);
    CGEventSetIntegerValueField(e31, 101, 28);
    CGEventSetIntegerValueField(e31, 107, 848);
    CGEventSetDoubleValueField(e31, 110, 27);
    CGEventSetDoubleValueField(e31, 119, 1.401298464324817e-45);
    CGEventSetDoubleValueField(e31, 123, 1);
    CGEventSetDoubleValueField(e31, 139, 1.401298464324817e-45);
    CGEventSetDoubleValueField(e31, 165, 1);
    CGEventSetIntegerValueField(e31, 138, 1);
    CGEventSetDoubleValueField(e31, 132, phase);
    CGEventSetDoubleValueField(e31, 134, phase);
    CGEventSetDoubleValueField(e31, 124, offset);
    Float32 ofsFloat32 = (Float32)offset;
    uint32_t ofsInt32;
    memcpy(&ofsInt32, &ofsFloat32, sizeof(ofsFloat32));
    CGEventSetIntegerValueField(e31, 135, (int64_t)ofsInt32);
    if (phase == kIOHIDEventPhaseEnded || phase == kIOHIDEventPhaseCancelled) {
        double exitSpeed = _lastDelta * 100.0;
        CGEventSetDoubleValueField(e31, 129, exitSpeed);
        CGEventSetDoubleValueField(e31, 130, exitSpeed);
    }
    CGEventPost(kCGSessionEventTap, e31);
    CGEventPost(kCGSessionEventTap, e29);
    CFRelease(e31);
    CFRelease(e29);
}

+ (void)suspend {}
+ (void)unsuspend {}

@end
