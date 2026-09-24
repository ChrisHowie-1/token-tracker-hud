import SwiftUI
import AppKit

public struct WindowDragView: NSViewRepresentable {
    public init() {}

    public func makeNSView(context: Context) -> DragAreaNSView {
        let view = DragAreaNSView()
        return view
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

    // High Contrast Palette (Preserved Theme)
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

    public var body: some View {
        ZStack {
            // Full background drag handler
            WindowDragView()

            VStack(alignment: .leading, spacing: 10) {
                // Header Bar
                HStack(spacing: 8) {
                    let statusColor = (watcher.stats.isBusy == true ? accentGreen : accentBlue)
                    ZStack {
                        Circle()
                            .fill(statusColor)
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
                    .shadow(color: statusColor.opacity(0.85), radius: 5, x: 0, y: 0)
                    .shadow(color: statusColor.opacity(0.40), radius: 10, x: 0, y: 0)

                    Text("Gemini Quota Tracker")
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
                    .help("Toggle compact mode")

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
                    .help("Hide HUD (accessible via Menu Bar)")
                }

                // 1. Weekly Limit Remaining Card (ON TOP)
                liquidGlassCard(
                    title: "Weekly Limit Remaining",
                    countdownText: "Refreshes in \(watcher.weeklyCountdown)",
                    percentage: watcher.stats.calculatedWeeklyRemainingPct,
                    limitTag: "(7)",
                    isLowest: !watcher.stats.isFiveHourLower
                )

                if !watcher.isCompact {
                    // 2. Five Hour Limit Remaining Card (SECOND)
                    liquidGlassCard(
                        title: "Five Hour Limit Remaining",
                        countdownText: "Refreshes in \(watcher.fiveHourCountdown)",
                        percentage: watcher.stats.calculated5hRemainingPct,
                        limitTag: "(5)",
                        isLowest: watcher.stats.isFiveHourLower
                    )
                }
            }
            .padding(12)
        }
        .frame(width: 330)
        // Liquid Glass Background
        .background(
            ZStack {
                // Native continuous frosted glass
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)

                // Deep dark tint preserving contrast across wallpapers
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(bgMain.opacity(0.82))

                // Liquid glass surface sheen
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
            // Liquid glass specular rim highlight
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
    private func liquidGlassCard(title: String, countdownText: String, percentage: Double, limitTag: String = "", isLowest: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 7) {
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
                    .font(.system(size: 22, weight: .heavy, design: .rounded))
                    .foregroundColor(remainingColor(percentage))
                    .shadow(color: remainingColor(percentage).opacity(0.40), radius: 6, x: 0, y: 0)
            }

            // Liquid Glass Progress Bar Tube
            GeometryReader { geo in
                let fillWidth = max(7, geo.size.width * CGFloat(min(1.0, percentage / 100.0)))
                let color = remainingColor(percentage)

                ZStack(alignment: .leading) {
                    // Recessed cylindrical glass tube
                    Capsule()
                        .fill(Color.black.opacity(0.55))
                        .frame(height: 8)
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.08), lineWidth: 0.5)
                        )

                    // Luminous liquid fill inside tube
                    ZStack(alignment: .topLeading) {
                        // Liquid base gradient
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        color.opacity(0.95),
                                        color
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                        // Liquid glass specular gloss line
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.white.opacity(0.52),
                                        Color.white.opacity(0.0)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(height: 3.5)
                            .padding(.horizontal, 1)
                    }
                    .frame(width: fillWidth, height: 8)
                    .clipShape(Capsule())
                    // Liquid glow aura
                    .shadow(color: color.opacity(0.65), radius: 5, x: 0, y: 0)
                    .shadow(color: color.opacity(0.35), radius: 10, x: 0, y: 0)
                }
            }
            .frame(height: 8)
        }
        .padding(11)
        // Card frosted glass container with concentric corner radius (12pt)
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

    private func remainingColor(_ pct: Double) -> Color {
        if pct >= 50.0 { return accentGreen }
        if pct >= 20.0 { return accentOrange }
        return accentRed
    }
}
