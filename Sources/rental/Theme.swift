import SwiftUI

/// Design tokens for the Rental app.
///
/// The visual language is modelled on the Turo decrypted bundle we analysed:
/// a light, content-forward marketplace with large car photography, pill
/// filters, rounded cards and a single confident accent colour used for the
/// primary "Request to book" action. Turo ships a custom face ("TuroSans");
/// we use the system font so the app is self-contained.
enum Theme {
    // Accent — a confident marketplace green/teal in the spirit of Turo's brand.
    static let accent = Color(red: 0.00, green: 0.55, blue: 0.47)
    static let accentDark = Color(red: 0.00, green: 0.42, blue: 0.36)

    static let ink = Color(red: 0.07, green: 0.09, blue: 0.11)      // near-black text
    static let subtle = Color(red: 0.42, green: 0.45, blue: 0.49)   // secondary text
    static let hairline = Color(red: 0.90, green: 0.91, blue: 0.93) // dividers
    static let surface = Color(.systemBackground)
    static let field = Color(red: 0.96, green: 0.96, blue: 0.97)

    static let star = Color(red: 0.95, green: 0.72, blue: 0.20)

    static let cardRadius: CGFloat = 16
    static let controlRadius: CGFloat = 12
}

/// A rounded card surface with a soft shadow — the recurring container used by
/// vehicle cards, trip rows and host tiles.
struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

extension View {
    func card() -> some View { modifier(CardStyle()) }
}

/// The full-width primary action button ("Request to book", "Continue"),
/// mirroring Turo's sticky bottom CTA.
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

/// Star rating + trip count, used on cards and detail pages.
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
