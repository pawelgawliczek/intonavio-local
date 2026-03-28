import SwiftUI

struct HomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel = LibraryViewModel()
    private var network: NetworkMonitor { NetworkMonitor.shared }

    #if os(iOS)
    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]
    #else
    private let columns = [
        GridItem(.adaptive(minimum: 180, maximum: 250), spacing: 12)
    ]
    #endif

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                songSection
                Divider()
                exerciseSection
                Divider()
                recordingsSection
            }
            .padding(.vertical)
        }
        .background(Color.intonavioBackground.ignoresSafeArea())
        .navigationTitle("Library")
        .toolbar {
            if !network.isConnected {
                ToolbarItem(placement: .navigationBarLeading) {
                    Label("Offline", systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundStyle(Color.intonavioTextSecondary)
                }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    viewModel.showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(!network.isConnected)
            }
        }
        .sheet(isPresented: $viewModel.showAddSheet) {
            AddSongSheet(viewModel: viewModel)
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
            if viewModel.songs.isEmpty {
                viewModel.fetchSongs()
            }
        }
    }
}

// MARK: - Subviews

private extension HomeView {
    var songSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("My Songs")
                    .font(.title2.bold())
                Spacer()
                if viewModel.isLoading {
                    ProgressView()
                }
            }
            .padding(.horizontal)

            if viewModel.songs.isEmpty, !viewModel.isLoading {
                emptyState
            } else {
                songGrid
            }
        }
    }

    var songGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            ForEach(viewModel.songs, id: \.id) { song in
                let isAvailableOffline = isSongAvailableOffline(song)
                if !network.isConnected && !isAvailableOffline {
                    SongGridItemView(
                        song: song,
                        isOfflineUnavailable: true
                    )
                } else {
                    NavigationLink(value: song.id) {
                        SongGridItemView(song: song)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal)
        .navigationDestination(for: String.self) { songId in
            if let song = viewModel.songs.first(where: { $0.id == songId }) {
                SongPracticeView(
                    songId: song.id,
                    videoId: song.videoId,
                    songStems: song.stems,
                    songTitle: song.title,
                    songArtist: song.artist,
                    songDuration: song.duration
                )
            }
        }
    }

    func isSongAvailableOffline(_ song: SongModel) -> Bool {
        guard song.status == .ready else { return false }
        let hasStemFiles = song.stems.allSatisfy { stem in
            FileManager.default.fileExists(atPath: stem.localPath)
        }
        return hasStemFiles && LocalStorageService.pitchDataExists(songId: song.id)
    }

    var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.largeTitle)
                .foregroundStyle(Color.intonavioIce)
            Text("No songs yet")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Tap + to add a YouTube song")
                .font(.subheadline)
                .foregroundStyle(Color.intonavioTextSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.title2.bold())
                .padding(.horizontal)

            ExerciseSectionView()
        }
    }

    var recordingsSection: some View {
        RecordingsSectionView()
    }
}

#Preview {
    NavigationStack {
        HomeView()
    }
    .environment(AppState())
}
