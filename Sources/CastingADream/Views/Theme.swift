import SwiftUI

/// Black with neon, matching the app icon.
enum Theme {
    static let background = Color(hex: 0x050507)
    static let surface = Color(hex: 0x0E0E14)
    static let surfaceRaised = Color(hex: 0x16161F)
    static let hairline = Color.white.opacity(0.08)
    static let textPrimary = Color(hex: 0xF4F4F8)
    static let textSecondary = Color(hex: 0x8A8A9A)

    static let cyan = Color(hex: 0x00F0FF)
    static let violet = Color(hex: 0x7A5CFF)
    static let magenta = Color(hex: 0xFF2BD6)
    static let ice = Color(hex: 0x8FE3FF)
    /// Accent of collection.stevan.co.rs.
    static let collection = Color(hex: 0x5B4CF0)
    static let collectionHover = Color(hex: 0x6E60FF)

    static let neon = LinearGradient(colors: [cyan, violet, magenta], startPoint: .topLeading, endPoint: .bottomTrailing)

    static let cardWidth: CGFloat = 168
    static let cardSpacing: CGFloat = 24
    static let pagePadding: CGFloat = 32
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }
}

/// The app icon's open ring with a glowing dot in the gap.
struct NeonRing: View {
    var size: CGFloat
    var glow = true

    var body: some View {
        let line = size * 0.13
        let radius = (size - line) / 2
        ZStack {
            Circle()
                .trim(from: 0, to: 300.0 / 360.0)
                .stroke(Theme.neon, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .rotationEffect(.degrees(-15))
            Circle()
                .fill(Theme.cyan)
                .frame(width: line * 1.1, height: line * 1.1)
                .offset(x: radius * cos(-.pi / 4), y: radius * sin(-.pi / 4))
        }
        .frame(width: size, height: size)
        .shadow(color: glow ? Theme.violet.opacity(0.9) : .clear, radius: size * 0.12)
        .shadow(color: glow ? Theme.cyan.opacity(0.5) : .clear, radius: size * 0.3)
    }
}

struct SystemChip: View {
    let system: GameSystem

    var body: some View {
        Text(system.displayName.uppercased())
            .font(.system(size: 9.5, weight: .bold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(system.accent)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(system.accent.opacity(0.12), in: Capsule())
            .overlay(Capsule().strokeBorder(system.accent.opacity(0.35), lineWidth: 0.5))
            .fixedSize()
    }
}
