import AppKit
import SwiftUI

@main
struct OntodeApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var updaterViewModel = CheckForUpdatesViewModel()

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
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(viewModel: updaterViewModel)
            }
            CommandGroup(replacing: .newItem) {
                Button("New File") {
                    appState.createNewFile()
                }
                .keyboardShortcut("n", modifiers: .command)
                .disabled(!appState.hasFolders)
                Button("Add Folder…") {
                    appState.openFolderPicker()
                }
                .keyboardShortcut("o", modifiers: .command)
            }
            CommandGroup(replacing: .saveItem) {
                Button("Save") {
                    appState.commitEditing()
                }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(appState.editingBlockID == nil)
                Divider()
                Button("Close Tab") {
                    appState.closeCurrentTab()
                }
                .keyboardShortcut("w", modifiers: .command)
                Button("Close Window") {
                    NSApp.keyWindow?.performClose(nil)
                }
                .keyboardShortcut("w", modifiers: [.command, .shift])
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
                Button(appState.showSource ? "Hide Raw Source" : "Show Raw Source") {
                    appState.toggleSource()
                }
                .keyboardShortcut("/", modifiers: .command)
                .disabled(appState.selectedFile == nil)
                Button(appState.theme == .dark ? "Switch to Light Theme" : "Switch to Dark Theme") {
                    appState.toggleTheme()
                }
                .keyboardShortcut("l", modifiers: [.command, .shift])
            }
            CommandMenu("Go") {
                Button("Next Tab") {
                    appState.selectAdjacentTab(1)
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(appState.openTabs.count < 2)
                Button("Previous Tab") {
                    appState.selectAdjacentTab(-1)
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(appState.openTabs.count < 2)
                Divider()
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
