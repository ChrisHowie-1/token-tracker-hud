import Foundation
import AppKit
import CryptoKit

private struct RemoteAppVersion: Codable {
    let available: Bool
    let binaryMtime: Double?
    let binarySize: Int64?
    let binarySha256: String?
    let bundleUrl: String?

    enum CodingKeys: String, CodingKey {
        case available
        case binaryMtime = "binary_mtime"
        case binarySize = "binary_size"
        case binarySha256 = "binary_sha256"
        case bundleUrl = "bundle_url"
    }
}

public class AutoUpdater {
    public static let shared = AutoUpdater()

    private let versionURL = URL(string: "http://192.168.32.90:9587/app/version")!
    private let buildSourceBundlePath = "/Users/chrishowie/Antigravity/Personal/Misc/TokenTrackerHUD/build/TokenTrackerHUD.app"

    private var updateTimer: Timer?
    private var isUpdating = false

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 5.0
        config.timeoutIntervalForResource = 30.0
        return URLSession(configuration: config)
    }()

    public func startPeriodicChecks() {
        checkForUpdates()
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: 300.0, repeats: true) { [weak self] _ in
            self?.checkForUpdates()
        }
    }

    private func sha256Hex(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public func checkForUpdates(manual: Bool = false) {
        let currentBundleURL = Bundle.main.bundleURL.standardizedFileURL
        // Never self-update if running directly out of the build staging folder
        if currentBundleURL.path == URL(fileURLWithPath: buildSourceBundlePath).standardizedFileURL.path {
            return
        }

        guard !isUpdating else { return }

        session.dataTask(with: versionURL) { [weak self] data, response, error in
            guard let self = self,
                  !self.isUpdating,
                  error == nil,
                  let data = data,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200,
                  let meta = try? JSONDecoder().decode(RemoteAppVersion.self, from: data),
                  meta.available,
                  let remoteHash = meta.binarySha256,
                  let remoteMtime = meta.binaryMtime,
                  let bundleUrlStr = meta.bundleUrl,
                  let bundleURL = URL(string: bundleUrlStr) else {
                return
            }

            guard let execURL = Bundle.main.executableURL,
                  let localHash = self.sha256Hex(of: execURL),
                  let localAttrs = try? FileManager.default.attributesOfItem(atPath: execURL.path),
                  let localDate = localAttrs[.modificationDate] as? Date else {
                return
            }

            if localHash != remoteHash && (remoteMtime - localDate.timeIntervalSince1970) > 2.0 {
                self.isUpdating = true
                self.downloadAndInstall(from: bundleURL, expectedBinarySha256: remoteHash, destinationBundle: currentBundleURL)
            }
        }.resume()
    }

    private func downloadAndInstall(from bundleURL: URL, expectedBinarySha256: String, destinationBundle: URL) {
        session.downloadTask(with: bundleURL) { [weak self] tempZipURL, response, error in
            guard let self = self else { return }
            guard error == nil,
                  let tempZipURL = tempZipURL,
                  let http = response as? HTTPURLResponse,
                  http.statusCode == 200 else {
                self.isUpdating = false
                return
            }

            let fm = FileManager.default
            let stagingDir = fm.temporaryDirectory.appendingPathComponent("tokentracker_update_\(UUID().uuidString)")
            do {
                try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
                let zipCopy = stagingDir.appendingPathComponent("bundle.zip")
                try fm.moveItem(at: tempZipURL, to: zipCopy)

                let unzip = Process()
                unzip.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                unzip.arguments = ["-x", "-k", zipCopy.path, stagingDir.path]
                try unzip.run()
                unzip.waitUntilExit()

                let extractedApp = stagingDir.appendingPathComponent("TokenTrackerHUD.app")
                let extractedBinary = extractedApp.appendingPathComponent("Contents/MacOS/TokenTrackerHUD")

                let verifySign = Process()
                verifySign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
                verifySign.arguments = ["--verify", "--deep", "--strict", extractedApp.path]
                try verifySign.run()
                verifySign.waitUntilExit()

                guard unzip.terminationStatus == 0,
                      verifySign.terminationStatus == 0,
                      fm.isExecutableFile(atPath: extractedBinary.path),
                      let extractedHash = self.sha256Hex(of: extractedBinary),
                      extractedHash == expectedBinarySha256 else {
                    try? fm.removeItem(at: stagingDir)
                    self.isUpdating = false
                    return
                }

                self.performAtomicSwap(stagedApp: extractedApp, stagingDir: stagingDir, destination: destinationBundle)
            } catch {
                try? fm.removeItem(at: stagingDir)
                self.isUpdating = false
            }
        }.resume()
    }

    private func performAtomicSwap(stagedApp: URL, stagingDir: URL, destination: URL) {
        let pid = ProcessInfo.processInfo.processIdentifier
        let destPath = destination.path
        let stagedPath = stagedApp.path
        let stagingRoot = stagingDir.path
        let destExec = destination.appendingPathComponent("Contents/MacOS/TokenTrackerHUD").path

        let script = """
        while kill -0 \(pid) 2>/dev/null; do sleep 0.2; done
        rm -rf "\(destPath)"
        mv "\(stagedPath)" "\(destPath)"
        xattr -cr "\(destPath)"
        rm -rf "\(stagingRoot)"
        nohup "\(destExec)" >/dev/null 2>&1 &
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
            try? FileManager.default.removeItem(at: stagingDir)
            self.isUpdating = false
        }
    }
}
