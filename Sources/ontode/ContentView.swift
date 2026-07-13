import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        Group {
            if !appState.hasFolders {
                WelcomeView()
            } else {
                NavigationSplitView {
                    FileListView()
                        .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 320)
                } detail: {
                    FileReaderView()
                        .toolbar {
                            ToolbarItem {
                                Button(action: { appState.toggleTheme() }) {
                                    Label(
                                        "Toggle Theme",
                                        systemImage: appState.theme == .dark ? "sun.max" : "moon"
                                    )
                                }
                                .help("Switch between Light and Dark (⇧⌘L)")
                            }
                        }
                }
            }
        }
        .sheet(isPresented: $appState.quickOpenPresented) {
            QuickOpenView()
                .environmentObject(appState)
                .environment(\.appTheme, appState.theme)
        }
        .environment(\.appTheme, appState.theme)
        .preferredColorScheme(appState.theme.colorScheme)
        .tint(appState.theme.accent)
    }
}
