import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.16, green: 0.19, blue: 0.30),
                                Color(red: 0.09, green: 0.10, blue: 0.16),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 84, height: 84)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                Text("md")
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            VStack(spacing: 6) {
                Text("No Folders Open")
                    .font(.title2.weight(.semibold))
                Text("Browse, search, and edit the Markdown files in one or more folders.")
                    .foregroundStyle(.secondary)
            }
            Button("Add Folder…") {
                appState.openFolderPicker()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Text("or drop folders here — ⌘O")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(appState.theme.canvas)
        .dropDestination(for: URL.self) { urls, _ in
            let directories = urls.filter {
                (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            guard !directories.isEmpty else { return false }
            for directory in directories {
                appState.addFolder(directory)
            }
            return true
        }
    }
}
