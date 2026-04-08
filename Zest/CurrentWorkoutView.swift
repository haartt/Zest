import SwiftUI
import Combine
internal import CoreData

/// Active workout screen:
///  • Large monospaced timer
///  • Live GPS speedometer (speed, avg, distance)
///  • Current track name
///  • Scatter indicator with Shaperbox-style bar animation + 2 effect placeholder slots
///  • Stop / Start button
struct CurrentWorkoutView: View {

    @EnvironmentObject var workoutManager: WorkoutManager
    @Environment(\.managedObjectContext) private var context

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // ── Timer + Speedometer row ────────────────────────
                HStack(alignment: .center, spacing: 20) {
                    timerBlock
                    SpeedometerView(
                        speedMS:      workoutManager.locationManager.speed,
                        averageSpeed: workoutManager.locationManager.averageSpeed,
                        distance:     workoutManager.locationManager.distance
                    )
                    .frame(width: 130, height: 130)
                }
                .padding(.horizontal, 24)

                // ── Track name ────────────────────────────────────
                Text(workoutManager.audioEngine.currentTrackName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.zestGreen.opacity(0.8))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 40)
                    .padding(.top, 14)

                // ── Calibration banner ──────────────────────────
                CalibrationBannerView(state: workoutManager.motionManager.calibrationState)
                    .padding(.horizontal, 20)
                    .padding(.top, 10)

                Spacer()

                // ── Indicator row ────────────────────────────────
                HStack(spacing: 14) {
                    ScatterIndicatorView(
                        count:    workoutManager.scatterCount,
                        isActive: workoutManager.audioEngine.isScattering
                    )
                    EffectSlotView(label: "FX 1", icon: "dial.low",  hint: "reverb")
                    EffectSlotView(label: "FX 2", icon: "dial.high", hint: "delay")
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)

                // ── Stop / Start button ─────────────────────────
                Button(action: toggleSession) {
                    Text(workoutManager.isSessionActive ? "STOP" : "START")
                        .font(.system(size: 20, weight: .bold))
                        .tracking(1.5)
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                        .background(stopStartColor)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 36)
                .animation(.easeInOut(duration: 0.2), value: workoutManager.isSessionActive)
            }
        }
    }

    // MARK: - Subviews

    private var timerBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedTime)
                .font(.system(size: 62, weight: .black, design: .monospaced))
                .foregroundColor(.white)
                .minimumScaleFactor(0.5)
                .lineLimit(1)

            Text("ELAPSED")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.3))
                .tracking(2.5)
        }
    }

    private var stopStartColor: Color {
        workoutManager.isSessionActive
            ? Color(red: 1, green: 0.25, blue: 0.25)
            : .zestGreen
    }

    // MARK: - Helpers

    private var formattedTime: String {
        let h = workoutManager.elapsedSeconds / 3600
        let m = (workoutManager.elapsedSeconds % 3600) / 60
        let s = workoutManager.elapsedSeconds % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%02d:%02d", m, s)
    }

    private func toggleSession() {
        if workoutManager.isSessionActive {
            workoutManager.stop(context: context)
        } else {
            workoutManager.start()
        }
    }
}

// MARK: - SpeedometerView

/// Live GPS speedometer showing:
///  - Current speed (large, tap to toggle km/h ↔ m/s)
///  - Average speed (⌀) and total distance below
///  - Arc fills 0–20 km/h, color shifts green → yellow → orange
struct SpeedometerView: View {

    let speedMS:      Double   // current speed m/s  (from LocationManager.speed)
    let averageSpeed: Double   // average m/s        (from LocationManager.averageSpeed)
    let distance:     Double   // total metres       (from LocationManager.distance)

    private let maxKMH: Double = 20.0
    @State private var showKMH = true

    // MARK: Derived

    private var speedKMH: Double { speedMS * 3.6 }
    private var avgKMH: Double   { averageSpeed * 3.6 }

    private var arcProgress: CGFloat {
        CGFloat(min(speedKMH / maxKMH, 1.0))
    }

    private var currentDisplay: String {
        showKMH
            ? String(format: "%.1f", speedKMH)
            : String(format: "%.2f", speedMS)
    }

    private var currentUnit: String { showKMH ? "km/h" : "m/s" }

    private var avgDisplay: String {
        showKMH
            ? String(format: "⌀ %.1f km/h", avgKMH)
            : String(format: "⌀ %.2f m/s",  averageSpeed)
    }

    private var distanceDisplay: String {
        distance < 1000
            ? String(format: "%.0f m",   distance)
            : String(format: "%.2f km",  distance / 1000)
    }

    private var arcColor: Color {
        let t = min(speedKMH / maxKMH, 1.0)
        switch t {
        case ..<0.5: return .zestGreen
        case ..<0.8: return Color(red: 1.0, green: 0.85, blue: 0.0)
        default:     return Color(red: 1.0, green: 0.45, blue: 0.0)
        }
    }

    // MARK: Body

    var body: some View {
        Button { showKMH.toggle() } label: {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 8)

                // Speed arc
                Circle()
                    .trim(from: 0, to: arcProgress)
                    .stroke(arcColor,
                            style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.35, dampingFraction: 0.75),
                               value: arcProgress)

                // Center content
                VStack(spacing: 2) {
                    // Current speed — large
                    Text(currentDisplay)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .minimumScaleFactor(0.5)
                        .lineLimit(1)
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.25), value: currentDisplay)

                    Text(currentUnit)
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(Color.white.opacity(0.4))
                        .tracking(0.8)

                    // Divider
                    Rectangle()
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 38, height: 0.5)
                        .padding(.vertical, 2)

                    // Avg speed
                    Text(avgDisplay)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.white.opacity(0.35))
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.25), value: avgDisplay)

                    // Distance
                    Text(distanceDisplay)
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .foregroundColor(Color.zestGreen.opacity(0.7))
                        .contentTransition(.numericText())
                        .animation(.linear(duration: 0.25), value: distanceDisplay)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - ScatterIndicatorView

/// Displays the scatter count and a Shaperbox-inspired bar animation
/// when the gating effect is active.
struct ScatterIndicatorView: View {
    let count: Int
    let isActive: Bool

    @State private var barHeights: [CGFloat] = [0.3, 0.7, 1.0, 0.6, 0.25]
    private let barTimer = Timer.publish(every: 0.07, on: .main, in: .common).autoconnect()

    var body: some View {
        indicatorCard
            .onReceive(barTimer) { _ in
                guard isActive else { return }
                withAnimation(.easeInOut(duration: 0.06)) {
                    barHeights = barHeights.map { _ in CGFloat.random(in: 0.15...1.0) }
                }
            }
            .onChange(of: isActive) { active in
                if !active {
                    withAnimation {
                        barHeights = [0.3, 0.7, 1.0, 0.6, 0.25]
                    }
                }
            }
    }

    private var indicatorCard: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(isActive
                              ? Color(red: 1, green: 0.25, blue: 0.25)
                              : Color.zestGreen.opacity(0.45))
                        .frame(width: 5, height: max(4, 22 * barHeights[i]))
                }
            }
            .frame(height: 24)

            Text("\(count)")
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundColor(isActive ? Color(red: 1, green: 0.25, blue: 0.25) : .white)

            Text("SCATTER")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.3))
                .tracking(1.5)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.04))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            isActive
                                ? Color(red: 1, green: 0.25, blue: 0.25).opacity(0.6)
                                : Color.white.opacity(0.08),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - EffectSlotView

struct EffectSlotView: View {
    let label: String
    let icon: String
    let hint: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(Color.white.opacity(0.15))

            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(Color.white.opacity(0.2))
                .tracking(1)

            Text(hint)
                .font(.system(size: 8))
                .foregroundColor(Color.white.opacity(0.1))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.white.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}

// MARK: - CalibrationBannerView

/// Shows warm-up countdown, then a brief "ready" flash, then disappears.
struct CalibrationBannerView: View {
    let state: CalibrationState
    @State private var showReady = false
    @State private var hideReady = false

    var body: some View {
        Group {
            switch state {
            case .warmingUp(let remaining):
                HStack(spacing: 10) {
                    Circle()
                        .fill(Color.zestGreen)
                        .frame(width: 7, height: 7)
                        .opacity(remaining % 2 == 0 ? 1.0 : 0.3)
                        .animation(.easeInOut(duration: 0.5), value: remaining)

                    Text("Reading your stride… \(remaining)s")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color.zestGreen.opacity(0.9))

                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.zestGreen.opacity(0.07))
                        .overlay(RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.zestGreen.opacity(0.2), lineWidth: 1))
                )
                .transition(.opacity.combined(with: .move(edge: .top)))

            case .active:
                if !hideReady {
                    HStack(spacing: 8) {
                        Image(systemName: "waveform.path.ecg")
                            .foregroundColor(Color.zestGreen)
                            .font(.system(size: 13))
                        Text("Pattern locked — adaptive detection on")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color.white.opacity(0.45))
                    }
                    .transition(.opacity)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { hideReady = true }
                        }
                    }
                }

            case .idle:
                EmptyView()
            }
        }
        .animation(.easeInOut(duration: 0.4), value: state == .active)
        .onChange(of: state) { _ in
            if case .warmingUp = state { hideReady = false }
        }
    }
}

// MARK: - Preview

#Preview {
    CurrentWorkoutView()
        .environmentObject(WorkoutManager())
        .environment(
            \.managedObjectContext,
             PersistenceController.preview.container.viewContext
        )
}
