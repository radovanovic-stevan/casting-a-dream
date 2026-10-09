import AppKit
import Combine

enum SystemFilter: Hashable, CaseIterable {
    case all
    case system(GameSystem)

    static var allCases: [SystemFilter] { [.all] + GameSystem.allCases.map { .system($0) } }

    var title: String {
        switch self {
        case .all: "All"
        case .system(let system): system.displayName
        }
    }
}

enum LibrarySort: String, CaseIterable {
    case recent = "Recently Played"
    case title = "Title"
}

@MainActor
final class AppModel: ObservableObject {
    let library = Library()
    let launcher = EmulatorLauncher()
    let covers = CoverArtStore()

    @Published var filter: SystemFilter = .all {
        didSet { keepSelectionVisible() }
    }
    @Published var search = "" {
        didSet { keepSelectionVisible() }
    }
    @Published var sort: LibrarySort {
        didSet { UserDefaults.standard.set(sort.rawValue, forKey: "sort") }
    }
    @Published var launchFullScreen: Bool {
        didSet { UserDefaults.standard.set(launchFullScreen, forKey: "launchFullScreen") }
    }
    @Published var selectedID: Game.ID?
    /// Bumped to move keyboard focus into the search field.
    @Published var searchFocusRequest = 0

    /// Set by the grid from its width, used for up/down navigation.
    var gridColumns = 1

    private var cancellables: Set<AnyCancellable> = []

    init() {
        let defaults = UserDefaults.standard
        sort = defaults.string(forKey: "sort").flatMap(LibrarySort.init(rawValue:)) ?? .recent
        launchFullScreen = defaults.object(forKey: "launchFullScreen") as? Bool ?? false

        // Views observe this model only, so pass on changes from the parts.
        for publisher in [library.objectWillChange, launcher.objectWillChange] {
            publisher.sink { [weak self] _ in self?.objectWillChange.send() }.store(in: &cancellables)
        }
    }

    // MARK: - What the grid shows

    var visibleGames: [Game] {
        var games = library.games
        if case .system(let system) = filter {
            games = games.filter { $0.system == system }
        }
        let query = search.trimmingCharacters(in: .whitespaces)
        if !query.isEmpty {
            games = games.filter { $0.name.localizedCaseInsensitiveContains(query) }
        }
        switch sort {
        case .title:
            return games.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .recent:
            let played = library.lastPlayed
            return games.sorted { a, b in
                switch (played[a.id], played[b.id]) {
                case let (x?, y?): return x > y
                case (_?, nil): return true
                case (nil, _?): return false
                case (nil, nil): return a.title.localizedStandardCompare(b.title) == .orderedAscending
                }
            }
        }
    }

    /// The most recently played game, shown as the "Continue playing" banner on the unfiltered view.
    var heroGame: Game? {
        guard filter == .all, search.isEmpty else { return nil }
        let played = library.lastPlayed
        return library.games
            .filter { played[$0.id] != nil }
            .max { played[$0.id]! < played[$1.id]! }
    }

    func count(for filter: SystemFilter) -> Int {
        switch filter {
        case .all: library.games.count
        case .system(let system): library.games.filter { $0.system == system }.count
        }
    }

    // MARK: - Actions

    func play(_ game: Game) {
        selectedID = game.id
        launcher.launch(game, fullScreen: launchFullScreen) { [weak self] in
            self?.library.markPlayed(game)
        }
    }

    func playSelected() {
        guard let id = selectedID, let game = visibleGames.first(where: { $0.id == id }) else {
            selectFirstIfNeeded()
            return
        }
        play(game)
    }

    /// Arrow keys / D-pad: dx moves within a row, dy moves a whole row.
    func moveSelection(dx: Int, dy: Int) {
        let games = visibleGames
        guard !games.isEmpty else { return }
        guard let id = selectedID, let index = games.firstIndex(where: { $0.id == id }) else {
            selectedID = games[0].id
            return
        }
        let target = index + dx + dy * max(gridColumns, 1)
        selectedID = games[min(max(target, 0), games.count - 1)].id
    }

    func cycleFilter(by step: Int) {
        let filters = SystemFilter.allCases
        let index = filters.firstIndex(of: filter) ?? 0
        filter = filters[(index + step + filters.count) % filters.count]
    }

    func selectFirstIfNeeded() {
        if selectedID == nil || !visibleGames.contains(where: { $0.id == selectedID }) {
            selectedID = visibleGames.first?.id
        }
    }

    private func keepSelectionVisible() {
        if let id = selectedID, !visibleGames.contains(where: { $0.id == id }) {
            selectedID = nil
        }
    }
}
