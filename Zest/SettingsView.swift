import SwiftUI

struct SettingsView: View {
    @AppStorage(ZestSettings.Keys.slowPaceSecondsPerKm) private var slowPace: Double = ZestSettings.Defaults.slowPaceSecondsPerKm
    @AppStorage(ZestSettings.Keys.mediumPaceSecondsPerKm) private var mediumPace: Double = ZestSettings.Defaults.mediumPaceSecondsPerKm
    @AppStorage(ZestSettings.Keys.fastPaceSecondsPerKm) private var fastPace: Double = ZestSettings.Defaults.fastPaceSecondsPerKm

    var body: some View {
        NavigationStack {
            Form {
                Section("Pace thresholds (min/km)") {
                    paceRow(title: "Slow", secondsPerKm: $slowPace, range: 240...900)
                    paceRow(title: "Medium", secondsPerKm: $mediumPace, range: 180...720)
                    paceRow(title: "Fast", secondsPerKm: $fastPace, range: 150...600)

                    Text("These values control the audio low‑pass filter cutoff. Faster pace → higher cutoff (more open sound).")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Live mapping preview") {
                    let t = ZestSettings.orderedSpeedThresholds()
                    LabeledContent("Slow speed", value: formatSpeed(t.slow))
                    LabeledContent("Medium speed", value: formatSpeed(t.medium))
                    LabeledContent("Fast speed", value: formatSpeed(t.fast))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Settings")
        }
        .tint(.zestGreen)
    }

    @ViewBuilder
    private func paceRow(title: String, secondsPerKm: Binding<Double>, range: ClosedRange<Double>) -> some View {
        let minutes = Int(secondsPerKm.wrappedValue) / 60
        let seconds = Int(secondsPerKm.wrappedValue) % 60

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                Spacer()
                Text(String(format: "%d:%02d /km", minutes, seconds))
                    .fontDesign(.monospaced)
                    .foregroundStyle(.secondary)
            }

            Slider(value: secondsPerKm, in: range, step: 5)
        }
        .padding(.vertical, 4)
    }

    private func formatSpeed(_ mps: Float) -> String {
        String(format: "%.2f m/s", mps)
    }
}

#Preview {
    SettingsView()
        .preferredColorScheme(.dark)
}

