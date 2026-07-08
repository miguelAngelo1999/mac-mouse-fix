//
// --------------------------------------------------------------------------
// AppsTabController.swift
// Created for Mac Mouse Fix (https://github.com/noah-nuebling/mac-mouse-fix)
// Licensed under the MMF License (https://github.com/noah-nuebling/mac-mouse-fix/blob/master/License)
// --------------------------------------------------------------------------
//
// Per-app configuration tab. Lets users override scroll and pointer settings
// for specific applications (e.g. disable smooth scrolling in games).
//

import Cocoa
import CocoaLumberjackSwift

// MARK: - Model

/// Keys used in AppOverrides config
private let kAppOverrideDisableMMF = "General.disableMouseFix"
private let kAppOverrideDisableSmooth = "Scroll.smooth"
private let kAppOverrideScrollSpeed = "Scroll.speed"

// MARK: - App Row Model

private class AppRow: NSObject {
    var bundleID: String
    var icon: NSImage?
    var displayName: String
    
    /// Per-app override values
    var disableMMF: Bool = false
    var disableSmooth: Bool = false
    var scrollSpeedMultiplier: Double = 1.0
    
    init(bundleID: String) {
        self.bundleID = bundleID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            displayName = (url.deletingPathExtension().lastPathComponent)
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            displayName = bundleID
            icon = NSWorkspace.shared.icon(forFileType: "app")
        }
    }
}

// MARK: - Controller

class AppsTabController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    
    // MARK: Vars
    
    private var rows: [AppRow] = []
    private var tableView: NSTableView!
    private var detailStack: NSStackView!
    private var disableMMFCheck: NSButton!
    private var disableSmoothCheck: NSButton!
    private var speedSlider: NSSlider!
    private var speedLabel: NSTextField!
    private var noSelectionLabel: NSTextField!
    
    // MARK: Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        buildUI()
        loadFromConfig()
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        loadFromConfig()
    }
    
    // MARK: UI Construction
    
    private func buildUI() {
        
        let container = NSStackView()
        container.orientation = .horizontal
        container.alignment = .top
        container.spacing = 16
        container.translatesAutoresizingMaskIntoConstraints = false
        container.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)
        view.addSubview(container)
        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: view.topAnchor),
            container.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
        
        // MARK: Left column — app list
        
        let leftStack = NSStackView()
        leftStack.orientation = .vertical
        leftStack.alignment = .leading
        leftStack.spacing = 8
        
        let listLabel = NSTextField(labelWithString: NSLocalizedString("apps-tab.list-label", value: "App Overrides", comment: ""))
        listLabel.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
        leftStack.addArrangedSubview(listLabel)
        
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        tableView = NSTableView()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.headerView = nil
        tableView.allowsMultipleSelection = false
        tableView.rowHeight = 28
        
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        col.title = "App"
        tableView.addTableColumn(col)
        
        scrollView.documentView = tableView
        scrollView.widthAnchor.constraint(equalToConstant: 180).isActive = true
        scrollView.heightAnchor.constraint(equalToConstant: 280).isActive = true
        leftStack.addArrangedSubview(scrollView)
        
        // Add / Remove buttons
        let buttonRow = NSStackView()
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 4
        
        let addBtn = NSButton(title: "+", target: self, action: #selector(addApp))
        addBtn.bezelStyle = .roundRect
        addBtn.toolTip = NSLocalizedString("apps-tab.add-tooltip", value: "Add a running app", comment: "")
        
        let removeBtn = NSButton(title: "−", target: self, action: #selector(removeApp))
        removeBtn.bezelStyle = .roundRect
        removeBtn.toolTip = NSLocalizedString("apps-tab.remove-tooltip", value: "Remove override for selected app", comment: "")
        
        buttonRow.addArrangedSubview(addBtn)
        buttonRow.addArrangedSubview(removeBtn)
        leftStack.addArrangedSubview(buttonRow)
        
        container.addArrangedSubview(leftStack)
        
        // MARK: Right column — detail panel
        
        let rightStack = NSStackView()
        rightStack.orientation = .vertical
        rightStack.alignment = .leading
        rightStack.spacing = 14
        
        noSelectionLabel = NSTextField(labelWithString: NSLocalizedString("apps-tab.no-selection", value: "Select an app to configure overrides.", comment: ""))
        noSelectionLabel.textColor = .secondaryLabelColor
        noSelectionLabel.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        rightStack.addArrangedSubview(noSelectionLabel)
        
        detailStack = NSStackView()
        detailStack.orientation = .vertical
        detailStack.alignment = .leading
        detailStack.spacing = 12
        detailStack.isHidden = true
        
        // Disable MMF for this app
        disableMMFCheck = NSButton(checkboxWithTitle: NSLocalizedString("apps-tab.disable-mmf", value: "Disable Mac Mouse Fix for this app", comment: ""), target: self, action: #selector(overrideChanged))
        detailStack.addArrangedSubview(disableMMFCheck)
        
        // Separator
        let sep1 = NSBox()
        sep1.boxType = .separator
        sep1.translatesAutoresizingMaskIntoConstraints = false
        detailStack.addArrangedSubview(sep1)
        sep1.widthAnchor.constraint(equalToConstant: 200).isActive = true
        
        // Disable smooth scrolling
        disableSmoothCheck = NSButton(checkboxWithTitle: NSLocalizedString("apps-tab.disable-smooth", value: "Disable smooth scrolling", comment: ""), target: self, action: #selector(overrideChanged))
        detailStack.addArrangedSubview(disableSmoothCheck)
        
        // Scroll speed
        let speedRow = NSStackView()
        speedRow.orientation = .horizontal
        speedRow.spacing = 8
        
        let speedTitle = NSTextField(labelWithString: NSLocalizedString("apps-tab.scroll-speed", value: "Scroll speed:", comment: ""))
        speedSlider = NSSlider(value: 1.0, minValue: 0.1, maxValue: 3.0, target: self, action: #selector(overrideChanged))
        speedSlider.numberOfTickMarks = 0
        speedSlider.isContinuous = true
        speedSlider.widthAnchor.constraint(equalToConstant: 100).isActive = true
        
        speedLabel = NSTextField(labelWithString: "1.0×")
        speedLabel.widthAnchor.constraint(equalToConstant: 32).isActive = true
        
        speedRow.addArrangedSubview(speedTitle)
        speedRow.addArrangedSubview(speedSlider)
        speedRow.addArrangedSubview(speedLabel)
        detailStack.addArrangedSubview(speedRow)
        
        rightStack.addArrangedSubview(detailStack)
        container.addArrangedSubview(rightStack)
        
        // Listen for table selection changes
        NotificationCenter.default.addObserver(self, selector: #selector(selectionChanged), name: NSTableView.selectionDidChangeNotification, object: tableView)
    }
    
    // MARK: Load / Save
    
    private func loadFromConfig() {
        let overrides = (Config.shared().config[kMFConfigKeyAppOverrides] as? NSDictionary) ?? NSDictionary()
        
        rows = overrides.allKeys.compactMap { key in
            guard let bundleID = key as? String else { return nil }
            let row = AppRow(bundleID: bundleID)
            let root = (overrides[bundleID] as? NSDictionary)?["Root"] as? NSDictionary ?? NSDictionary()
            row.disableMMF = (root[kAppOverrideDisableMMF] as? Bool) ?? false
            row.disableSmooth = !((root[kAppOverrideDisableSmooth] as? Bool) ?? true)
            row.scrollSpeedMultiplier = (root[kAppOverrideScrollSpeed] as? Double) ?? 1.0
            return row
        }.sorted { $0.displayName < $1.displayName }
        
        tableView?.reloadData()
        updateDetail()
    }
    
    private func saveToConfig() {
        guard let row = selectedRow() else { return }
        let bundleIDEscaped = row.bundleID.replacingOccurrences(of: ".", with: "\\.")
        
        if row.disableMMF {
            setConfig("AppOverrides.\(bundleIDEscaped).Root.\(kAppOverrideDisableMMF)", true as NSObject)
        } else {
            removeFromConfig("AppOverrides.\(bundleIDEscaped).Root.\(kAppOverrideDisableMMF)")
        }
        
        if row.disableSmooth {
            setConfig("AppOverrides.\(bundleIDEscaped).Root.\(kAppOverrideDisableSmooth)", false as NSObject)
        } else {
            removeFromConfig("AppOverrides.\(bundleIDEscaped).Root.\(kAppOverrideDisableSmooth)")
        }
        
        if abs(row.scrollSpeedMultiplier - 1.0) > 0.01 {
            setConfig("AppOverrides.\(bundleIDEscaped).Root.\(kAppOverrideScrollSpeed)", row.scrollSpeedMultiplier as NSObject)
        } else {
            removeFromConfig("AppOverrides.\(bundleIDEscaped).Root.\(kAppOverrideScrollSpeed)")
        }
        
        commitConfig()
    }
    
    // MARK: Actions
    
    @objc private func addApp() {
        /// Show a menu of running apps to add
        let menu = NSMenu()
        
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
        
        for app in runningApps {
            guard let bundleID = app.bundleIdentifier else { continue }
            if rows.contains(where: { $0.bundleID == bundleID }) { continue }
            
            let item = NSMenuItem(title: app.localizedName ?? bundleID, action: #selector(addAppFromMenu(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = bundleID
            if let icon = app.icon {
                icon.size = NSSize(width: 16, height: 16)
                item.image = icon
            }
            menu.addItem(item)
        }
        
        if menu.items.isEmpty {
            let empty = NSMenuItem(title: NSLocalizedString("apps-tab.no-apps", value: "No new apps to add", comment: ""), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        
        let btn = view.window?.contentView?.hitTest(NSEvent.mouseLocation) ?? view
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: 0), in: btn)
    }
    
    @objc private func addAppFromMenu(_ sender: NSMenuItem) {
        guard let bundleID = sender.representedObject as? String else { return }
        let row = AppRow(bundleID: bundleID)
        rows.append(row)
        rows.sort { $0.displayName < $1.displayName }
        
        /// Create empty override entry so the app appears in config
        let bundleIDEscaped = bundleID.replacingOccurrences(of: ".", with: "\\.")
        setConfig("AppOverrides.\(bundleIDEscaped).meta.addedByUser", true as NSObject)
        commitConfig()
        
        tableView.reloadData()
        if let idx = rows.firstIndex(where: { $0.bundleID == bundleID }) {
            tableView.selectRowIndexes(IndexSet(integer: idx), byExtendingSelection: false)
        }
        updateDetail()
    }
    
    @objc private func removeApp() {
        guard let row = selectedRow(),
              let idx = rows.firstIndex(where: { $0.bundleID == row.bundleID }) else { return }
        
        /// Remove entire override entry from config
        let bundleIDEscaped = row.bundleID.replacingOccurrences(of: ".", with: "\\.")
        removeFromConfig("AppOverrides.\(bundleIDEscaped)")
        commitConfig()
        
        rows.remove(at: idx)
        tableView.reloadData()
        updateDetail()
    }
    
    @objc private func overrideChanged() {
        guard let row = selectedRow() else { return }
        row.disableMMF = disableMMFCheck.state == .on
        row.disableSmooth = disableSmoothCheck.state == .on
        row.scrollSpeedMultiplier = speedSlider.doubleValue
        speedLabel.stringValue = String(format: "%.1f×", row.scrollSpeedMultiplier)
        saveToConfig()
    }
    
    @objc private func selectionChanged() {
        updateDetail()
    }
    
    // MARK: Detail panel update
    
    private func updateDetail() {
        guard let row = selectedRow() else {
            detailStack.isHidden = true
            noSelectionLabel.isHidden = false
            return
        }
        
        detailStack.isHidden = false
        noSelectionLabel.isHidden = true
        
        disableMMFCheck.state = row.disableMMF ? .on : .off
        disableSmoothCheck.state = row.disableSmooth ? .on : .off
        speedSlider.doubleValue = row.scrollSpeedMultiplier
        speedLabel.stringValue = String(format: "%.1f×", row.scrollSpeedMultiplier)
        
        /// Grey out smooth/speed controls if MMF is disabled for this app
        disableSmoothCheck.isEnabled = !row.disableMMF
        speedSlider.isEnabled = !row.disableMMF
    }
    
    private func selectedRow() -> AppRow? {
        let idx = tableView?.selectedRow ?? -1
        guard idx >= 0 && idx < rows.count else { return nil }
        return rows[idx]
    }
    
    // MARK: NSTableViewDataSource
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        rows.count
    }
    
    // MARK: NSTableViewDelegate
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < rows.count else { return nil }
        let app = rows[row]
        
        let cell = NSTableCellView()
        cell.imageView = NSImageView()
        cell.imageView!.image = app.icon
        cell.imageView!.translatesAutoresizingMaskIntoConstraints = false
        
        cell.textField = NSTextField(labelWithString: app.displayName)
        cell.textField!.translatesAutoresizingMaskIntoConstraints = false
        cell.textField!.lineBreakMode = .byTruncatingTail
        
        cell.addSubview(cell.imageView!)
        cell.addSubview(cell.textField!)
        
        NSLayoutConstraint.activate([
            cell.imageView!.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            cell.imageView!.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            cell.imageView!.widthAnchor.constraint(equalToConstant: 18),
            cell.imageView!.heightAnchor.constraint(equalToConstant: 18),
            cell.textField!.leadingAnchor.constraint(equalTo: cell.imageView!.trailingAnchor, constant: 6),
            cell.textField!.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
            cell.textField!.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
        ])
        
        return cell
    }
}
