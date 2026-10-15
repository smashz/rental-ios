import SwiftUI

/// The Inbox tab. Every trip is a conversation between its renter and host,
/// so the inbox is the list of the user's trips, each opening that trip's
/// message thread. Unread counts come from the backend.
struct InboxView: View {
    @EnvironmentObject var store: DataStore

    /// Trips that have a conversation, most recently active first (unread first).
    private var threads: [Trip] {
        store.trips.sorted {
            let a = ($0.unreadCount ?? 0) > 0, b = ($1.unreadCount ?? 0) > 0
            if a != b { return a }
            return $0.start > $1.start
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if threads.isEmpty {
                    emptyState
                } else {
                    List(threads) { trip in
                        NavigationLink {
                            MessageThreadView(tripID: trip.id, title: trip.counterpartyName ?? "Messages")
                        } label: {
                            row(trip)
                        }
                        .listRowBackground(Theme.background)
                    }
                    .listStyle(.plain)
                    .refreshable { await store.loadTrips() }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Inbox")
            .task { await store.loadTrips() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48)).foregroundColor(Theme.subtle)
            Text("No messages yet").font(.headline).foregroundColor(Theme.ink)
            Text("Book a car or list one — your trip conversations show up here.")
                .font(.subheadline).foregroundColor(Theme.subtle)
                .multilineTextAlignment(.center).padding(.horizontal, 40)
        }
    }

    private func row(_ trip: Trip) -> some View {
        let name = trip.counterpartyName ?? "Host"
        let unread = (trip.unreadCount ?? 0) > 0
        return HStack(spacing: 12) {
            Circle().fill(Theme.accent.opacity(0.15)).frame(width: 46, height: 46)
                .overlay(Text(String(name.prefix(1)))
                    .font(.headline).foregroundColor(Theme.accentDark))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(name).font(.headline).foregroundColor(Theme.ink)
                    if trip.isHost {
                        Text("Guest").font(.caption2.weight(.bold))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(Theme.accent.opacity(0.15)).foregroundColor(Theme.accent)
                            .clipShape(Capsule())
                    }
                    if unread { Circle().fill(Theme.accent).frame(width: 8, height: 8) }
                }
                Text(trip.vehicleTitle).font(.caption).foregroundColor(Theme.subtle)
                Text(trip.lastMessage ?? "No messages yet")
                    .font(.subheadline)
                    .foregroundColor(unread ? Theme.ink : Theme.subtle)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
