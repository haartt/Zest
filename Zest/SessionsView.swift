import SwiftUI
internal import CoreData

/// Displays all past WorkoutSession records, newest first.
/// Supports swipe-to-delete.
struct SessionsView: View {

    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        fetchRequest: WorkoutSession.newestFirstRequest,
        animation: .default
    )
    private var sessions: FetchedResults<WorkoutSession>

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("Sessions")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                EditButton()
                    .tint(.zestGreen)
            }
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 56))
                .foregroundColor(Color.zestGreen.opacity(0.3))

            Text("No sessions yet")
                .font(.headline)
                .foregroundColor(Color.white.opacity(0.5))

            Text("Finish a run and it'll appear here")
                .font(.subheadline)
                .foregroundColor(Color.white.opacity(0.25))
        }
    }

    private var sessionList: some View {
        List {
            ForEach(sessions) { session in
                SessionRowView(session: session)
                    .listRowBackground(Color.white.opacity(0.04))
                    .listRowSeparatorTint(Color.white.opacity(0.07))
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete(perform: deleteSessions)
        }
        .scrollContentBackground(.hidden)
        .listStyle(.plain)
    }

    // MARK: - Actions

    private func deleteSessions(at offsets: IndexSet) {
        offsets.map { sessions[$0] }.forEach(context.delete)
        try? context.save()
    }
}

// MARK: - SessionRowView

struct SessionRowView: View {
    let session: WorkoutSession

    var body: some View {
        HStack(spacing: 14) {
            // Icon
            ZStack {
                Circle()
                    .fill(Color.zestGreen.opacity(0.12))
                    .frame(width: 46, height: 46)
                Image(systemName: "figure.run")
                    .font(.system(size: 19))
                    .foregroundColor(.zestGreen)
            }

            // Track + genre + duration
            VStack(alignment: .leading, spacing: 5) {
                Text(session.trackName ?? "Unknown Track")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if let genre = session.genre, !genre.isEmpty {
                        Text(genre)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.zestGreen)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.zestGreen.opacity(0.1))
                            .cornerRadius(6)
                    }

                    Label(formattedDuration, systemImage: "timer")
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.4))
                        .labelStyle(.titleAndIcon)
                }
            }

            Spacer()

            // Date
            if let date = session.date {
                VStack(alignment: .trailing, spacing: 3) {
                    Text(date, style: .date)
                        .font(.system(size: 11))
                        .foregroundColor(Color.white.opacity(0.3))
                    Text(date, style: .time)
                        .font(.system(size: 10))
                        .foregroundColor(Color.white.opacity(0.2))
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var formattedDuration: String {
        let d = Int(session.durationSeconds)
        if d >= 3600 {
            return String(format: "%dh %02dm", d / 3600, (d % 3600) / 60)
        } else {
            return String(format: "%d:%02d", d / 60, d % 60)
        }
    }
}

// MARK: - Preview

#Preview {
    SessionsView()
        .environment(
            \.managedObjectContext,
             PersistenceController.preview.container.viewContext
        )
}
