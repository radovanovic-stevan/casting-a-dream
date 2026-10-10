import SwiftUI

@main
struct CastingADreamApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Casting a Dream", id: "library") {
            LibraryView()
                .environmentObject(model)
                .environmentObject(model.covers)
                .frame(minWidth: 820, minHeight: 560)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1240, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) {}
            CommandMenu("Library") {
                Button("Find…") { model.searchFocusRequest += 1 }
                    .keyboardShortcut("f")
                Button("Rescan Library") { model.library.scan() }
                    .keyboardShortcut("r")
                Divider()
                ForEach(GameSystem.allCases) { system in
                    Button("Open \(system.displayName) Folder") { model.library.openFolder(system) }
                }
                Divider()
                Toggle("Launch Games Full Screen", isOn: $model.launchFullScreen)
                Button("Collection Export Folder…") { model.chooseCollectionExportFolder() }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Running the bare executable (swift run) has no bundle to make it a regular app.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
