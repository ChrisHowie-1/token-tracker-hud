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

    // High Contrast Solid Color Palette (WCAG AAA contrast on all wallpapers)
    private let bgMain = Color(red: 0.10, green: 0.10, blue: 0.12)
    private let bgCard = Color(red: 0.16, green: 0.16, blue: 0.19)
    private let strokeColor = Color.white.opacity(0.18)

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
                    Circle()
                        .fill(watcher.stats.isBusy == true ? accentGreen : accentBlue)
                        .frame(width: 9, height: 9)
                        .shadow(color: (watcher.stats.isBusy == true ? accentGreen : accentBlue).opacity(0.8), radius: 4)

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
                    }
                    .buttonStyle(PlainButtonStyle())
                    .onHover { isHoveringClose = $0 }
                    .help("Hide HUD (accessible via Menu Bar)")
                }

                // 1. Weekly Limit Remaining Card (ON TOP)
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Weekly Limit Remaining")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(textWhite)
                            Text("Refreshes in \(watcher.weeklyCountdown)")
                                .font(.system(size: 10, weight: .medium, design: .monospaced))
                                .foregroundColor(textLight)
                        }
                        Spacer()
                        Text(String(format: "%.0f%%", watcher.stats.calculatedWeeklyRemainingPct))
                            .font(.system(size: 22, weight: .heavy, design: .rounded))
                            .foregroundColor(remainingColor(watcher.stats.calculatedWeeklyRemainingPct))
                    }

                    // Progress Bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color.black.opacity(0.5))
                                .frame(height: 7)

                            Capsule()
                                .fill(remainingColor(watcher.stats.calculatedWeeklyRemainingPct))
                                .frame(width: max(6, geo.size.width * CGFloat(min(1.0, watcher.stats.calculatedWeeklyRemainingPct / 100.0))), height: 7)
                        }
                    }
                    .frame(height: 7)
                }
                .padding(11)
                .background(bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )

                if !watcher.isCompact {
                    // 2. Five Hour Limit Remaining Card (SECOND)
                    VStack(alignment: .leading, spacing: 7) {
                        HStack(alignment: .center) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Five Hour Limit Remaining")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(textWhite)
                                Text("Refreshes in \(watcher.fiveHourCountdown)")
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundColor(textLight)
                            }
                            Spacer()
                            Text(String(format: "%.0f%%", watcher.stats.calculated5hRemainingPct))
                                .font(.system(size: 22, weight: .heavy, design: .rounded))
                                .foregroundColor(remainingColor(watcher.stats.calculated5hRemainingPct))
                        }

                        // Progress Bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(height: 7)

                                Capsule()
                                    .fill(remainingColor(watcher.stats.calculated5hRemainingPct))
                                    .frame(width: max(6, geo.size.width * CGFloat(min(1.0, watcher.stats.calculated5hRemainingPct / 100.0))), height: 7)
                            }
                        }
                        .frame(height: 7)
                    }
                    .padding(11)
                    .background(bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(strokeColor, lineWidth: 1)
                    )
                }
            }
            .padding(12)
        }
        .frame(width: 330)
        .background(bgMain)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.25), lineWidth: 1.2)
        )
        .shadow(color: Color.black.opacity(0.7), radius: 24, x: 0, y: 12)
    }

    private func remainingColor(_ pct: Double) -> Color {
        if pct >= 50.0 { return accentGreen }
        if pct >= 20.0 { return accentOrange }
        return accentRed
    }
}
