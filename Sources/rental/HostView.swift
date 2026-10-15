import SwiftUI

/// The Host tab (owner side). Mirrors Turo's host surfaces: an earnings
/// summary, a "List your car" entry point, and the owner's current listings.
/// In this project, owners actually create listings in the web Client
/// Dashboard (./dashboard); those uploads then appear in Search via the API.
struct HostView: View {
    @EnvironmentObject var store: DataStore

    // The signed-in owner's own listings (from /api/vehicles/mine).
    private var myCars: [Vehicle] { store.myVehicles }
    private var monthEarnings: Double { myCars.reduce(0) { $0 + $1.dailyPrice * 6 } }

    // Bookings on this owner's cars (trips where the viewer is the host).
    private var hostTrips: [Trip] { store.trips.filter { $0.isHost } }
    private var pendingTrips: [Trip] { hostTrips.filter { $0.status == .requested } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    earningsCard
                    bookingsSection
                    listCTA
                    Text("Your listings").font(.title3.bold()).foregroundColor(Theme.ink)
                    Text("Tap a car to edit its details, pricing or availability.")
                        .font(.caption).foregroundColor(Theme.subtle)
                    if myCars.isEmpty {
                        Text("No cars yet. Add one in the Client Dashboard and it'll appear here.")
                            .font(.subheadline).foregroundColor(Theme.subtle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(myCars) { car in
                            NavigationLink(value: car) { HostListingRow(vehicle: car) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16).padding(.bottom, 24)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Host")
            .navigationDestination(for: Vehicle.self) { EditListingView(vehicle: $0) }
            .navigationDestination(for: Trip.self) { TripDetailView(tripID: $0.id) }
            .refreshable { await store.loadMine(); await store.loadTrips() }
            .task { await store.loadTrips() }
        }
    }

    @ViewBuilder private var bookingsSection: some View {
        if !hostTrips.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Bookings on your cars").font(.title3.bold()).foregroundColor(Theme.ink)
                    Spacer()
                    if !pendingTrips.isEmpty {
                        Text("\(pendingTrips.count) to review")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Color.orange.opacity(0.18)).foregroundColor(.orange)
                            .clipShape(Capsule())
                    }
                }
                ForEach(hostTrips) { trip in
                    NavigationLink(value: trip) { HostTripRow(trip: trip) }
                        .buttonStyle(.plain)
                }
            }
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
            Image(systemName: "pencil").foregroundColor(Theme.accent)
        }
        .padding(12)
        .card()
    }
}

/// A booking on one of the owner's cars (host perspective).
struct HostTripRow: View {
    let trip: Trip
    var body: some View {
        HStack(spacing: 12) {
            VehiclePhoto(url: trip.photoURL, height: 60, corner: 10).frame(width: 84)
            VStack(alignment: .leading, spacing: 3) {
                Text(trip.vehicleTitle).font(.subheadline.bold()).foregroundColor(Theme.ink)
                Text("Guest: \(trip.renterName ?? trip.counterpartyName ?? "—")")
                    .font(.caption).foregroundColor(Theme.subtle)
                Text(TripRow.range(trip.start, trip.end)).font(.caption).foregroundColor(Theme.subtle)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(trip.status.label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(statusColor.opacity(0.15)).foregroundColor(statusColor)
                    .clipShape(Capsule())
                if let n = trip.unreadCount, n > 0 {
                    Image(systemName: "bubble.fill").font(.system(size: 10)).foregroundColor(Theme.accent)
                }
            }
        }
        .padding(10)
        .card()
    }

    private var statusColor: Color {
        switch trip.status {
        case .requested: return .orange
        case .upcoming: return Theme.accent
        case .inProgress: return .blue
        case .completed: return .green
        case .cancelled, .declined: return .red
        }
    }
}
