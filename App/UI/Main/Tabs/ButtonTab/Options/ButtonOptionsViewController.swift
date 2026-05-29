//
// --------------------------------------------------------------------------
// ButtonOptionsViewController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Created by Noah Nuebling in 2022
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//

import Cocoa
import ReactiveCocoa
import ReactiveSwift

class ButtonOptionsViewController: NSViewController {

    /// Vars
    
    static var instance: ButtonOptionsViewController? = nil
    
    var lockPointer = ConfigValue<Bool>(configPath: "General.lockPointerDuringDrag")
    var primaryButtonModLayer = ConfigValue<Bool>(configPath: "General.primaryButtonModifierLayer")
    var showMenuBarItem = ConfigValue<Bool>(configPath: "General.showMenuBarItem")
    
    /// IB outlets & actions
    
    @IBOutlet weak var doneButton: NSButton!
    @IBOutlet weak var lockPointerButton: NSButton!
    
    /// Programmatic toggles
    private var primaryButtonModLayerButton: NSButton!
    private var showMenuBarButton: NSButton!
        
    @IBAction func done(_ sender: Any) {
        ButtonOptionsViewController.remove()
    }
    
    /// Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        lockPointerButton.reactive.boolValue <~ lockPointer
        lockPointer <~ lockPointerButton.reactive.boolValues
        
        /// Add extra toggles programmatically below the existing ones
        let stack = lockPointerButton.superview as? NSStackView ?? {
            /// If not already in a stack, wrap existing content
            let s = NSStackView()
            s.orientation = .vertical
            s.alignment = .leading
            s.spacing = 8
            return s
        }()
        
        /// Primary Button Modifier Layer toggle
        primaryButtonModLayerButton = NSButton(checkboxWithTitle: "Primary button modifier layer (hold thumb → remap L/R click)", target: nil, action: nil)
        primaryButtonModLayerButton.toolTip = "When enabled, holding button 4/5/6 lets you remap left and right click to different actions"
        primaryButtonModLayerButton.reactive.boolValue <~ primaryButtonModLayer
        primaryButtonModLayer <~ primaryButtonModLayerButton.reactive.boolValues
        
        /// Show Menu Bar Item toggle
        showMenuBarButton = NSButton(checkboxWithTitle: "Show menu bar icon (with active modifier indicator)", target: nil, action: nil)
        showMenuBarButton.toolTip = "Shows the Mac Mouse Fix icon in the menu bar. Displays which button modifier is active."
        showMenuBarButton.reactive.boolValue <~ showMenuBarItem
        showMenuBarItem <~ showMenuBarButton.reactive.boolValues
        
        /// Insert into the view hierarchy
        if let existingStack = lockPointerButton.superview as? NSStackView {
            existingStack.addArrangedSubview(primaryButtonModLayerButton)
            existingStack.addArrangedSubview(showMenuBarButton)
        } else {
            /// Fallback: add below lockPointerButton manually
            let container = lockPointerButton.superview!
            primaryButtonModLayerButton.translatesAutoresizingMaskIntoConstraints = false
            showMenuBarButton.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(primaryButtonModLayerButton)
            container.addSubview(showMenuBarButton)
            NSLayoutConstraint.activate([
                primaryButtonModLayerButton.leadingAnchor.constraint(equalTo: lockPointerButton.leadingAnchor),
                primaryButtonModLayerButton.topAnchor.constraint(equalTo: lockPointerButton.bottomAnchor, constant: 8),
                showMenuBarButton.leadingAnchor.constraint(equalTo: lockPointerButton.leadingAnchor),
                showMenuBarButton.topAnchor.constraint(equalTo: primaryButtonModLayerButton.bottomAnchor, constant: 8),
            ])
        }
        
        /// Adjust views for Tahoe
        if #available(macOS 26.0, *) {
            self.view.prefersCompactControlSizeMetrics = true;
        }
    }
    
    /// Interface
    
    @objc static func add() {
        
        /// Create new instance every time. Otherwise the done button won't be blue after the first open
        instance?.nibBundle?.unload()
        instance = nil
        instance = ButtonOptionsViewController(nibName: "ButtonOptionsViewController", bundle: Bundle.main)
        
        /// Open sheet
        guard let tabViewController = MainAppState.shared.tabViewController else { assert(false); return }
        tabViewController.presentAsSheet(instance!)
    }
    
    @objc static func remove() {
        
        /// Close sheet
        guard let tabViewController = MainAppState.shared.tabViewController else { assert(false); return }
        tabViewController.dismiss(instance!)
    }
    
    
    
}
