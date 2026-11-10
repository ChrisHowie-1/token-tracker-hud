import Cocoa
import SwiftUI
import Combine
import ServiceManagement

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var contextMenu: NSMenu!
    private var hudWindow: FloatingHUDWindow?
    private var watcher = TokenStatsWatcher.shared
    private var cancellables = Set<AnyCancellable>()

    private let hudWidth: CGFloat = 336
    private let compactHeight: CGFloat = 158
    private let expandedBaseHeight: CGFloat = 236
    private let expandedFullHeight: CGFloat = 314
    private var lastAppliedHeight: CGFloat = 0

    private var launchAtLoginItem: NSMenuItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHUDWindow()
        bindWatcher()
        ensureLoginItemConfigured()
        AutoUpdater.shared.startPeriodicChecks()
    }

    private func targetWindowHeight(stats: TokenStats, isCompact: Bool) -> CGFloat {
        if isCompact {
            return compactHeight
        }
        return stats.hasThreePQuota ? expandedFullHeight : expandedBaseHeight
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.title = "⚡️ ..."
            button.action = #selector(menuBarClicked(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()

        let headerItem = NSMenuItem(title: "AI Quota & M3 Ultra Tracker", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        menu.addItem(NSMenuItem.separator())

        let toggleHUD = NSMenuItem(title: "Toggle Floating HUD", action: #selector(toggleHUDAction), keyEquivalent: "t")
        toggleHUD.target = self
        menu.addItem(toggleHUD)

        let toggleCompact = NSMenuItem(title: "Toggle Compact Mode", action: #selector(toggleCompactAction), keyEquivalent: "c")
        toggleCompact.target = self
        menu.addItem(toggleCompact)

        let snapTopRight = NSMenuItem(title: "Snap HUD to Top-Right", action: #selector(snapTopRightAction), keyEquivalent: "r")
        snapTopRight.target = self
        menu.addItem(snapTopRight)

        menu.addItem(NSMenuItem.separator())

        let loginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLoginAction), keyEquivalent: "l")
        loginItem.target = self
        loginItem.state = isLaunchAtLoginEnabled() ? .on : .off
        self.launchAtLoginItem = loginItem
        menu.addItem(loginItem)

        let refreshNow = NSMenuItem(title: "Refresh Telemetry", action: #selector(refreshAction), keyEquivalent: "")
        refreshNow.target = self
        menu.addItem(refreshNow)

        let updateItem = NSMenuItem(title: "Check for Updates", action: #selector(checkForUpdatesAction), keyEquivalent: "u")
        updateItem.target = self
        menu.addItem(updateItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit TokenTrackerHUD", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        // Keep statusItem.menu nil at rest so AppKit delivers left-clicks to menuBarClicked(_:)
        self.contextMenu = menu
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        let plistPath = ("~/Library/LaunchAgents/com.antigravity.tokentracker.app.plist" as NSString).expandingTildeInPath
        return FileManager.default.fileExists(atPath: plistPath)
    }

    private func ensureLoginItemConfigured() {
        if #available(macOS 13.0, *) {
            if SMAppService.mainApp.status != .enabled {
                try? SMAppService.mainApp.register()
            }
        }
        launchAtLoginItem?.state = isLaunchAtLoginEnabled() ? .on : .off
    }

    @objc private func toggleLaunchAtLoginAction() {
        if #available(macOS 13.0, *) {
            let service = SMAppService.mainApp
            if service.status == .enabled {
                try? service.unregister()
            } else {
                try? service.register()
            }
            launchAtLoginItem?.state = (service.status == .enabled) ? .on : .off
        }
    }

    private func setupHUDWindow() {
        guard let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let initialHeight = targetWindowHeight(stats: watcher.stats, isCompact: watcher.isCompact)
        lastAppliedHeight = initialHeight
        let initialX = screenRect.maxX - hudWidth - 20
        let initialY = screenRect.maxY - initialHeight - 20

        let rect = NSRect(x: initialX, y: initialY, width: hudWidth, height: initialHeight)
        let window = FloatingHUDWindow(contentRect: rect)

        let rootView = FloatingHUDView(watcher: watcher)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]
        hostingView.wantsLayer = true
        hostingView.layer?.cornerRadius = 20
        hostingView.layer?.cornerCurve = .continuous
        hostingView.layer?.masksToBounds = true

        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        window.invalidateShadow()
        self.hudWindow = window
    }

    private func bindWatcher() {
        Publishers.CombineLatest(watcher.$stats, watcher.$isOffline)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats, isOffline in
                guard let self = self else { return }
                self.updateStatusButton(stats: stats, isOffline: isOffline)
                let desired = self.targetWindowHeight(stats: stats, isCompact: self.watcher.isCompact)
                if abs(desired - self.lastAppliedHeight) > 1 {
                    self.animateWindowResize(targetHeight: desired)
                }
            }
            .store(in: &cancellables)

        watcher.$isHUDVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                if visible {
                    self?.hudWindow?.orderFront(nil)
                    self?.hudWindow?.invalidateShadow()
                } else {
                    self?.hudWindow?.orderOut(nil)
                }
            }
            .store(in: &cancellables)

        watcher.$isCompact
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isCompact in
                guard let self = self else { return }
                let desired = self.targetWindowHeight(stats: self.watcher.stats, isCompact: isCompact)
                self.animateWindowResize(targetHeight: desired)
            }
            .store(in: &cancellables)
    }

    private func updateStatusButton(stats: TokenStats, isOffline: Bool) {
        guard let button = statusItem.button else { return }

        let lowest = stats.lowestRemainingPct
        let tag = stats.lowestTag
        let pctStr = String(format: "%.0f%%", lowest)
        let icon: String
        if isOffline {
            icon = "⚪️"
        } else if stats.isBusy == true {
            icon = "⚡️"
        } else {
            icon = "🟢"
        }

        let font = NSFont.systemFont(ofSize: 13, weight: .medium)
        let boldFont = NSFont.systemFont(ofSize: 12, weight: .bold)

        let attrTitle = NSMutableAttributedString()
        attrTitle.append(NSAttributedString(string: "\(icon) \(pctStr) ", attributes: [
            .font: font,
            .foregroundColor: isOffline ? NSColor.secondaryLabelColor : NSColor.labelColor
        ]))
        attrTitle.append(NSAttributedString(string: tag, attributes: [
            .font: boldFont,
            .foregroundColor: isOffline ? NSColor.secondaryLabelColor : statusColor(for: lowest)
        ]))

        button.attributedTitle = attrTitle

        var tipLines = [
            isOffline ? "AI Quota Tracker (Offline - Cached)" : "AI Quota Tracker (Live Sync)",
            String(format: "Gemini — 5h: %.0f%% | 7d: %.0f%%", stats.calculated5hRemainingPct, stats.calculatedWeeklyRemainingPct)
        ]
        if stats.hasThreePQuota {
            tipLines.append(String(format: "Claude/GPT — 5h: %.0f%% | 7d: %.0f%%", stats.calculated3p5hRemainingPct, stats.calculated3pWeeklyRemainingPct))
        }
        tipLines.append("M3 Ultra — \(stats.formattedSavings) saved (\(stats.formattedFreeTokens) tok · \(stats.formattedSpeed))")
        tipLines.append("Left-click: Toggle HUD · Right-click: Menu")
        button.toolTip = tipLines.joined(separator: "\n")
    }

    private func statusColor(for pct: Double) -> NSColor {
        if pct >= 50.0 {
            return NSColor(red: 0.22, green: 0.88, blue: 0.45, alpha: 1.0)
        } else if pct >= 20.0 {
            return NSColor(red: 1.0, green: 0.58, blue: 0.20, alpha: 1.0)
        } else {
            return NSColor(red: 1.0, green: 0.30, blue: 0.30, alpha: 1.0)
        }
    }

    private func animateWindowResize(targetHeight: CGFloat) {
        guard let window = hudWindow else { return }
        lastAppliedHeight = targetHeight
        let currentFrame = window.frame
        let topY = currentFrame.origin.y + currentFrame.height
        let newOriginY = topY - targetHeight

        let newFrame = NSRect(
            x: currentFrame.origin.x,
            y: newOriginY,
            width: hudWidth,
            height: targetHeight
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().setFrame(newFrame, display: true)
        } completionHandler: {
            window.invalidateShadow()
        }
    }

    @objc private func menuBarClicked(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else {
            watcher.toggleVisibility()
            return
        }
        if event.type == .rightMouseUp || event.modifierFlags.contains(.control) {
            statusItem.menu = contextMenu
            sender.performClick(nil)
            DispatchQueue.main.async { [weak self] in
                self?.statusItem.menu = nil
            }
        } else {
            watcher.toggleVisibility()
        }
    }

    @objc private func toggleHUDAction() {
        watcher.toggleVisibility()
    }

    @objc private func toggleCompactAction() {
        watcher.toggleCompact()
    }

    @objc private func snapTopRightAction() {
        guard let window = hudWindow, let screen = NSScreen.main else { return }
        let screenRect = screen.visibleFrame
        let targetHeight = targetWindowHeight(stats: watcher.stats, isCompact: watcher.isCompact)
        lastAppliedHeight = targetHeight
        let newX = screenRect.maxX - hudWidth - 20
        let newY = screenRect.maxY - targetHeight - 20
        window.setFrame(NSRect(x: newX, y: newY, width: hudWidth, height: targetHeight), display: true, animate: true)
        window.invalidateShadow()
        if !watcher.isHUDVisible {
            watcher.isHUDVisible = true
        }
    }

    @objc private func refreshAction() {
        watcher.loadStats()
    }

    @objc private func checkForUpdatesAction() {
        AutoUpdater.shared.checkForUpdates(manual: true)
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
