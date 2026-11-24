import Foundation
import SwiftUI
import Combine

public class TokenStatsWatcher: ObservableObject {
    public static let shared = TokenStatsWatcher()

    @Published public var stats: TokenStats = TokenStats.fallback()
    @Published public var lastRefreshed: Date = Date()
    @Published public var isHUDVisible: Bool = true
    @Published public var isCompact: Bool = false
    @Published public var isOffline: Bool = false

    @Published public var fiveHourCountdown: String = "Calculating..."
    @Published public var weeklyCountdown: String = "Calculating..."
    @Published public var threePFiveHourCountdown: String = "Calculating..."
    @Published public var threePWeeklyCountdown: String = "Calculating..."

    private var timer: Timer?
    private var consecutiveLanFailures: Int = 0
    private var isFetchingLan: Bool = false

    private let primaryStatsPath = "/Users/chrishowie/.gemini/antigravity/local_ai_stats.json"
    private let lanStatsURL = URL(string: "http://192.168.32.90:9587/stats")!

    private let isLocalHost: Bool = {
        let name = ProcessInfo.processInfo.hostName.lowercased()
        return name.contains("studio")
    }()

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0
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
        timer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            self?.loadStats()
            self?.updateCountdowns()
        }
    }

    public func loadStats() {
        let fileManager = FileManager.default

        // 1. If running on Mac Studio, read primary local file directly
        if isLocalHost {
            if fileManager.fileExists(atPath: primaryStatsPath),
               let data = try? Data(contentsOf: URL(fileURLWithPath: primaryStatsPath)) {
                if decodeData(data) {
                    DispatchQueue.main.async {
                        if self.isOffline { self.isOffline = false }
                    }
                    return
                }
            }
        }

        // 2. Client mode (MacBook Pro): fetch live stream from Mac Studio LAN daemon with in-flight guard
        guard !isFetchingLan else { return }
        isFetchingLan = true

        var request = URLRequest(url: lanStatsURL)
        request.timeoutInterval = 2.0
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

        session.dataTask(with: request) { [weak self] data, response, error in
            guard let self = self else { return }
            self.isFetchingLan = false

            if let data = data, error == nil, let http = response as? HTTPURLResponse, http.statusCode == 200 {
                if self.decodeData(data) {
                    self.consecutiveLanFailures = 0
                    DispatchQueue.main.async {
                        if self.isOffline { self.isOffline = false }
                    }
                    return
                }
            }

            self.consecutiveLanFailures += 1
            if self.consecutiveLanFailures >= 3 {
                DispatchQueue.main.async {
                    if !self.isOffline { self.isOffline = true }
                }
            }
        }.resume()
    }

    @discardableResult
    private func decodeData(_ data: Data, allowOlder: Bool = false) -> Bool {
        do {
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(TokenStats.self, from: data)

            // Monotonicity guard: never overwrite fresher live data with older payload
            if !allowOlder,
               let incomingTime = decoded.lastUpdated,
               let currentTime = self.stats.lastUpdated,
               currentTime > 0 {
                if incomingTime < (currentTime - 2.0) {
                    return false
                }
            }

            DispatchQueue.main.async {
                self.stats = decoded
                self.lastRefreshed = Date()
                self.updateCountdowns(with: decoded)
            }
            return true
        } catch {
            return false
        }
    }

    private static func format5h(target: Double?, fallback: String?, now: Double) -> String {
        if let t = target, t > now {
            let rem = t - now
            let hours = Int(rem) / 3600
            let mins = (Int(rem) % 3600) / 60
            return "\(hours)h \(mins)m"
        }
        if let f = fallback?.trimmingCharacters(in: .whitespacesAndNewlines), !f.isEmpty {
            return f
        }
        return "Ready"
    }

    private static func formatWeekly(target: Double?, fallback: String?, now: Double) -> String {
        if let t = target, t > now {
            let rem = t - now
            let days = Int(rem) / 86400
            let hours = Int(round((rem.truncatingRemainder(dividingBy: 86400)) / 3600.0))
            return "\(days)d \(hours)h"
        }
        if let f = fallback?.trimmingCharacters(in: .whitespacesAndNewlines), !f.isEmpty {
            return f
        }
        return "Ready"
    }

    private func updateCountdowns(with source: TokenStats? = nil) {
        let s = source ?? stats
        let now = Date().timeIntervalSince1970

        let g5 = Self.format5h(target: s.fiveHourResetTimestamp, fallback: s.fiveHourRefreshTime, now: now)
        let g7 = Self.formatWeekly(target: s.weeklyResetTimestamp, fallback: s.weeklyRefreshTime, now: now)
        let c5 = (s.threePFiveHourDisabled == true)
            ? "Weekly hit"
            : Self.format5h(target: s.threePFiveHourResetTimestamp, fallback: s.threePFiveHourRefreshTime, now: now)
        let c7 = Self.formatWeekly(target: s.threePWeeklyResetTimestamp, fallback: s.threePWeeklyRefreshTime, now: now)

        let apply = {
            if self.fiveHourCountdown != g5 { self.fiveHourCountdown = g5 }
            if self.weeklyCountdown != g7 { self.weeklyCountdown = g7 }
            if self.threePFiveHourCountdown != c5 { self.threePFiveHourCountdown = c5 }
            if self.threePWeeklyCountdown != c7 { self.threePWeeklyCountdown = c7 }
        }

        if Thread.isMainThread {
            apply()
        } else {
            DispatchQueue.main.async(execute: apply)
        }
    }

    public func countdownForBucket(kind: String) -> String {
        switch kind {
        case "G7": return weeklyCountdown
        case "G5": return fiveHourCountdown
        case "C5": return threePFiveHourCountdown
        case "C7": return threePWeeklyCountdown
        default: return fiveHourCountdown
        }
    }

    public func toggleVisibility() {
        isHUDVisible.toggle()
    }

    public func toggleCompact() {
        isCompact.toggle()
    }
}
