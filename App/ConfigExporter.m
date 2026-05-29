//
// --------------------------------------------------------------------------
// ConfigExporter.m
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Import/export button configurations as JSON
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

#import "ConfigExporter.h"
#import "Config.h"
#import "Constants.h"
#import <AppKit/AppKit.h>
#import <UniformTypeIdentifiers/UniformTypeIdentifiers.h>

@implementation ConfigExporter

+ (void)exportRemapsToJSON {
    /// Present a save panel and export the current remaps as JSON
    
    NSArray *remaps = Config.shared.config[kMFConfigKeyRemaps];
    if (!remaps) {
        NSLog(@"ConfigExporter: No remaps to export");
        return;
    }
    
    NSError *error = nil;
    NSData *jsonData = [NSJSONSerialization dataWithJSONObject:remaps
                                                      options:NSJSONWritingPrettyPrinted | NSJSONWritingSortedKeys
                                                        error:&error];
    if (error || !jsonData) {
        NSLog(@"ConfigExporter: Failed to serialize remaps: %@", error);
        return;
    }
    
    NSSavePanel *panel = [NSSavePanel savePanel];
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"json"]];
    panel.nameFieldStringValue = @"mmf-button-config.json";
    panel.title = @"Export Button Configuration";
    
    [panel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result == NSModalResponseOK && panel.URL) {
            NSError *writeError = nil;
            [jsonData writeToURL:panel.URL options:NSDataWritingAtomic error:&writeError];
            if (writeError) {
                NSLog(@"ConfigExporter: Failed to write file: %@", writeError);
            }
        }
    }];
}

+ (void)importRemapsFromJSON {
    /// Present an open panel and import remaps from a JSON file
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    panel.allowedContentTypes = @[[UTType typeWithFilenameExtension:@"json"]];
    panel.allowsMultipleSelection = NO;
    panel.title = @"Import Button Configuration";
    
    [panel beginWithCompletionHandler:^(NSModalResponse result) {
        if (result != NSModalResponseOK || !panel.URL) return;
        
        NSError *error = nil;
        NSData *data = [NSData dataWithContentsOfURL:panel.URL options:0 error:&error];
        if (error || !data) {
            NSLog(@"ConfigExporter: Failed to read file: %@", error);
            return;
        }
        
        id parsed = [NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&error];
        if (error || !parsed) {
            NSLog(@"ConfigExporter: Failed to parse JSON: %@", error);
            return;
        }
        
        if (![parsed isKindOfClass:[NSArray class]]) {
            NSLog(@"ConfigExporter: Expected JSON array at top level");
            return;
        }
        
        /// Apply the imported remaps
        setConfig(kMFConfigKeyRemaps, parsed);
        commitConfig();
        
        /// Notify user
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Import Successful";
            alert.informativeText = @"Button configuration has been imported. The remaps table will reload.";
            alert.alertStyle = NSAlertStyleInformational;
            [alert runModal];
            
            /// Post notification to reload UI
            [[NSNotificationCenter defaultCenter] postNotificationName:@"MFConfigImported" object:nil];
        });
    }];
}

@end
