import Foundation
import SwiftUI
import AppKit

public struct TokenStats: Codable {
    public var totalFreeTokens: Int?
    public var totalRequests: Int?
    public var lastSpeedTokS: Double?
    public var lastModel: String?
    public var lastUpdated: Double?
    public var totalSavingsGbp: Double?
    public var todayDate: String?
    public var todayFreeTokens: Int?
    public var todayRequests: Int?
    public var todaySavingsGbp: Double?
    public var cloudTokensToday: Int?
    public var cloudTokens5h: Int?
    public var cloudTokens7d: Int?
    public var cloudTokensTotal: Int?
    public var rolling5hLimit: Int?
    public var rolling5hUsagePct: Double?
    public var rolling7dLimit: Int?
    public var rolling7dUsagePct: Double?
    public var fiveHourRemainingPct: Double?
    public var weeklyRemainingPct: Double?
    public var fiveHourRefreshTime: String?
    public var weeklyRefreshTime: String?
    public var fiveHourResetTimestamp: Double?
    public var weeklyResetTimestamp: Double?
    public var lastChat: String?
    public var lastTool: String?
    public var lastVolume: String?
    public var lastTokens: Int?
    public var isBusy: Bool?
    public var cloudTasksToday: Int?
    public var cloudTasksTotal: Int?
    public var todayTotalTasks: Int?
    public var totalCumulativeTasks: Int?
    public var activeChat: String?
    public var liveLoadPct: Double?
    public var status: String?
    public var cacheEntries: Int?
    public var shadowTokensAvoided: Int?

    enum CodingKeys: String, CodingKey {
        case totalFreeTokens = "total_free_tokens"
        case totalRequests = "total_requests"
        case lastSpeedTokS = "last_speed_tok_s"
        case lastModel = "last_model"
        case lastUpdated = "last_updated"
        case totalSavingsGbp = "total_savings_gbp"
        case todayDate = "today_date"
        case todayFreeTokens = "today_free_tokens"
        case todayRequests = "today_requests"
        case todaySavingsGbp = "today_savings_gbp"
        case cloudTokensToday = "cloud_tokens_today"
        case cloudTokens5h = "cloud_tokens_5h"
        case cloudTokens7d = "cloud_tokens_7d"
        case cloudTokensTotal = "cloud_tokens_total"
        case rolling5hLimit = "rolling_5h_limit"
        case rolling5hUsagePct = "rolling_5h_usage_pct"
        case rolling7dLimit = "rolling_7d_limit"
        case rolling7dUsagePct = "rolling_7d_usage_pct"
        case fiveHourRemainingPct = "five_hour_remaining_pct"
        case weeklyRemainingPct = "weekly_remaining_pct"
        case fiveHourRefreshTime = "five_hour_refresh_time"
        case weeklyRefreshTime = "weekly_refresh_time"
        case fiveHourResetTimestamp = "five_hour_reset_timestamp"
        case weeklyResetTimestamp = "weekly_reset_timestamp"
        case lastChat = "last_chat"
        case lastTool = "last_tool"
        case lastVolume = "last_volume"
        case lastTokens = "last_tokens"
        case isBusy = "is_busy"
        case cloudTasksToday = "cloud_tasks_today"
        case cloudTasksTotal = "cloud_tasks_total"
        case todayTotalTasks = "today_total_tasks"
        case totalCumulativeTasks = "total_cumulative_tasks"
        case activeChat = "active_chat"
        case liveLoadPct = "live_load_pct"
        case status = "status"
        case cacheEntries = "cache_entries"
        case shadowTokensAvoided = "shadow_tokens_avoided"
    }

    public static func fallback() -> TokenStats {
        return TokenStats(
            totalFreeTokens: 0,
            totalRequests: 0,
            lastSpeedTokS: 0.0,
            lastModel: "Local M3 Ultra",
            lastUpdated: Date().timeIntervalSince1970,
            totalSavingsGbp: 0.0,
            todayDate: "",
            todayFreeTokens: 0,
            todayRequests: 0,
            todaySavingsGbp: 0.0,
            cloudTokensToday: 0,
            cloudTokens5h: 0,
            cloudTokens7d: 0,
            cloudTokensTotal: 0,
            rolling5hLimit: 3500000,
            rolling5hUsagePct: 7.0,
            rolling7dLimit: 100000000,
            rolling7dUsagePct: 5.0,
            fiveHourRemainingPct: 93.0,
            weeklyRemainingPct: 95.0,
            fiveHourRefreshTime: "4 hours, 22 minutes",
            weeklyRefreshTime: "6 days, 15 hours",
            fiveHourResetTimestamp: Date().timeIntervalSince1970 + (4 * 3600 + 22 * 60),
            weeklyResetTimestamp: Date().timeIntervalSince1970 + (6 * 86400 + 15 * 3600),
            lastChat: "None",
            lastTool: "Idle",
            lastVolume: "-",
            lastTokens: 0,
            isBusy: false,
            cloudTasksToday: 0,
            cloudTasksTotal: 0,
            todayTotalTasks: 0,
            totalCumulativeTasks: 0,
            activeChat: "None",
            liveLoadPct: 0.0,
            status: "Idle",
            cacheEntries: 0,
            shadowTokensAvoided: 0
        )
    }

    public var calculated5hRemainingPct: Double {
        if let explicit = fiveHourRemainingPct {
            return explicit
        }
        let used = rolling5hUsagePct ?? 0.0
        return max(0.0, min(100.0, 100.0 - used))
    }

    public var calculatedWeeklyRemainingPct: Double {
        if let explicit = weeklyRemainingPct {
            return explicit
        }
        let used = rolling7dUsagePct ?? 0.0
        return max(0.0, min(100.0, 100.0 - used))
    }

    public var formattedSavings: String {
        let gbp = totalSavingsGbp ?? 0.0
        return String(format: "£%.2f", gbp)
    }

    public var formattedTodaySavings: String {
        let gbp = todaySavingsGbp ?? 0.0
        return String(format: "£%.2f", gbp)
    }

    public func formatNumber(_ num: Int) -> String {
        if num >= 1_000_000 {
            let val = Double(num) / 1_000_000.0
            return String(format: "%.1fM", val)
        } else if num >= 1_000 {
            let val = Double(num) / 1_000.0
            return String(format: "%.0fk", val)
        }
        return "\(num)"
    }
}
