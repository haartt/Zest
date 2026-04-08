import SwiftUI
import UniformTypeIdentifiers

/// Home tab: choose Library genre or Import a track, then Start.
/// Library scans bundled `tracks/<genre>/*.(mp3|m4a|wav|aac|flac)`.
struct HomeView: View {

    @EnvironmentObject var workoutManager: WorkoutManager

    private enum SourceMode {
        case library
        case `import`
    }

    @State private var genres: [String] = []
    @State private var tracksByGenre: [String: [URL]] = [:]
    @State private var selectedGenre: String = ""
    @State private var selectedTrack: URL? = nil
    @State private var showFilePicker = false
    @State private var importedName: String?  = nil
    @State private var sourceMode: SourceMode = .library
    @State private var randomFromGenre = true

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Picker("Source", selection: sourceModeBinding) {
                        Text("Library").tag(SourceMode.library)
                        Text("Import").tag(SourceMode.import)
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(Color.clear)

                switch sourceMode {
                case .library:
                    libraryRows
                case .import:
                    importRows
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) { startBar }
            .navigationTitle("Zest")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear { reloadLibrary() }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio]
        ) { result in
            handleImport(result)
        }
    }

    private var startBar: some View {
        VStack(spacing: 10) {
            Button(action: startWorkout) {
                Text("START")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(canStart ? Color.zestGreen : Color.gray.opacity(0.4))
                    .cornerRadius(14)
            }
            .disabled(!canStart)
            .frame(maxWidth: 340)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        .background(.black.opacity(0.92))
    }

    private var sourceModeBinding: Binding<SourceMode> {
        Binding(
            get: { sourceMode },
            set: { newValue in
                sourceMode = newValue
                if newValue == .import {
                    // Keep Import consistent with HIG: selecting Import brings file picker.
                    showFilePicker = true
                } else {
                    importedName = nil
                    selectedTrack = nil
                    workoutManager.selectedTrackURL = nil
                }
            }
        )
    }

    private var libraryRows: some View {
        Group {
            Section("Genre") {
                if genres.isEmpty {
                    Text("No bundled tracks found. Make sure your audio is under `tracks/<genre>/` in the app bundle.")
                        .foregroundStyle(.secondary)
                } else {
                    Picker("Genre", selection: $selectedGenre) {
                        ForEach(genres, id: \.self) { g in
                            Text(g).tag(g)
                        }
                    }
                    .pickerStyle(.menu)

                    Toggle("Random song on start", isOn: $randomFromGenre)
                }
            }

            Section("Tracks") {
                let tracks = tracksByGenre[selectedGenre] ?? []
                if tracks.isEmpty {
                    Text("No tracks in this genre.")
                        .foregroundStyle(.secondary)
                } else if randomFromGenre {
                    Text("\(tracks.count) tracks available.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(tracks, id: \.self) { url in
                        HStack {
                            Text(url.deletingPathExtension().lastPathComponent)
                                .lineLimit(1)
                            Spacer()
                            if selectedTrack == url {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.zestGreen)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedTrack = url
                            workoutManager.selectedTrackURL = url
                            workoutManager.selectedGenre = selectedGenre
                        }
                    }
                }
            }
        }
    }

    private var importRows: some View {
        Group {
            Section("Imported track") {
                if let importedName {
                    Text(importedName)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } else {
                    Text("No file imported yet.")
                        .foregroundStyle(.secondary)
                }

                Button("Import .mp3") {
                    showFilePicker = true
                }
                .tint(.zestGreen)
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 44))
                .foregroundColor(Color.white.opacity(0.12))
            Text("No tracks in this genre")
                .foregroundColor(Color.white.opacity(0.3))
                .font(.system(size: 15))
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Library scanning

    private func reloadLibrary() {
        let (g, map) = scanBundledTracks()
        genres = g
        tracksByGenre = map

        if selectedGenre.isEmpty || !genres.contains(selectedGenre) {
            selectedGenre = genres.first ?? ""
        }

        if sourceMode == .library {
            workoutManager.selectedGenre = selectedGenre
        }
    }

    // MARK: - Actions

    private func handleImport(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else { return }
            selectedTrack = url
            importedName  = url.deletingPathExtension().lastPathComponent
            workoutManager.selectedTrackURL = url
            workoutManager.selectedGenre    = "Imported"
        case .failure(let error):
            print("[HomeView] Import error: \(error)")
        }
    }

    private var canStart: Bool {
        switch sourceMode {
        case .library:
            let tracks = tracksByGenre[selectedGenre] ?? []
            if randomFromGenre { return !selectedGenre.isEmpty && !tracks.isEmpty }
            return selectedTrack != nil
        case .import:
            return workoutManager.selectedTrackURL != nil
        }
    }

    private func startWorkout() {
        switch sourceMode {
        case .library:
            guard !selectedGenre.isEmpty else { return }
            let tracks = tracksByGenre[selectedGenre] ?? []
            if randomFromGenre {
                guard let chosen = tracks.randomElement() else { return }
                workoutManager.selectedTrackURL = chosen
            } else {
                guard let chosen = selectedTrack else { return }
                workoutManager.selectedTrackURL = chosen
            }
            workoutManager.selectedGenre = selectedGenre
        case .import:
            break
        }
        workoutManager.start()
    }

    private func scanBundledTracks() -> (genres: [String], byGenre: [String: [URL]]) {
        let exts: Set<String> = ["mp3", "m4a", "wav", "aac", "flac"]
        var map: [String: [URL]] = [:]

        // Most robust approach: walk the app bundle and pick any audio under /tracks/<genre>/.
        if let root = Bundle.main.resourceURL,
           let e = FileManager.default.enumerator(at: root, includingPropertiesForKeys: nil) {
            for case let url as URL in e {
                guard exts.contains(url.pathExtension.lowercased()) else { continue }
                guard let genre = genreFromPath(url.pathComponents) else { continue }
                map[genre, default: []].append(url)
            }
        }

        // Fallback: if folder-walk fails, use Bundle API.
        if map.isEmpty {
            for ext in exts {
                let urls = (Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: "tracks") ?? [])
                for url in urls {
                    if let genre = genreFromPath(url.pathComponents) {
                        map[genre, default: []].append(url)
                    }
                }
            }
        }

        for k in map.keys {
            map[k] = (map[k] ?? []).sorted { $0.lastPathComponent < $1.lastPathComponent }
        }

        let genres = map.keys.sorted()
        return (genres, map)
    }

    private func genreFromPath(_ components: [String]) -> String? {
        // Extract ".../tracks/<genre>/<file>" from the path components.
        guard let idx = components.lastIndex(of: "tracks"), idx + 2 <= components.count else { return nil }
        let genre = components[idx + 1]
        return genre.isEmpty ? nil : genre
    }
}

// MARK: - GenrePill

struct GenrePill: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(isSelected ? .black : .zestGreen)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.zestGreen : Color.white.opacity(0.06))
                .clipShape(Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.zestGreen.opacity(isSelected ? 0 : 0.35), lineWidth: 1)
                )
        }
    }
}

// MARK: - TrackRow

struct TrackRow: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: isSelected ? "play.circle.fill" : "music.note")
                    .foregroundColor(isSelected ? .zestGreen : Color.white.opacity(0.35))
                    .font(.system(size: 20))
                    .frame(width: 26)

                Text(name)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.zestGreen)
                        .font(.system(size: 16))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected
                          ? Color.zestGreen.opacity(0.1)
                          : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.zestGreen.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(WorkoutManager())
}
