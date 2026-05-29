//
// --------------------------------------------------------------------------
// ConfigExporter.h
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface ConfigExporter : NSObject

+ (void)exportRemapsToJSON;
+ (void)importRemapsFromJSON;

@end

NS_ASSUME_NONNULL_END
