import SwiftUI

/// A trip's message thread, shared by renter and host. Loads the trip's
/// messages from the backend, marks them read on open, and sends new ones.
struct MessageThreadView: View {
    let tripID: String
    let title: String
    @EnvironmentObject var store: DataStore

    @State private var messages: [Message] = []
    @State private var draft = ""
    @State private var loading = true
    @State private var sending = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        if loading {
                            ProgressView().padding(.top, 40)
                        } else if messages.isEmpty {
                            emptyState
                        } else {
                            ForEach(messages) { bubble($0) }
                        }
                    }
                    .padding(16)
                }
                .onChange(of: messages.count) { _ in
                    if let last = messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                }
            }
            composer
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await load() }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40)).foregroundColor(Theme.subtle)
            Text("No messages yet").font(.headline).foregroundColor(Theme.ink)
            Text("Say hello to coordinate pickup, keys and questions.")
                .font(.subheadline).foregroundColor(Theme.subtle)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 60).padding(.horizontal, 32)
    }

    private func bubble(_ m: Message) -> some View {
        HStack {
            if m.mine { Spacer(minLength: 40) }
            VStack(alignment: m.mine ? .trailing : .leading, spacing: 3) {
                Text(m.body)
                    .foregroundColor(m.mine ? .white : Theme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(m.mine ? Theme.accent : Theme.field)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                Text(Self.time(m.createdAt)).font(.caption2).foregroundColor(Theme.subtle)
            }
            if !m.mine { Spacer(minLength: 40) }
        }
        .id(m.id)
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Message…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Theme.field)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .lineLimit(1...4)
            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(canSend ? Theme.accent : Theme.subtle)
            }
            .disabled(!canSend)
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.hairline), alignment: .top)
    }

    private var canSend: Bool {
        !sending && !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func load() async {
        loading = true
        messages = await store.loadMessages(tripId: tripID)
        loading = false
    }

    private func send() {
        let text = draft
        guard canSend else { return }
        sending = true
        draft = ""
        Task {
            if let msg = await store.sendMessage(tripId: tripID, body: text) {
                messages.append(msg)
            } else {
                draft = text   // restore so the user doesn't lose it
            }
            sending = false
        }
    }

    static func time(_ d: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "MMM d, h:mm a"
        return f.string(from: d)
    }
}
