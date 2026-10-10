import SwiftUI

/// Gold "3/9" count on a game card; opens the trophy list.
struct TrophyBadge: View {
    let game: Game
    let progress: (earned: Int, total: Int)
    @EnvironmentObject private var model: AppModel
    @State private var hovering = false

    var body: some View {
        Button {
            model.trophySheetGame = game
        } label: {
            HStack(spacing: 3) {
                Image(systemName: "trophy.fill")
                Text("\(progress.earned)/\(progress.total)")
                    .monospacedDigit()
            }
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.gold)
            .padding(.horizontal, 6)
            .frame(height: 18)
            .background(Theme.gold.opacity(hovering ? 0.22 : 0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(Theme.gold.opacity(0.35), lineWidth: 0.5))
            .fixedSize()
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help("Trophies")
    }
}

/// Every trophy of one game, earned ones lit with their unlock date.
struct TrophiesView: View {
    let game: Game
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let store = model.trophies
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "trophy.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.gold)
                    .shadow(color: Theme.gold.opacity(0.6), radius: 8)
                VStack(alignment: .leading, spacing: 2) {
                    Text(game.title)
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                    if let progress = store.progress(for: game) {
                        Text("\(progress.earned) of \(progress.total) trophies")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)

            if let progress = store.progress(for: game) {
                ProgressView(value: Double(progress.earned), total: Double(max(progress.total, 1)))
                    .tint(Theme.gold)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 14)
            }

            Divider().overlay(Theme.hairline)

            ScrollView {
                VStack(spacing: 8) {
                    if let set = store.trophySet(for: game) {
                        ForEach(set.trophies) { trophy in
                            TrophyRow(trophy: trophy, unlockedOn: store.unlockDate(trophy, in: set))
                        }
                    }
                }
                .padding(16)
            }

            Text("Checked from the game's save whenever \(game.system.emulatorName) closes.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textSecondary)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(width: 440, height: 560)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}

private struct TrophyRow: View {
    let trophy: Trophy
    let unlockedOn: Date?

    var body: some View {
        let earned = unlockedOn != nil
        let hidden = trophy.secret && !earned
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(earned ? Theme.gold.opacity(0.18) : Color.white.opacity(0.04))
                    .overlay(Circle().strokeBorder(earned ? Theme.gold.opacity(0.6) : Theme.hairline))
                Image(systemName: earned ? trophy.symbol : "lock.fill")
                    .font(.system(size: earned ? 17 : 13, weight: .semibold))
                    .foregroundStyle(earned ? Theme.gold : Theme.textSecondary.opacity(0.6))
            }
            .frame(width: 40, height: 40)
            .shadow(color: earned ? Theme.gold.opacity(0.45) : .clear, radius: 8)

            VStack(alignment: .leading, spacing: 3) {
                Text(hidden ? "Secret trophy" : trophy.title)
                    .font(.system(size: 13.5, weight: .semibold))
                    .foregroundStyle(earned ? Theme.textPrimary : Theme.textSecondary)
                Text(hidden ? "Keep playing to find out." : trophy.detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            if let unlockedOn {
                Text(unlockedOn.formatted(date: .abbreviated, time: .omitted))
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.gold.opacity(0.85))
            }
        }
        .padding(10)
        .background(Theme.surface.opacity(earned ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(Theme.hairline))
    }
}

/// Pop-up for newly unlocked trophies, shown when the launcher comes back after a game.
struct TrophyToast: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if let first = model.trophies.announcements.first {
            let count = model.trophies.announcements.count
            Button {
                model.trophySheetGame = first.game
                model.trophies.announcements.removeAll()
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: first.trophy.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(Theme.gold)
                        .frame(width: 38, height: 38)
                        .background(Theme.gold.opacity(0.18), in: Circle())
                        .overlay(Circle().strokeBorder(Theme.gold.opacity(0.6)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(count > 1 ? "\(count) TROPHIES UNLOCKED" : "TROPHY UNLOCKED")
                            .font(.system(size: 10, weight: .heavy, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(Theme.gold)
                        Text(first.trophy.title)
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                        Text(first.game.title)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Theme.surfaceRaised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Theme.gold.opacity(0.5)))
                .shadow(color: Theme.gold.opacity(0.35), radius: 18)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Show trophies")
            .task(id: first.id) {
                // Each announcement stays a few seconds unless clicked.
                try? await Task.sleep(for: .seconds(6))
                if model.trophies.announcements.first?.id == first.id {
                    model.trophies.announcements.removeFirst()
                }
            }
        }
    }
}
