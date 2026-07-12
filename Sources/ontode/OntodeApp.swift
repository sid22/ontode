import SwiftUI

@main
struct OntodeApp: App {
    @StateObject private var appState = AppState()

    init() {
        AppIcon.install()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 860, minHeight: 520)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Add Folder…") {
                    appState.openFolderPicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .printItem) {
                Button("Quick Open…") {
                    appState.quickOpenPresented = true
                }
                .keyboardShortcut("p", modifiers: .command)
                .disabled(!appState.hasFolders)
            }
            CommandGroup(after: .textEditing) {
                Divider()
                Button("Edit Block") {
                    appState.beginEditingFocusedBlock()
                }
                .keyboardShortcut("e", modifiers: .command)
                .disabled(appState.selectedFile == nil || appState.editingBlockID != nil)
                Button("Done Editing") {
                    appState.commitEditing()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(appState.editingBlockID == nil)
            }
            CommandGroup(after: .sidebar) {
                Divider()
                Button(appState.theme == .solarizedDark ? "Switch to Solarized Light" : "Switch to Solarized Dark") {
                    appState.toggleTheme()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
            CommandMenu("Go") {
                Button("Previous File") {
                    appState.selectAdjacentFile(-1)
                }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
                .disabled(appState.mdFiles.isEmpty)
                Button("Next File") {
                    appState.selectAdjacentFile(1)
                }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
                .disabled(appState.mdFiles.isEmpty)
            }
        }
    }
}
