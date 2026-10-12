import SwiftUI

struct GameGrid: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GeometryReader { geometry in
            let available = geometry.size.width - Theme.pagePadding * 2
            let columns = max(1, Int((available + Theme.cardSpacing) / (Theme.cardWidth + Theme.cardSpacing)))

            ScrollViewReader { proxy in
                ScrollView {
                    let sections = model.visibleSections
                    VStack(alignment: .leading, spacing: 30) {
                        if let hero = model.heroGame {
                            HeroBanner(game: hero)
                        }
                        if !sections.regular.isEmpty {
                            grid(sections.regular, columns: columns)
                        }
                        // Homebrew starts on a row of its own under a header; moveSelection counts rows the same way.
                        if !sections.homebrew.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HomebrewHeader(count: sections.homebrew.count)
                                grid(sections.homebrew, columns: columns)
                            }
                        }
                    }
                    .padding(.horizontal, Theme.pagePadding)
                    .padding(.top, 6)
                    .padding(.bottom, 32)
                }
                .scrollIndicators(.automatic)
                .onChange(of: model.selectedID) { _, id in
                    guard let id else { return }
                    withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(id) }
                }
            }
            .onAppear { model.gridColumns = columns }
            .onChange(of: columns) { _, value in model.gridColumns = value }
        }
    }

    private func grid(_ games: [Game], columns: Int) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.fixed(Theme.cardWidth), spacing: Theme.cardSpacing, alignment: .top),
                                 count: columns),
                  alignment: .leading, spacing: 28) {
            ForEach(games) { game in
                GameCard(game: game, isSelected: model.selectedID == game.id)
                    .id(game.id)
            }
        }
    }
}

/// Divider above the homebrew games: label in the "Continue playing" style, then a hairline to the edge.
struct HomebrewHeader: View {
    let count: Int

    var body: some View {
        HStack(spacing: 10) {
            Label("HOMEBREW", systemImage: "hammer.fill")
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .tracking(1.6)
                .foregroundStyle(Theme.neon)
            Text("\(count)")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.textSecondary.opacity(0.7))
                .monospacedDigit()
            Rectangle()
                .fill(Theme.hairline)
                .frame(height: 1)
        }
        .padding(.top, 4)
        .help("My own ROM hacks, marked by a homebrew.txt in their folder. They're not in My Collection.")
    }
}

/// Corner tag on a homebrew game's cover, so it stands out in search results and "All" too.
struct HomebrewBadge: View {
    var body: some View {
        Label("HOMEBREW", systemImage: "hammer.fill")
            .labelStyle(BadgeLabelStyle())
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(Theme.magenta)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(.black.opacity(0.7), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.magenta.opacity(0.5), lineWidth: 0.5))
            .fixedSize()
            .help("Homebrew")
    }

    private struct BadgeLabelStyle: LabelStyle {
        func makeBody(configuration: Configuration) -> some View {
            HStack(spacing: 3) {
                configuration.icon
                configuration.title
            }
        }
    }
}

struct GameCard: View {
    let game: Game
    let isSelected: Bool
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var covers: CoverArtStore
    @State private var hovering = false

    private var highlighted: Bool { isSelected || hovering }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            CoverView(game: game, image: covers.images[game.id])
                .frame(width: Theme.cardWidth, height: Theme.cardWidth * 4 / 3)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(highlighted ? AnyShapeStyle(Theme.neon) : AnyShapeStyle(Theme.hairline),
                                      lineWidth: highlighted ? 2 : 1)
                }
                .overlay(alignment: .topLeading) {
                    if game.isHomebrew {
                        HomebrewBadge().padding(7)
                    }
                }
                .overlay {
                    if hovering {
                        PlayGlyph()
                            .onTapGesture { model.play(game) }
                    }
                }
                .shadow(color: highlighted ? game.system.accent.opacity(0.45) : .black.opacity(0.4),
                        radius: highlighted ? 18 : 8, y: highlighted ? 0 : 4)
                .scaleEffect(highlighted ? 1.03 : 1)

            Text(game.title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)

            Label(model.playTimeText(for: game), systemImage: "clock")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)

            HStack(spacing: 5) {
                SystemChip(system: game.system)
                if let progress = model.trophies.progress(for: game) {
                    TrophyBadge(game: game, progress: progress)
                }
                Spacer(minLength: 4)
                // Homebrew isn't in the collection, so there's nothing to link to.
                if !game.isHomebrew {
                    CollectionLink(game: game)
                }
            }
        }
        .frame(width: Theme.cardWidth, alignment: .leading)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .onTapGesture(count: 2) { model.play(game) }
        .onTapGesture { model.selectedID = game.id }
        .onAppear { covers.load(game) }
        .animation(.easeOut(duration: 0.15), value: highlighted)
        .contextMenu {
            Button("Play") { model.play(game) }
            if model.trophies.trophySet(for: game) != nil {
                Button("Trophies…") { model.trophySheetGame = game }
            }
            if !game.isHomebrew {
                Button("Open in My Collection") { NSWorkspace.shared.open(Collection.url(for: game)) }
            }
            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([game.url]) }
        }
        .help(game.name)
    }
}

/// Small violet button that opens this game in collection.stevan.co.rs.
struct CollectionLink: View {
    let game: Game
    @State private var hovering = false

    var body: some View {
        Button {
            NSWorkspace.shared.open(Collection.url(for: game))
        } label: {
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 18)
                .background(hovering ? Theme.collectionHover : Theme.collection, in: Capsule())
                .shadow(color: Theme.collection.opacity(hovering ? 0.6 : 0), radius: 6)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Open \(game.title) in My Collection")
    }
}

struct PlayGlyph: View {
    var body: some View {
        Image(systemName: "play.fill")
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 52, height: 52)
            .background(.black.opacity(0.55), in: Circle())
            .overlay(Circle().strokeBorder(Theme.neon, lineWidth: 1.5))
            .shadow(color: Theme.violet.opacity(0.8), radius: 12)
            .contentShape(Circle())
    }
}

/// Box art fitted over a blurred copy of itself, so square Dreamcast and tall PSP covers
/// both fill the card. Without art: a dark tile with the neon ring and the title.
struct CoverView: View {
    let game: Game
    let image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .blur(radius: 18)
                    .opacity(0.55)
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                LinearGradient(colors: [Theme.surfaceRaised, Theme.background], startPoint: .top, endPoint: .bottom)
                VStack(spacing: 14) {
                    NeonRing(size: 44)
                    Text(game.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary.opacity(0.85))
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 14)
                }
            }
        }
        .background(Theme.surface)
    }
}

// MARK: - Continue playing

struct HeroBanner: View {
    let game: Game
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var covers: CoverArtStore
    @State private var hovering = false

    var body: some View {
        let image = covers.images[game.id]
        HStack(spacing: 26) {
            CoverView(game: game, image: image)
                .frame(width: 120, height: 160)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline))
                .shadow(color: game.system.accent.opacity(0.35), radius: 16)

            VStack(alignment: .leading, spacing: 10) {
                Text("CONTINUE PLAYING")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(Theme.neon)
                Text(game.title)
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    SystemChip(system: game.system)
                    if let date = model.library.lastPlayed[game.id] {
                        Text("Played \(date.formatted(.relative(presentation: .named))) · \(model.playTimeText(for: game))")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Button {
                    model.play(game)
                } label: {
                    Label("Play", systemImage: "play.fill")
                        .font(.system(size: 13.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 9)
                        .background(Theme.neon, in: Capsule())
                        .shadow(color: Theme.violet.opacity(hovering ? 0.9 : 0.5), radius: hovering ? 16 : 10)
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .onHover { hovering = $0 }
                .padding(.top, 6)
            }
            Spacer(minLength: 0)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Theme.surface
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: 40)
                        .opacity(0.35)
                }
                LinearGradient(colors: [Theme.background.opacity(0.2), Theme.background.opacity(0.85)],
                               startPoint: .leading, endPoint: .trailing)
            }
            .clipped()
        }
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(Theme.hairline))
        .onAppear { covers.load(game) }
    }
}
