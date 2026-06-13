// --------------------------------------------------------------------------
// ProfileManager.swift
// Created for Mac Mouse Fix
// Created by Miguel Angelo 2026
// --------------------------------------------------------------------------

import Foundation
import AppKit
import CocoaLumberjackSwift

// MARK: - ProfileManager

/// Manages named profiles — snapshots of Remaps + Scroll + Pointer + relevant General settings.
/// Profiles are stored as .plist files in ~/Library/Application Support/com.virgoh.macmousefix/Profiles/

// Swift-friendly wrappers for the ObjC config functions
// (config/setConfig are bridged to take String in Swift)
private func configGet(_ keyPath: String) -> Any? {
    config(keyPath)
}
private func configSet(_ keyPath: String, _ value: NSObject) {
    setConfig(keyPath, value)
}

@objc class ProfileManager: NSObject {
    
    // MARK: Constants
    
    /// Keys saved into a profile (exclude State, License, Constants, and app-level General prefs)
    static let profileKeys = ["Remaps", "Scroll", "Pointer"]
    static let profileGeneralKeys = ["buttonKillSwitch", "scrollKillSwitch", "lockPointerDuringDrag", "primaryButtonModifierLayer"]
    
    // MARK: Storage path
    
    static var profilesDir: URL {
        /// Search all candidate app support locations to find the right one.
        /// Uses whichever folder contains config.plist (the authoritative indicator).
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let bundleID = Bundle.main.bundleIdentifier ?? "com.virgoh.mac-mouse-fix"
        let candidates = [
            bundleID,                                       // com.virgoh.mac-mouse-fix (with dashes)
            bundleID.replacingOccurrences(of: "-", with: ""), // com.virgoh.macmousefix (no dashes)
            "com.nuebling.mac-mouse-fix",                   // legacy Noah bundle ID
        ]
        // Pick whichever folder has config.plist
        for folder in candidates {
            let base = appSupport.appendingPathComponent(folder)
            if FileManager.default.fileExists(atPath: base.appendingPathComponent("config.plist").path) {
                let dir = base.appendingPathComponent("Profiles")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                return dir
            }
        }
        // Fallback: use the runtime bundle ID directly
        let fallback = appSupport.appendingPathComponent(bundleID).appendingPathComponent("Profiles")
        try? FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
        return fallback
    }
    
    static func urlForProfile(_ name: String) -> URL {
        profilesDir.appendingPathComponent(name).appendingPathExtension("plist")
    }
    
    // MARK: CRUD
    
    static func savedProfileNames() -> [String] {
        let files = (try? FileManager.default.contentsOfDirectory(at: profilesDir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { $0.pathExtension == "plist" }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
    }
    
    /// Save current config as a named profile
    @objc static func saveProfile(name: String) {
        var profileDict: [String: Any] = [:]
        
        // Save top-level keys
        for key in profileKeys {
            if let val = configGet(key) as? NSObject {
                profileDict[key] = val
            }
        }
        
        // Save relevant General keys
        var generalDict: [String: Any] = [:]
        for key in profileGeneralKeys {
            if let val = configGet("General." + key) as? NSObject {
                generalDict[key] = val
            }
        }
        if !generalDict.isEmpty {
            profileDict["General"] = generalDict
        }
        
        let url = urlForProfile(name)
        let data = try? PropertyListSerialization.data(fromPropertyList: profileDict,
                                                       format: .xml, options: 0)
        try? data?.write(to: url)
        DDLogInfo("ProfileManager: Saved profile '\(name)'")
    }
    
    /// Load a named profile into active config
    @objc static func loadProfile(name: String) -> Bool {
        let url = urlForProfile(name)
        guard let data = try? Data(contentsOf: url),
              let dict = try? PropertyListSerialization.propertyList(from: data, options: .mutableContainersAndLeaves, format: nil) as? [String: Any]
        else {
            DDLogError("ProfileManager: Failed to load profile '\(name)'")
            return false
        }
        
        // Restore top-level keys
        for key in profileKeys {
            if let val = dict[key] as? NSObject {
                configSet(key, val)
            }
        }
        
        // Restore relevant General keys
        if let generalDict = dict["General"] as? [String: Any] {
            for key in profileGeneralKeys {
                if let val = generalDict[key] as? NSObject {
                    configSet("General." + key, val)
                }
            }
        }
        
        commitConfig()
        
        // Reload the remap table UI
        DispatchQueue.main.async {
            MainAppState.shared.remapTableController?.reloadAll()
            MainAppState.shared.buttonTabController?.tableView.updateColumnWidths()
        }
        
        DDLogInfo("ProfileManager: Loaded profile '\(name)'")
        return true
    }
    
    /// Delete a named profile
    @objc static func deleteProfile(name: String) {
        try? FileManager.default.removeItem(at: urlForProfile(name))
        DDLogInfo("ProfileManager: Deleted profile '\(name)'")
    }
    
    // MARK: Save sheet helper
    
    /// Shows a sheet to get a profile name, then saves
    static func promptSaveProfile(in window: NSWindow, completion: @escaping (String?) -> Void) {
        let alert = NSAlert()
        alert.messageText = "Save Profile"
        alert.informativeText = "Enter a name for this profile:"
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        textField.placeholderString = "e.g. Work, Gaming, Laptop"
        alert.accessoryView = textField
        
        alert.beginSheetModal(for: window) { response in
            if response == .alertFirstButtonReturn {
                let name = textField.stringValue.trimmingCharacters(in: .whitespaces)
                if !name.isEmpty {
                    completion(name)
                    return
                }
            }
            completion(nil)
        }
    }
}
