import Foundation
import SwiftUI
import Combine

public class TokenStatsWatcher: ObservableObject {
    public static let shared = TokenStatsWatcher()

    @Published public var stats: TokenStats = TokenStats.fallback()
    @Published public var lastRefreshed: Date = Date()
    @Published public var isHUDVisible: Bool = true
    @Published public var isCompact: Bool = false
    @Published public var fiveHourCountdown: String = "3 hours, 23 minutes"
    @Published public var weeklyCountdown: String = "6 days, 14 hours"

    private var timer: Timer?
    private var consecutiveLanFailures: Int = 0

    private let primaryStatsPath = "/Users/chrishowie/.gemini/antigravity/local_ai_stats.json"
    private let icloudStatsPath = ("/Users/chrishowie/Library/Mobile Documents/com~apple~CloudDocs/Antigravity Projects/Misc/TokenTrackerHUD/stats.json" as NSString).expandingTildeInPath
    private let lanStatsURL = URL(string: "http://192.168.32.90:9587/stats")!

    private let isLocalHost: Bool = {
        let name = ProcessInfo.processInfo.hostName.lowercased()
        return name.contains("studio")
    }()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 2.5
        config.timeoutIntervalForResource = 2.5
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        return URLSession(configuration: config)
    }()

    public init() {
        loadStats()
        startWatching()
    }

    public func startWatching() {
        timer?.invalidate()
        // Poll every 1.5 seconds for fresh stats
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.loadStats()
            self?.updateCountdowns()
        }
    }

    public func loadStats() {
        let fileManager = FileManager.default

        // 1. If running locally on Mac Studio, read primary path directly
        if isLocalHost {
            if fileManager.fileExists(atPath: primaryStatsPath),
               let data = try? Data(contentsOf: URL(fileURLWithPath: primaryStatsPath)) {
                if decodeData(data) {
                    // Keep iCloud copy fresh atomically from Mac Studio
                    try? data.write(to: URL(fileURLWithPath: icloudStatsPath), options: .atomic)
                    return
                }
            }
        }

        // 2. Client mode (MacBook): fetch live stream from Mac Studio LAN daemon
        var request = URLRequest(url: lanStatsURL)
        request.timeoutInterval = 2.5
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }

            if let data = data, error == nil, let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if self.decodeData(data) {
                    self.consecutiveLanFailures = 0
                    return
                }
            }

            self.consecutiveLanFailures += 1

            // 3. Fallback to iCloud file ONLY if LAN is genuinely down (3+ failures) or initial launch
            if (self.consecutiveLanFailures >= 3 || self.stats.totalRequests == 0),
               fileManager.fileExists(atPath: self.icloudStatsPath),
               let fileData = try? Data(contentsOf: URL(fileURLWithPath: self.icloudStatsPath)) {
                _ = self.decodeData(fileData)
            }
        }.resume()
    }

    @discardableResult
    private func decodeData(_ data: Data, allowOlder: Bool = false) -> Bool {
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(TokenStats.self, from: data)

            // Monotonicity guard: never overwrite fresher live data with older/stale payload
            if !allowOlder,
               let incomingTime = decoded.lastUpdated,
               let currentTime = self.stats.lastUpdated,
               self.stats.totalRequests != 0 {
                if incomingTime < (currentTime - 2.0) {
                    // Stale fallback payload rejected
                    return false
                }
            }

            DispatchQueue.main.async {
                self.stats = decoded
                self.lastRefreshed = Date()
            }
            return true
        } catch {
            return false
        }
    }

    private func updateCountdowns() {
        let now = Date().timeIntervalSince1970

        // 5-Hour Countdown
        if let target5h = stats.fiveHourResetTimestamp, target5h > now {
            let remaining = target5h - now
            let hours = Int(remaining) / 3600
            let minutes = (Int(remaining) % 3600) / 60
            DispatchQueue.main.async {
                self.fiveHourCountdown = "\(hours) hours, \(minutes) minutes"
            }
        } else if let explicit5h = stats.fiveHourRefreshTime {
            DispatchQueue.main.async {
                self.fiveHourCountdown = explicit5h
            }
        }

        // Weekly Countdown
        if let targetWk = stats.weeklyResetTimestamp, targetWk > now {
            let remaining = targetWk - now
            let days = Int(remaining) / 86400
            let hours = Int(round((remaining.truncatingRemainder(dividingBy: 86400)) / 3600.0))
            DispatchQueue.main.async {
                self.weeklyCountdown = "\(days) days, \(hours) hours"
            }
        } else if let explicitWk = stats.weeklyRefreshTime {
            DispatchQueue.main.async {
                self.weeklyCountdown = explicitWk
            }
        }
    }

    public func toggleVisibility() {
        isHUDVisible.toggle()
    }

    public func toggleCompact() {
        isCompact.toggle()
    }
}
