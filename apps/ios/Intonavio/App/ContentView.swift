import SwiftUI

/// Root view with tab navigation (iOS) or sidebar navigation (macOS).
struct ContentView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        @Bindable var state = appState

        Group {
            #if os(iOS)
            TabView(selection: $state.selectedTab) {
                NavigationStack {
                    HomeView()
                }
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
                .tag(AppState.Tab.library)

                NavigationStack {
                    SessionHistoryView()
                }
                .tabItem {
                    Label("Sessions", systemImage: "clock.arrow.circlepath")
                }
                .tag(AppState.Tab.sessions)

                NavigationStack {
                    SettingsView()
                }
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(AppState.Tab.settings)
            }
            #else
            NavigationSplitView {
                List(selection: $state.selectedTab) {
                    Label("Library", systemImage: "music.note.list")
                        .tag(AppState.Tab.library)
                    Label("Sessions", systemImage: "clock.arrow.circlepath")
                        .tag(AppState.Tab.sessions)
                    Label("Settings", systemImage: "gearshape")
                        .tag(AppState.Tab.settings)
                }
                .navigationTitle("IntonavioLocal")
            } detail: {
                NavigationStack {
                    switch state.selectedTab {
                    case .library:
                        HomeView()
                    case .sessions:
                        SessionHistoryView()
                    case .settings:
                        SettingsView()
                    }
                }
            }
            .frame(minWidth: 900, minHeight: 600)
            #endif
        }
        .tint(Color.intonavioIce)
        .background(Color.intonavioBackground)
        .onAppear {
            WebViewPrewarmer.shared.warmUp()
        }
    }
}

#Preview {
    ContentView()
        .environment(AppState())
}
