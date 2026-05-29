//
// --------------------------------------------------------------------------
// ModTapCoordinator.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Smart modifier detection: delays thumb button action to detect modifier intent
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import "Device.h"
#import "Constants.h"
#import "ButtonInputReceiver.h"

NS_ASSUME_NONNULL_BEGIN

/// State of the mod-tap state machine
typedef enum {
    kModTapStateIdle,           /// No modifier button held
    kModTapStateUndecided,     /// Modifier button pressed, waiting to see if primary follows
    kModTapStateModifier,      /// Committed as modifier (primary button was pressed)
    kModTapStateTap,           /// Committed as tap (released quickly, no primary pressed)
} ModTapState;

@interface ModTapCoordinator : NSObject

+ (instancetype)shared;

/// Called by ButtonInputReceiver for ALL button events.
/// Returns YES if the event was consumed (held/deferred). Returns NO if it should be processed normally.
- (BOOL)handleButtonInput:(NSUInteger)buttonNumber
                   device:(Device *)device
                 mouseDown:(BOOL)mouseDown
                    event:(CGEventRef)event;

/// Configuration
@property (nonatomic) NSTimeInterval tappingTerm; /// Default 180ms

@end

NS_ASSUME_NONNULL_END
