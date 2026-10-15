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
                        Circle().fill(Theme.accent.opacity(0.18)).frame(width: 60, height: 60)
                            .overlay(Text(String((store.currentUser?.name ?? "?").prefix(1)))
                                .font(.title2.bold()).foregroundColor(Theme.accent))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.currentUser?.name ?? "Guest").font(.title3.bold()).foregroundColor(Theme.ink)
                            Text(store.currentUser?.email ?? "—")
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
                    Button(role: .destructive) { store.logout() } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Log out")
                        }
                    }
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
