import SwiftUI

/// The Trips tab. Shows every trip the signed-in user is part of — both the
/// cars they've booked (as guest) and bookings on their own cars (as host) —
/// split into Booked vs. History. Tapping a trip opens the shared detail
/// screen that both parties see. Data is live from the backend.
struct TripsView: View {
    @EnvironmentObject var store: DataStore
    @State private var scope: Scope = .booked

    enum Scope: String, CaseIterable { case booked = "Booked", history = "History" }

    private var shown: [Trip] {
        store.trips.filter {
            switch $0.status {
            case .requested, .upcoming, .inProgress: return scope == .booked
            case .completed, .cancelled, .declined:  return scope == .history
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $scope) {
                    ForEach(Scope.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(16)

                if shown.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(shown) { trip in
                                NavigationLink(value: trip) { TripRow(trip: trip) }
                                    .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 24)
                    }
                    .refreshable { await store.loadTrips() }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Trips")
            .navigationDestination(for: Trip.self) { TripDetailView(tripID: $0.id) }
            .task { await store.loadTrips() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "suitcase").font(.system(size: 48)).foregroundColor(Theme.subtle)
            Text(scope == .booked ? "No booked trips yet" : "No past trips")
                .font(.headline).foregroundColor(Theme.ink)
            Text("When you book a car — or someone books yours — it'll show up here.")
                .font(.subheadline).foregroundColor(Theme.subtle)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct TripRow: View {
    let trip: Trip
    var body: some View {
        HStack(spacing: 12) {
            VehiclePhoto(url: trip.photoURL, height: 80, corner: 10).frame(width: 110)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(trip.vehicleTitle).font(.headline).foregroundColor(Theme.ink)
                    if trip.isHost { roleTag }
                }
                Text(trip.city).font(.subheadline).foregroundColor(Theme.subtle)
                Text(Self.range(trip.start, trip.end)).font(.subheadline).foregroundColor(Theme.subtle)
                HStack {
                    statusBadge
                    if let n = trip.unreadCount, n > 0 { unreadDot(n) }
                    Spacer()
                    Text(trip.total.money(trip.currency)).font(.subheadline.bold()).foregroundColor(Theme.ink)
                }
            }
        }
        .padding(12)
        .card()
    }

    private var roleTag: some View {
        Text("Hosting")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Theme.accent.opacity(0.18))
            .foregroundColor(Theme.accent)
            .clipShape(Capsule())
    }

    private func unreadDot(_ n: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: "bubble.fill").font(.system(size: 9))
            Text("\(n)").font(.caption2.weight(.bold))
        }
        .foregroundColor(Theme.accent)
    }

    private var statusBadge: some View {
        Text(trip.status.label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch trip.status {
        case .requested: return .orange
        case .upcoming: return Theme.accent
        case .inProgress: return .blue
        case .completed: return Theme.subtle
        case .cancelled, .declined: return .red
        }
    }

    static func range(_ a: Date, _ b: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(f.string(from: a)) – \(f.string(from: b))"
    }
}
