import Foundation
import AppKit

public class AutoUpdater {
    public static let shared = AutoUpdater()

    private let icloudAppURL: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Antigravity Projects/Misc/TokenTrackerHUD/build/TokenTrackerHUD.app")
    }()

    private var updateTimer: Timer?
    private var isUpdating = false

    public func startPeriodicChecks() {
        checkForUpdates()
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
    }

    public func checkForUpdates(manual: Bool = false) {
        DispatchQueue.global(qos: .background).async { [weak self] in
            guard let self = self, !self.isUpdating else { return }

            let currentURL = Bundle.main.bundleURL.standardizedFileURL
            let sourceURL = self.icloudAppURL.standardizedFileURL

            // Don't auto-update if already running directly from the iCloud build directory
            if currentURL == sourceURL {
                return
            }

            let sourceBinary = sourceURL.appendingPathComponent("Contents/MacOS/TokenTrackerHUD")
            let currentBinary = currentURL.appendingPathComponent("Contents/MacOS/TokenTrackerHUD")

            guard FileManager.default.fileExists(atPath: sourceBinary.path),
                  FileManager.default.isExecutableFile(atPath: sourceBinary.path) else {
                return
            }

            guard let sourceAttrs = try? FileManager.default.attributesOfItem(atPath: sourceBinary.path),
                  let sourceSize = sourceAttrs[.size] as? Int64, sourceSize > 100_000,
                  let sourceDate = sourceAttrs[.modificationDate] as? Date else {
                return
            }

            guard let currentAttrs = try? FileManager.default.attributesOfItem(atPath: currentBinary.path),
                  let currentDate = currentAttrs[.modificationDate] as? Date else {
                return
            }

            if sourceDate.timeIntervalSince(currentDate) > 2.0 {
                self.isUpdating = true
                self.performUpdate(from: sourceURL, to: currentURL)
            }
        }
    }

    private func performUpdate(from source: URL, to destination: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let destPath = destination.path
        let srcPath = source.path

        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf "\(destPath)"
        cp -R "\(srcPath)" "\(destPath)"
        xattr -cr "\(destPath)"
        open "\(destPath)"
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]

        do {
            try process.run()
            DispatchQueue.main.async {
                NSApplication.shared.terminate(nil)
            }
        } catch {
            self.isUpdating = false
        }
    }
}
