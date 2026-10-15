import SwiftUI

/// The Host tab (owner side). Mirrors Turo's host surfaces: an earnings
/// summary, a "List your car" entry point, and the owner's current listings.
/// In this project, owners actually create listings in the web Client
/// Dashboard (./dashboard); those uploads then appear in Search via the API.
struct HostView: View {
    @EnvironmentObject var store: DataStore

    // Treat the catalogue as "your cars" for the host demo.
    private var myCars: [Vehicle] { store.vehicles }
    private var monthEarnings: Double { myCars.reduce(0) { $0 + $1.dailyPrice * 6 } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    earningsCard
                    listCTA
                    Text("Your listings").font(.title3.bold()).foregroundColor(Theme.ink)
                    ForEach(myCars) { car in
                        HostListingRow(vehicle: car)
                    }
                }
                .padding(16).padding(.bottom, 24)
            }
            .background(Theme.field.opacity(0.35).ignoresSafeArea())
            .navigationTitle("Host")
        }
    }

    private var earningsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Estimated earnings this month").font(.subheadline).foregroundColor(.white.opacity(0.85))
            Text(monthEarnings.money("USD")).font(.system(size: 34, weight: .bold)).foregroundColor(.white)
            HStack(spacing: 16) {
                stat("\(myCars.count)", "Cars")
                stat("\(myCars.reduce(0) { $0 + $1.trips })", "Trips")
                stat(String(format: "%.2f", avgRating), "Rating")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: [Theme.accent, Theme.accentDark],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    private var avgRating: Double {
        myCars.isEmpty ? 0 : myCars.reduce(0) { $0 + $1.rating } / Double(myCars.count)
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline).foregroundColor(.white)
            Text(label).font(.caption).foregroundColor(.white.opacity(0.85))
        }
    }

    private var listCTA: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("List your car", systemImage: "plus.circle.fill")
                .font(.headline).foregroundColor(Theme.ink)
            Text("Add a new car, photos, pricing and availability in the Client Dashboard. New listings appear here and in Search automatically.")
                .font(.subheadline).foregroundColor(Theme.subtle)
            HStack(spacing: 6) {
                Image(systemName: "globe")
                Text("localhost:3000  ·  web dashboard")
            }
            .font(.footnote.weight(.medium)).foregroundColor(Theme.accent)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

struct HostListingRow: View {
    let vehicle: Vehicle
    var body: some View {
        HStack(spacing: 12) {
            VehiclePhoto(url: vehicle.heroURL, height: 72, corner: 10).frame(width: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.title).font(.headline).foregroundColor(Theme.ink)
                Text(vehicle.dailyPrice.money(vehicle.currency) + " / day")
                    .font(.subheadline).foregroundColor(Theme.subtle)
                HStack(spacing: 6) {
                    Circle().fill(vehicle.available ? Theme.accent : Theme.subtle).frame(width: 8, height: 8)
                    Text(vehicle.available ? "Listed" : "Snoozed")
                        .font(.caption).foregroundColor(Theme.subtle)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundColor(Theme.subtle)
        }
        .padding(12)
        .card()
    }
}
