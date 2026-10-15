import SwiftUI

/// The Account tab. Mirrors Turo's Account screen: profile header plus
/// grouped settings rows.
struct ProfileView: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Circle().fill(Theme.accent.opacity(0.15)).frame(width: 60, height: 60)
                            .overlay(Image(systemName: "person.fill")
                                .font(.title2).foregroundColor(Theme.accentDark))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Alex Rivera").font(.title3.bold()).foregroundColor(Theme.ink)
                            Text("Joined 2024 · \(store.savedIDs.count) saved")
                                .font(.subheadline).foregroundColor(Theme.subtle)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("Account") {
                    row("person.text.rectangle", "Driver profile")
                    row("creditcard", "Payment methods")
                    row("checkmark.shield", "Verification")
                    row("bell", "Notifications")
                }

                Section("Hosting") {
                    row("car.2", "Your listings")
                    row("dollarsign.circle", "Earnings")
                    row("calendar", "Availability")
                }

                Section("Support") {
                    row("questionmark.circle", "Help center")
                    row("doc.text", "Legal")
                }

                Section {
                    Text("Rental — UI modelled on an analysis of the Turo iOS bundle. Independent demo; not affiliated with Turo.")
                        .font(.caption).foregroundColor(Theme.subtle)
                }
            }
            .navigationTitle("Account")
        }
    }

    private func row(_ icon: String, _ title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).foregroundColor(Theme.accent).frame(width: 26)
            Text(title).foregroundColor(Theme.ink)
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(Theme.subtle)
        }
    }
}
