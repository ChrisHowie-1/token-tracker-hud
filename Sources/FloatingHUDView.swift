import SwiftUI
import AppKit

public struct WindowDragView: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> DragAreaNSView {
        return DragAreaNSView()
    }

    public func updateNSView(_ nsView: DragAreaNSView, context: Context) {}
}

public class DragAreaNSView: NSView {
    public override func mouseDown(with event: NSEvent) {
        if let window = self.window {
            window.performDrag(with: event)
        }
    }
}

public struct FloatingHUDView: View {
    @ObservedObject var watcher: TokenStatsWatcher
    @State private var isHoveringClose = false
    @State private var isHoveringCompact = false

    public init(watcher: TokenStatsWatcher = TokenStatsWatcher.shared) {
        self.watcher = watcher
    }

    // High Contrast Liquid Glass Palette
    private let bgMain = Color(red: 0.10, green: 0.10, blue: 0.12)
    private let bgCard = Color(red: 0.16, green: 0.16, blue: 0.19)

    private let textWhite = Color.white
    private let textLight = Color(red: 0.88, green: 0.90, blue: 0.94)
    private let textMuted = Color(red: 0.65, green: 0.68, blue: 0.75)

    // Vibrant Accents
    private let accentGreen = Color(red: 0.22, green: 0.88, blue: 0.45)
    private let accentBlue = Color(red: 0.35, green: 0.75, blue: 1.0)
    private let accentOrange = Color(red: 1.0, green: 0.58, blue: 0.20)
    private let accentRed = Color(red: 1.0, green: 0.30, blue: 0.30)

    private var headerStatusColor: Color {
        if watcher.isOffline { return textMuted }
        return watcher.stats.isBusy == true ? accentGreen : accentBlue
    }

    public var body: some View {
        let lowest = watcher.stats.lowestBucket

        ZStack {
            WindowDragView()

            VStack(alignment: .leading, spacing: 9) {
                // Header Bar
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(headerStatusColor)
                            .frame(width: 9, height: 9)
                            .overlay(
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white.opacity(0.7), Color.clear],
                                            startPoint: .topLeading,
                                            endPoint: .center
                                        )
                                    )
                            )
                    }
                    .shadow(color: headerStatusColor.opacity(0.85), radius: 5, x: 0, y: 0)
                    .shadow(color: headerStatusColor.opacity(0.40), radius: 10, x: 0, y: 0)

                    Text(watcher.isOffline ? "AI Quota Tracker (Offline)" : "AI Quota Tracker")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(textWhite)

                    Image(systemName: "hand.draw")
                        .font(.system(size: 10))
                        .foregroundColor(textMuted)
                        .help("Click and drag to move")

                    Spacer()

                    // Compact Toggle
                    Button(action: {
                        watcher.toggleCompact()
                    }) {
                        Image(systemName: watcher.isCompact ? "chevron.down.circle.fill" : "chevron.up.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(isHoveringCompact ? textWhite : textLight)
                            .background(
                                Circle()
                                    .fill(isHoveringCompact ? Color.white.opacity(0.14) : Color.clear)
                                    .frame(width: 22, height: 22)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { isHoveringCompact = $0 }
                    .help("Toggle compact mode (surfaces lowest pool)")

                    // Close Button
                    Button(action: {
                        watcher.isHUDVisible = false
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundColor(isHoveringClose ? accentRed : textMuted)
                            .background(
                                Circle()
                                    .fill(isHoveringClose ? accentRed.opacity(0.18) : Color.clear)
                                    .frame(width: 22, height: 22)
                            )
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { isHoveringClose = $0 }
                    .help("Hide HUD (left-click Menu Bar to restore)")
                }

                if watcher.isCompact {
                    // Compact Mode: Automatically displays whichever bucket has the lowest remaining quota
                    liquidGlassCard(
                        title: lowest.title,
                        countdownText: "Refreshes in \(watcher.countdownForBucket(kind: lowest.kind))",
                        percentage: lowest.percentage,
                        limitTag: lowest.tag,
                        isLowest: true
                    )
                } else {
                    // 1. Gemini Weekly Card
                    liquidGlassCard(
                        title: "Gemini Weekly",
                        countdownText: "Refreshes in \(watcher.weeklyCountdown)",
                        percentage: watcher.stats.calculatedWeeklyRemainingPct,
                        limitTag: "(G7)",
                        isLowest: lowest.kind == "G7"
                    )

                    // 2. Gemini 5-Hour Card
                    liquidGlassCard(
                        title: "Gemini 5-Hour",
                        countdownText: "Refreshes in \(watcher.fiveHourCountdown)",
                        percentage: watcher.stats.calculated5hRemainingPct,
                        limitTag: "(G5)",
                        isLowest: lowest.kind == "G5"
                    )

                    // 3. Claude & GPT Dual-Pool Card (when reported by Antigravity RPC)
                    if watcher.stats.hasThreePQuota {
                        dualThreePCard(lowestKind: lowest.kind)
                    }
                }

                // 4. M3 Ultra Live Savings & Throughput Strip
                m3UltraFooterStrip()
            }
            .padding(12)
        }
        .frame(width: 336)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(bgMain.opacity(0.84))

                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.12), location: 0.0),
                                .init(color: Color.white.opacity(0.02), location: 0.25),
                                .init(color: Color.clear, location: 0.60)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(0.60), location: 0.0),
                            .init(color: Color.white.opacity(0.20), location: 0.22),
                            .init(color: Color.white.opacity(0.06), location: 0.65),
                            .init(color: Color.white.opacity(0.22), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
    }

    @ViewBuilder
    private func dualThreePCard(lowestKind: String) -> some View {
        let p5 = watcher.stats.calculated3p5hRemainingPct
        let p7 = watcher.stats.calculated3pWeeklyRemainingPct
        let isAnyLowest = (lowestKind == "C5" || lowestKind == "C7")
        let borderAccent = remainingColor(min(p5, p7))

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                miniPoolColumn(
                    label: "Claude/GPT 5h",
                    tag: "(C5)",
                    countdown: watcher.threePFiveHourCountdown,
                    pct: p5
                )

                Rectangle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 1, height: 42)

                miniPoolColumn(
                    label: "Claude/GPT 7d",
                    tag: "(C7)",
                    countdown: watcher.threePWeeklyCountdown,
                    pct: p7
                )
            }
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .background(bgCard.opacity(0.68))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    isAnyLowest ? borderAccent.opacity(0.55) : Color.white.opacity(0.16),
                    lineWidth: isAnyLowest ? 1.4 : 1.0
                )
        )
        .shadow(color: Color.black.opacity(0.22), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func miniPoolColumn(label: String, tag: String, countdown: String, pct: Double) -> some View {
        let col = remainingColor(pct)
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(textWhite)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text(String(format: "%.0f%%", pct))
                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                    .foregroundColor(col)
            }
            Text("\(tag) · \(countdown)")
                .font(.system(size: 9.5, weight: .medium, design: .monospaced))
                .foregroundColor(textMuted)
                .lineLimit(1)

            liquidTube(percentage: pct, height: 6)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func m3UltraFooterStrip() -> some View {
        let isBusy = watcher.stats.isBusy == true
        HStack(spacing: 6) {
            Text(isBusy ? "⚡️" : "🖥")
                .font(.system(size: 11))
            Text(isBusy ? "M3 Ultra Active" : "M3 Ultra")
                .font(.system(size: 10.5, weight: .bold, design: .rounded))
                .foregroundColor(isBusy ? accentGreen : textLight)
            Spacer()
            Text("\(watcher.stats.formattedSavings) saved · \(watcher.stats.formattedFreeTokens) tok · \(watcher.stats.formattedSpeed)")
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundColor(isBusy ? accentGreen : accentBlue)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(isBusy ? accentGreen.opacity(0.14) : Color.white.opacity(0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(isBusy ? accentGreen.opacity(0.45) : Color.white.opacity(0.10), lineWidth: 0.8)
        )
    }

    @ViewBuilder
    private func liquidGlassCard(title: String, countdownText: String, percentage: Double, limitTag: String = "", isLowest: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(textWhite)
                        if !limitTag.isEmpty {
                            Text(limitTag)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundColor(remainingColor(percentage))
                        }
                    }
                    Text(countdownText)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundColor(textLight)
                }
                Spacer()
                Text(String(format: "%.0f%%", percentage))
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundColor(remainingColor(percentage))
                    .shadow(color: remainingColor(percentage).opacity(0.40), radius: 6, x: 0, y: 0)
            }

            liquidTube(percentage: percentage, height: 8)
        }
        .padding(10)
        .background(
            ZStack {
                bgCard.opacity(0.68)
                LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.08), location: 0.0),
                        .init(color: Color.white.opacity(0.02), location: 0.35),
                        .init(color: Color.clear, location: 0.70)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(
                    LinearGradient(
                        stops: isLowest ? [
                            .init(color: remainingColor(percentage).opacity(0.65), location: 0.0),
                            .init(color: remainingColor(percentage).opacity(0.25), location: 0.5),
                            .init(color: remainingColor(percentage).opacity(0.12), location: 1.0)
                        ] : [
                            .init(color: Color.white.opacity(0.32), location: 0.0),
                            .init(color: Color.white.opacity(0.10), location: 0.4),
                            .init(color: Color.white.opacity(0.04), location: 1.0)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: isLowest ? 1.4 : 1
                )
        )
        .shadow(color: Color.black.opacity(0.25), radius: 4, x: 0, y: 2)
    }

    @ViewBuilder
    private func liquidTube(percentage: Double, height: CGFloat) -> some View {
        GeometryReader { geo in
            let fillWidth = max(height, geo.size.width * CGFloat(min(1.0, max(0.0, percentage) / 100.0)))
            let color = remainingColor(percentage)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.black.opacity(0.55))
                    .frame(height: height)
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                    )

                ZStack(alignment: .topLeading) {
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.95), color],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.52), Color.white.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(height: height * 0.44)
                        .padding(.horizontal, 1)
                }
                .frame(width: fillWidth, height: height)
                .clipShape(Capsule())
                .shadow(color: color.opacity(0.55), radius: 4, x: 0, y: 0)
            }
        }
        .frame(height: height)
    }

    private func remainingColor(_ pct: Double) -> Color {
        if pct >= 50.0 { return accentGreen }
        if pct >= 20.0 { return accentOrange }
        return accentRed
    }
}
