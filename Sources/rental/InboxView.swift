import SwiftUI

/// The Inbox tab. Mirrors Turo's Conversations list.
struct InboxView: View {
    @EnvironmentObject var store: DataStore

    var body: some View {
        NavigationStack {
            Group {
                if store.conversations.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 48)).foregroundColor(Theme.subtle)
                        Text("No messages yet").font(.headline).foregroundColor(Theme.ink)
                    }
                } else {
                    List(store.conversations) { c in
                        HStack(spacing: 12) {
                            Circle().fill(Theme.accent.opacity(0.15)).frame(width: 46, height: 46)
                                .overlay(Text(String(c.name.prefix(1)))
                                    .font(.headline).foregroundColor(Theme.accentDark))
                            VStack(alignment: .leading, spacing: 3) {
                                HStack {
                                    Text(c.name).font(.headline).foregroundColor(Theme.ink)
                                    if c.unread {
                                        Circle().fill(Theme.accent).frame(width: 8, height: 8)
                                    }
                                }
                                Text(c.vehicle).font(.caption).foregroundColor(Theme.subtle)
                                Text(c.lastMessage).font(.subheadline).foregroundColor(Theme.subtle)
                                    .lineLimit(1)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Inbox")
        }
    }
}
