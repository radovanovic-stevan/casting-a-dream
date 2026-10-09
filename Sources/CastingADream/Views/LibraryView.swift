import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var searchFocused: Bool
    @State private var input = InputRouter()

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderBar(searchFocused: $searchFocused)
                content
                FooterHints()
            }

            if let game = model.launcher.running {
                PlayingOverlay(game: game)
                    .transition(.opacity)
            }
        }
        .background(WindowConfigurator())
        .animation(.easeOut(duration: 0.2), value: model.launcher.running)
        .onAppear {
            input.install(model: model)
            model.library.scan()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Picks up games added in Finder while the launcher was in the background.
            model.library.scan()
        }
        .onChange(of: model.searchFocusRequest) { searchFocused = true }
        .alert("Couldn't start the game", isPresented: errorShown) {
            Button("OK") {}
        } message: {
            Text(model.launcher.errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.library.hasScanned && model.library.games.isEmpty {
            EmptyLibraryView()
        } else if model.library.hasScanned && model.visibleGames.isEmpty {
            NoMatchesView()
        } else {
            GameGrid()
        }
    }

    private var errorShown: Binding<Bool> {
        Binding(get: { model.launcher.errorMessage != nil },
                set: { if !$0 { model.launcher.errorMessage = nil } })
    }
}

// MARK: - Header

struct HeaderBar: View {
    @EnvironmentObject private var model: AppModel
    var searchFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 14) {
            NeonRing(size: 24)
            Text("Casting a Dream")
                .font(.system(size: 19, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize()

            Spacer(minLength: 20)

            FilterPills()
            SearchField(text: $model.search, focused: searchFocused)
            SortMenu()
            CollectionButton()
        }
        .padding(.horizontal, Theme.pagePadding)
        .padding(.top, 38)   // room for the window buttons
        .padding(.bottom, 18)
    }
}

struct FilterPills: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SystemFilter.allCases, id: \.self) { filter in
                let selected = model.filter == filter
                Button {
                    model.filter = filter
                } label: {
                    HStack(spacing: 6) {
                        Text(filter.title)
                        Text("\(model.count(for: filter))")
                            .foregroundStyle(selected ? Theme.textPrimary.opacity(0.7) : Theme.textSecondary.opacity(0.7))
                            .monospacedDigit()
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(selected ? Theme.textPrimary : Theme.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background {
                        if selected {
                            Capsule().fill(Theme.surfaceRaised)
                                .overlay(Capsule().strokeBorder(Theme.neon, lineWidth: 1))
                        }
                    }
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline))
        .help("Switch systems with L1 / R1 on a controller")
    }
}

struct SearchField: View {
    @Binding var text: String
    var focused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.textSecondary)
            TextField("Search", text: $text)
                .textFieldStyle(.plain)
                .focused(focused)
            if !text.isEmpty {
                Button { text = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .font(.system(size: 13))
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .frame(width: 200)
        .background(Theme.surface, in: Capsule())
        .overlay(Capsule().strokeBorder(focused.wrappedValue ? Theme.violet.opacity(0.8) : Theme.hairline))
    }
}

struct SortMenu: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Menu {
            Picker("Sort By", selection: $model.sort) {
                ForEach(LibrarySort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 32, height: 30)
                .background(Theme.surface, in: Circle())
                .overlay(Circle().strokeBorder(Theme.hairline))
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Sort: \(model.sort.rawValue)")
    }
}

struct CollectionButton: View {
    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(Collection.home)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "square.stack.3d.up.fill")
                Text("My Collection")
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 10, weight: .bold))
            }
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(hovering ? Theme.collectionHover : Theme.collection, in: Capsule())
            .shadow(color: Theme.collection.opacity(hovering ? 0.6 : 0.3), radius: hovering ? 12 : 6)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .onHover { hovering = $0 }
        .help("collection.stevan.co.rs")
    }
}

// MARK: - Footer

struct FooterHints: View {
    var body: some View {
        HStack(spacing: 22) {
            hint("return", "Play")
            hint("arrow.up.and.down.and.arrow.left.and.right", "Navigate")
            hint("l1.rectangle.roundedbottom", "Switch system", alt: "R1")
            hint("command", "F  Search")
            Spacer()
            Text("Games open in Flycast or PPSSPP. Quit there to come back here.")
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
        }
        .font(.system(size: 11, weight: .medium))
        .foregroundStyle(Theme.textSecondary)
        .padding(.horizontal, Theme.pagePadding)
        .padding(.vertical, 10)
        .background(Theme.background)
        .overlay(alignment: .top) { Rectangle().fill(Theme.hairline).frame(height: 1) }
    }

    private func hint(_ symbol: String, _ label: String, alt: String? = nil) -> some View {
        HStack(spacing: 5) {
            Image(systemName: symbol)
            if let alt { Text("/ \(alt)") }
            Text(label)
        }
    }
}
