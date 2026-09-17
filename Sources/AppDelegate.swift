import Cocoa
import SwiftUI
import Combine
import ServiceManagement

public class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var hudWindow: FloatingHUDWindow?
    private var watcher = TokenStatsWatcher.shared
    private var cancellables = Set<AnyCancellable>()

    private let hudWidth: CGFloat = 330
    private let compactHeight: CGFloat = 136
    private let expandedHeight: CGFloat = 228

    private var launchAtLoginItem: NSMenuItem?

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        setupHUDWindow()
        bindWatcher()
        ensureLoginItemConfigured()
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

        let headerItem = NSMenuItem(title: "Gemini Models Quota Tracker", action: nil, keyEquivalent: "")
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

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit TokenTrackerHUD", action: #selector(quitAction), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func isLaunchAtLoginEnabled() -> Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        let plistPath = ("~/Library/LaunchAgents/com.antigravity.tokentracker.plist" as NSString).expandingTildeInPath
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
        let initialX = screenRect.maxX - hudWidth - 20
        let initialY = screenRect.maxY - expandedHeight - 20

        let rect = NSRect(x: initialX, y: initialY, width: hudWidth, height: expandedHeight)
        let window = FloatingHUDWindow(contentRect: rect)

        let rootView = FloatingHUDView(watcher: watcher)
        let hostingView = NSHostingView(rootView: rootView)
        hostingView.autoresizingMask = [.width, .height]

        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        self.hudWindow = window
    }

    private func bindWatcher() {
        watcher.$stats
            .receive(on: DispatchQueue.main)
            .sink { [weak self] stats in
                let remaining = stats.calculated5hRemainingPct
                let pctStr = String(format: "%.0f%%", remaining)
                let icon = stats.isBusy == true ? "⚡️" : "🟢"
                self?.statusItem.button?.title = "\(icon) \(pctStr)"
            }
            .store(in: &cancellables)

        watcher.$isHUDVisible
            .receive(on: DispatchQueue.main)
            .sink { [weak self] visible in
                if visible {
                    self?.hudWindow?.orderFront(nil)
                } else {
                    self?.hudWindow?.orderOut(nil)
                }
            }
            .store(in: &cancellables)

        watcher.$isCompact
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isCompact in
                self?.animateWindowResize(isCompact: isCompact)
            }
            .store(in: &cancellables)
    }

    private func animateWindowResize(isCompact: Bool) {
        guard let window = hudWindow else { return }
        let targetHeight = isCompact ? compactHeight : expandedHeight
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
        }
    }

    @objc private func menuBarClicked(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent {
            if event.type == .rightMouseUp {
                statusItem.menu?.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
            } else {
                watcher.toggleVisibility()
            }
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
        let targetHeight = watcher.isCompact ? compactHeight : expandedHeight
        let newX = screenRect.maxX - hudWidth - 20
        let newY = screenRect.maxY - targetHeight - 20
        window.setFrame(NSRect(x: newX, y: newY, width: hudWidth, height: targetHeight), display: true, animate: true)
        if !watcher.isHUDVisible {
            watcher.isHUDVisible = true
        }
    }

    @objc private func refreshAction() {
        watcher.loadStats()
    }

    @objc private func quitAction() {
        NSApplication.shared.terminate(nil)
    }
}
