import SwiftUI

/// The shared trip screen. The SAME trip is visible to both the renter and the
/// host; `trip.role` (set by the backend for the viewer) decides which status
/// actions appear. Everything here is persisted server-side.
struct TripDetailView: View {
    let tripID: String
    @EnvironmentObject var store: DataStore
    @State private var working = false

    /// Always read the freshest copy from the store so status changes reflect.
    private var trip: Trip? { store.trips.first { $0.id == tripID } }

    var body: some View {
        ScrollView {
            if let trip {
                VStack(alignment: .leading, spacing: 20) {
                    header(trip)
                    statusCard(trip)
                    partiesCard(trip)
                    detailsCard(trip)
                    messageLink(trip)
                    actions(trip)
                }
                .padding(16)
                .padding(.bottom, 24)
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Trip")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadTrips() }
    }

    // MARK: sections

    private func header(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VehiclePhoto(url: trip.photoURL, height: 180, corner: Theme.cardRadius)
            HStack(spacing: 6) {
                Text(trip.vehicleTitle).font(.title2.bold()).foregroundColor(Theme.ink)
                if trip.isHost {
                    Text("Hosting").font(.caption.weight(.bold))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Theme.accent.opacity(0.18)).foregroundColor(Theme.accent)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 12)
            Text(trip.city).font(.subheadline).foregroundColor(Theme.subtle)
        }
    }

    private func statusCard(_ trip: Trip) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Status").font(.caption).foregroundColor(Theme.subtle)
                Text(trip.status.label).font(.headline).foregroundColor(statusColor(trip.status))
            }
            Spacer()
            Image(systemName: statusIcon(trip.status))
                .font(.title2).foregroundColor(statusColor(trip.status))
        }
        .padding(16).card()
    }

    private func partiesCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            partyRow(label: trip.isHost ? "Guest" : "Host",
                     name: trip.counterpartyName ?? (trip.isHost ? trip.renterName : trip.hostName) ?? "—")
            Divider().background(Theme.hairline)
            partyRow(label: "You", name: (trip.isHost ? trip.hostName : trip.renterName) ?? "You")
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func partyRow(label: String, name: String) -> some View {
        HStack(spacing: 12) {
            Circle().fill(Theme.accent.opacity(0.15)).frame(width: 40, height: 40)
                .overlay(Text(String(name.prefix(1))).font(.headline).foregroundColor(Theme.accentDark))
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption).foregroundColor(Theme.subtle)
                Text(name).font(.subheadline.weight(.semibold)).foregroundColor(Theme.ink)
            }
            Spacer()
        }
    }

    private func detailsCard(_ trip: Trip) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Trip details").font(.title3.bold()).foregroundColor(Theme.ink)
            infoRow("calendar", "Dates", Self.dateRange(trip.start, trip.end))
            infoRow("clock", "Duration", "\(Self.nights(trip.start, trip.end)) days")
            if let plan = trip.plan, !plan.isEmpty {
                infoRow("shield.lefthalf.filled", "Protection", plan)
            }
            Divider().background(Theme.hairline)
            HStack {
                Text("Total").font(.headline).foregroundColor(Theme.ink)
                Spacer()
                Text(trip.total.money(trip.currency)).font(.headline).foregroundColor(Theme.ink)
            }
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading).card()
    }

    private func infoRow(_ icon: String, _ label: String, _ value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundColor(Theme.accent).frame(width: 24)
            Text(label).foregroundColor(Theme.subtle)
            Spacer()
            Text(value).foregroundColor(Theme.ink).fontWeight(.medium)
        }
        .font(.subheadline)
    }

    private func messageLink(_ trip: Trip) -> some View {
        NavigationLink {
            MessageThreadView(tripID: trip.id, title: trip.counterpartyName ?? "Messages")
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill").foregroundColor(Theme.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Message \(trip.counterpartyName ?? (trip.isHost ? "guest" : "host"))")
                        .font(.headline).foregroundColor(Theme.ink)
                    if let last = trip.lastMessage, !last.isEmpty {
                        Text(last).font(.subheadline).foregroundColor(Theme.subtle).lineLimit(1)
                    } else {
                        Text("Start the conversation").font(.subheadline).foregroundColor(Theme.subtle)
                    }
                }
                Spacer()
                if let n = trip.unreadCount, n > 0 {
                    Text("\(n)").font(.caption.bold()).foregroundColor(.white)
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Theme.accent).clipShape(Capsule())
                }
                Image(systemName: "chevron.right").font(.caption).foregroundColor(Theme.subtle)
            }
            .padding(16).card()
        }
        .buttonStyle(.plain)
    }

    // MARK: actions (role-gated, mirroring the backend's allowed transitions)

    @ViewBuilder private func actions(_ trip: Trip) -> some View {
        let options = transitions(for: trip)
        if !options.isEmpty {
            VStack(spacing: 10) {
                ForEach(options, id: \.self) { opt in
                    Button {
                        perform(trip, to: opt.target)
                    } label: {
                        Text(opt.title)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(opt.destructive ? Color.red.opacity(0.15) : Theme.accent)
                            .foregroundColor(opt.destructive ? .red : .white)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
                    }
                    .disabled(working)
                }
            }
        }
    }

    private struct Action: Hashable { let title: String; let target: Trip.Status; let destructive: Bool }

    private func transitions(for trip: Trip) -> [Action] {
        if trip.isHost {
            switch trip.status {
            case .requested:  return [Action(title: "Confirm booking", target: .upcoming, destructive: false),
                                      Action(title: "Decline", target: .declined, destructive: true)]
            case .upcoming:   return [Action(title: "Start trip", target: .inProgress, destructive: false),
                                      Action(title: "Cancel trip", target: .cancelled, destructive: true)]
            case .inProgress: return [Action(title: "Complete trip", target: .completed, destructive: false)]
            default:          return []
            }
        } else {
            switch trip.status {
            case .requested, .upcoming:
                return [Action(title: "Cancel trip", target: .cancelled, destructive: true)]
            default:
                return []
            }
        }
    }

    private func perform(_ trip: Trip, to status: Trip.Status) {
        guard !working else { return }
        working = true
        Task {
            await store.setTripStatus(trip, to: status)
            working = false
        }
    }

    // MARK: helpers

    private func statusColor(_ s: Trip.Status) -> Color {
        switch s {
        case .requested: return .orange
        case .upcoming: return Theme.accent
        case .inProgress: return .blue
        case .completed: return .green
        case .cancelled, .declined: return .red
        }
    }

    private func statusIcon(_ s: Trip.Status) -> String {
        switch s {
        case .requested: return "hourglass"
        case .upcoming: return "checkmark.circle.fill"
        case .inProgress: return "car.fill"
        case .completed: return "flag.checkered"
        case .cancelled, .declined: return "xmark.circle.fill"
        }
    }

    static func dateRange(_ a: Date, _ b: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, h:mm a"
        return "\(f.string(from: a)) → \(f.string(from: b))"
    }
    static func nights(_ a: Date, _ b: Date) -> Int {
        max(1, Calendar.current.dateComponents([.day], from: a, to: b).day ?? 1)
    }
}
