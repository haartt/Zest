/// ──────────────────────────────────────────────────────────────────────────
/// WatchStubView.swift  —  Zest watchOS Companion (Stub)
/// ──────────────────────────────────────────────────────────────────────────
/// How to use:
///   1. File → New → Target → watchOS App (choose "Watch App for Existing iOS App")
///   2. Copy this file into the watchOS target
///   3. Replace `@main` entry point body with `WatchWorkoutView()`
///   4. Use WatchConnectivity (WCSession) to push updates from iOS
///
/// This view is intentionally self-contained — no shared EnvironmentObjects.
/// ──────────────────────────────────────────────────────────────────────────

import SwiftUI

struct WatchWorkoutView: View {
    var elapsedSeconds: Int  = 0
    var trackName: String    = "—"
    var isActive: Bool       = false
    var speed: Float         = 0
    var scatterCount: Int    = 0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 6) {
                // Status dot
                Circle()
                    .fill(isActive ? Color.green : Color.gray.opacity(0.4))
                    .frame(width: 8, height: 8)

                // Timer
                Text(formattedTime)
                    .font(.system(size: 34, weight: .black, design: .monospaced))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.6)

                // Speed
                Label(String(format: "%.1f m/s", speed), systemImage: "speedometer")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.green)

                // Track
                Text(trackName)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .padding(.horizontal, 8)

                // Scatter count
                if scatterCount > 0 {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                        Text("\(scatterCount)")
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding()
        }
    }

    private var formattedTime: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}

// MARK: - Preview (visible in watchOS simulator)
#Preview {
    WatchWorkoutView(
        elapsedSeconds: 1823,
        trackName: "Night Runner",
        isActive: true,
        speed: 3.2,
        scatterCount: 4
    )
}
