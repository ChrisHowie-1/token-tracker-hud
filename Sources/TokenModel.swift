import Foundation
import SwiftUI
import AppKit

public struct QuotaBucketSummary {
    public let title: String
    public let tag: String
    public let percentage: Double
    public let kind: String // "G7", "G5", "C5", "C7"
}

public struct TokenStats: Codable {
    public var totalFreeTokens: Int?
    public var totalRequests: Int?
    public var lastSpeedTokS: Double?
    public var lastModel: String?
    public var lastEngine: String?
    public var lastUpdated: Double?
    public var totalSavingsGbp: Double?
    public var totalContextSavingsGbp: Double?
    public var todayDate: String?
    public var todayFreeTokens: Int?
    public var todayRequests: Int?
    public var todaySavingsGbp: Double?
    public var todayContextSavingsGbp: Double?
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
    public var threePFiveHourRemainingPct: Double?
    public var threePWeeklyRemainingPct: Double?
    public var threePFiveHourRefreshTime: String?
    public var threePWeeklyRefreshTime: String?
    public var threePFiveHourResetTimestamp: Double?
    public var threePWeeklyResetTimestamp: Double?
    public var lowestOverallPct: Double?
    public var lowestOverallTag: String?
    public var officialSyncStatus: String?
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
        case lastEngine = "last_engine"
        case lastUpdated = "last_updated"
        case totalSavingsGbp = "total_savings_gbp"
        case totalContextSavingsGbp = "total_context_savings_gbp"
        case todayDate = "today_date"
        case todayFreeTokens = "today_free_tokens"
        case todayRequests = "today_requests"
        case todaySavingsGbp = "today_savings_gbp"
        case todayContextSavingsGbp = "today_context_savings_gbp"
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
        case threePFiveHourRemainingPct = "three_p_five_hour_remaining_pct"
        case threePWeeklyRemainingPct = "three_p_weekly_remaining_pct"
        case threePFiveHourRefreshTime = "three_p_five_hour_refresh_time"
        case threePWeeklyRefreshTime = "three_p_weekly_refresh_time"
        case threePFiveHourResetTimestamp = "three_p_five_hour_reset_timestamp"
        case threePWeeklyResetTimestamp = "three_p_weekly_reset_timestamp"
        case lowestOverallPct = "lowest_overall_pct"
        case lowestOverallTag = "lowest_overall_tag"
        case officialSyncStatus = "official_sync_status"
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
            lastModel: "M3 Ultra",
            lastEngine: "oMLX",
            lastUpdated: 0,
            totalSavingsGbp: 0.0,
            totalContextSavingsGbp: 0.0,
            todayDate: "",
            todayFreeTokens: 0,
            todayRequests: 0,
            todaySavingsGbp: 0.0,
            todayContextSavingsGbp: 0.0,
            cloudTokensToday: 0,
            cloudTokens5h: 0,
            cloudTokens7d: 0,
            cloudTokensTotal: 0,
            rolling5hLimit: 1750000,
            rolling5hUsagePct: 0.0,
            rolling7dLimit: 100000000,
            rolling7dUsagePct: 0.0,
            fiveHourRemainingPct: 100.0,
            weeklyRemainingPct: 100.0,
            fiveHourRefreshTime: "Waiting for sync...",
            weeklyRefreshTime: "Waiting for sync...",
            fiveHourResetTimestamp: nil,
            weeklyResetTimestamp: nil,
            threePFiveHourRemainingPct: nil,
            threePWeeklyRemainingPct: nil,
            threePFiveHourRefreshTime: nil,
            threePWeeklyRefreshTime: nil,
            threePFiveHourResetTimestamp: nil,
            threePWeeklyResetTimestamp: nil,
            lowestOverallPct: nil,
            lowestOverallTag: nil,
            officialSyncStatus: "WAITING",
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

    public var hasThreePQuota: Bool {
        return threePFiveHourRemainingPct != nil || threePWeeklyRemainingPct != nil
    }

    public var calculated3p5hRemainingPct: Double {
        return threePFiveHourRemainingPct ?? 100.0
    }

    public var calculated3pWeeklyRemainingPct: Double {
        return threePWeeklyRemainingPct ?? 100.0
    }

    public var allBuckets: [QuotaBucketSummary] {
        var list: [QuotaBucketSummary] = [
            QuotaBucketSummary(title: "Gemini Weekly", tag: "(G7)", percentage: calculatedWeeklyRemainingPct, kind: "G7"),
            QuotaBucketSummary(title: "Gemini 5-Hour", tag: "(G5)", percentage: calculated5hRemainingPct, kind: "G5")
        ]
        if hasThreePQuota {
            list.append(QuotaBucketSummary(title: "Claude/GPT 5-Hour", tag: "(C5)", percentage: calculated3p5hRemainingPct, kind: "C5"))
            list.append(QuotaBucketSummary(title: "Claude/GPT Weekly", tag: "(C7)", percentage: calculated3pWeeklyRemainingPct, kind: "C7"))
        }
        return list
    }

    public var lowestBucket: QuotaBucketSummary {
        return allBuckets.min(by: { $0.percentage < $1.percentage }) ?? QuotaBucketSummary(title: "Gemini 5-Hour", tag: "(G5)", percentage: calculated5hRemainingPct, kind: "G5")
    }

    public var lowestRemainingPct: Double {
        return lowestBucket.percentage
    }

    public var lowestTag: String {
        return lowestBucket.tag
    }

    public var effectiveTotalSavingsGbp: Double {
        return max(totalContextSavingsGbp ?? 0.0, totalSavingsGbp ?? 0.0)
    }

    public var formattedSavings: String {
        return String(format: "£%.2f", effectiveTotalSavingsGbp)
    }

    public var formattedFreeTokens: String {
        return formatNumber(totalFreeTokens ?? 0)
    }

    public var formattedSpeed: String {
        let spd = lastSpeedTokS ?? 0.0
        if spd > 0.0 {
            return String(format: "%.0f tok/s", spd)
        }
        return lastEngine ?? "oMLX"
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
