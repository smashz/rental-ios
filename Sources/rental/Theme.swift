import SwiftUI
import UIKit

/// A color that adapts to light / dark mode.
private func dyn(_ light: UInt, _ dark: UInt) -> Color {
    Color(uiColor: UIColor { trait in
        trait.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
    })
}

private extension UIColor {
    convenience init(rgb: UInt) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Design tokens for the Rental app.
///
/// Accent is purple in both modes; dark mode uses a pure-black background with
/// slightly raised near-black cards, per the requested theme.
enum Theme {
    // Purple accent (constant across light/dark).
    static let accent = Color(uiColor: UIColor(rgb: 0x8B5CF6))
    static let accentDark = Color(uiColor: UIColor(rgb: 0x6D28D9))

    static let ink      = dyn(0x121719, 0xF2F2F7)   // primary text
    static let subtle   = dyn(0x6B7280, 0x9BA1A8)   // secondary text
    static let hairline = dyn(0xE6E8EB, 0x2A2A2E)   // dividers / borders
    static let surface  = dyn(0xFFFFFF, 0x141416)   // card background
    static let field    = dyn(0xF2F2F4, 0x1C1C1E)   // inputs / pills
    static let background = dyn(0xF6F6F8, 0x000000)  // screen background (black in dark)

    static let star = Color(uiColor: UIColor(rgb: 0xF5B800))

    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
}

/// A rounded card surface with a soft shadow.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.18), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

/// The full-width primary action button ("Request to book", "Continue").
struct PrimaryButton: View {
    let title: String
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(enabled ? Theme.accent : Theme.subtle.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        }
        .disabled(!enabled)
    }
}

/// Rounded "pill" used for filters and feature chips.
struct Pill: View {
    let text: String
    var systemImage: String? = nil
    var selected: Bool = false

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage) }
            Text(text)
        }
        .font(.subheadline.weight(.medium))
        .foregroundColor(selected ? .white : Theme.ink)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(selected ? Theme.accent : Theme.field)
        .clipShape(Capsule())
    }
}

/// Star rating + trip count.
struct RatingLabel: View {
    let rating: Double
    var trips: Int? = nil
    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "star.fill").foregroundColor(Theme.star).font(.caption)
            Text(String(format: "%.2f", rating)).font(.subheadline.weight(.semibold))
            if let trips {
                Text("(\(trips) trips)").font(.subheadline).foregroundColor(Theme.subtle)
            }
        }
    }
}
