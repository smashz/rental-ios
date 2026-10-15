import SwiftUI

/// The Trips tab (guest side). Mirrors Turo's Dashboard/BookedTrips: a
/// Booked vs. History segmented control over a list of trip cards.
struct TripsView: View {
    @EnvironmentObject var store: DataStore
    @State private var scope: Scope = .booked

    enum Scope: String, CaseIterable { case booked = "Booked", history = "History" }

    private var shown: [Trip] {
        store.trips.filter {
            scope == .booked ? ($0.status == .upcoming || $0.status == .inProgress)
                             : ($0.status == .completed || $0.status == .cancelled)
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
                            ForEach(shown) { TripRow(trip: $0) }
                        }
                        .padding(.horizontal, 16).padding(.bottom, 24)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Trips")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "suitcase").font(.system(size: 48)).foregroundColor(Theme.subtle)
            Text(scope == .booked ? "No booked trips yet" : "No past trips")
                .font(.headline).foregroundColor(Theme.ink)
            Text("When you book a car it'll show up here.")
                .font(.subheadline).foregroundColor(Theme.subtle)
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
                Text(trip.vehicleTitle).font(.headline).foregroundColor(Theme.ink)
                Text(trip.city).font(.subheadline).foregroundColor(Theme.subtle)
                Text(Self.range(trip.start, trip.end)).font(.subheadline).foregroundColor(Theme.subtle)
                HStack {
                    statusBadge
                    Spacer()
                    Text(trip.total.money(trip.currency)).font(.subheadline.bold()).foregroundColor(Theme.ink)
                }
            }
        }
        .padding(12)
        .card()
    }

    private var statusBadge: some View {
        Text(trip.status.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundColor(color)
            .clipShape(Capsule())
    }

    private var color: Color {
        switch trip.status {
        case .upcoming: return Theme.accent
        case .inProgress: return .blue
        case .completed: return Theme.subtle
        case .cancelled: return .red
        }
    }

    static func range(_ a: Date, _ b: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(f.string(from: a)) – \(f.string(from: b))"
    }
}
