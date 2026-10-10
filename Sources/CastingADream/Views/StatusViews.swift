import SwiftUI

struct EmptyLibraryView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 18) {
            NeonRing(size: 72)
                .padding(.bottom, 8)
            Text("Your library is empty")
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text("Put each game in its own folder inside one of these, then come back.")
                .foregroundStyle(Theme.textSecondary)
            VStack(spacing: 10) {
                ForEach(GameSystem.allCases) { system in
                    HStack(spacing: 12) {
                        SystemChip(system: system)
                        Text("~/Games/\(system.folderName)")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                        Text(system.extensions.map { ".\($0)" }.joined(separator: " "))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSecondary)
                        Spacer()
                        Button("Open") { model.library.openFolder(system) }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(width: 520)
                    .background(Theme.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Theme.hairline))
                }
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct NoMatchesView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(Theme.textSecondary)
            Text(model.search.isEmpty ? "No \(model.filter.title) games yet" : "Nothing matches “\(model.search)”")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
            if !model.search.isEmpty {
                Button("Clear Search") { model.search = "" }
            } else if case .system(let system) = model.filter {
                Button("Open \(system.displayName) Folder") { model.library.openFolder(system) }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Covers the library while a game runs in its emulator.
struct PlayingOverlay: View {
    let game: Game
    @EnvironmentObject private var model: AppModel
    @State private var pulse = false

    var body: some View {
        ZStack {
            Theme.background.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 18) {
                NeonRing(size: 64)
                    .scaleEffect(pulse ? 1.06 : 0.96)
                    .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: pulse)
                Text("Playing \(game.title)")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text("The game is open in \(game.system.emulatorName). Quit it there (⌘Q) or stop it here to come back to your library.")
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                HStack(spacing: 12) {
                    Button("Show Game") { model.launcher.showRunningGame() }
                        .keyboardShortcut(.defaultAction)
                    Button("Stop Game", role: .destructive) { model.launcher.stopRunningGame() }
                }
                .controlSize(.large)
                .padding(.top, 4)
            }
        }
        .onAppear { pulse = true }
    }
}

/// Window chrome: black background, dragging by the background, no title text.
struct WindowConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isMovableByWindowBackground = true
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.backgroundColor = NSColor(Theme.background)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
