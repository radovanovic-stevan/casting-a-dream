import SwiftUI

struct GameGrid: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GeometryReader { geometry in
            let available = geometry.size.width - Theme.pagePadding * 2
            let columns = max(1, Int((available + Theme.cardSpacing) / (Theme.cardWidth + Theme.cardSpacing)))

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 30) {
                        if let hero = model.heroGame {
                            HeroBanner(game: hero)
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.fixed(Theme.cardWidth), spacing: Theme.cardSpacing, alignment: .top),
                                                 count: columns),
                                  alignment: .leading, spacing: 28) {
                            ForEach(model.visibleGames) { game in
                                GameCard(game: game, isSelected: model.selectedID == game.id)
                                    .id(game.id)
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
                Spacer(minLength: 4)
                CollectionLink(game: game)
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
            Button("Open in My Collection") { NSWorkspace.shared.open(Collection.url(for: game)) }
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
