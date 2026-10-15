import SwiftUI

@main
struct RentalApp: App {
    @StateObject private var store = DataStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if store.isAuthenticated {
                    RootView()
                } else {
                    AuthView()
                }
            }
            .environmentObject(store)
            .tint(Theme.accent)
            .task {
                await store.restoreSession()
                await store.refresh()
            }
        }
    }
}

/// Bottom tab bar mirroring Turo's five-tab layout:
/// Search · Trips · Host · Inbox · Account.
struct RootView: View {
    var body: some View {
        TabView {
            SearchView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
            TripsView()
                .tabItem { Label("Trips", systemImage: "suitcase.fill") }
            HostView()
                .tabItem { Label("Host", systemImage: "car.2.fill") }
            InboxView()
                .tabItem { Label("Inbox", systemImage: "bubble.left.and.bubble.right.fill") }
            ProfileView()
                .tabItem { Label("Account", systemImage: "person.crop.circle") }
        }
    }
}

/// Async car photo with a branded gradient + glyph placeholder, used wherever
/// a vehicle image appears. Falls back gracefully when no photo URL resolves
/// (e.g. the sample inventory, or while the dashboard image loads).
struct VehiclePhoto: View {
    let url: URL?
    var height: CGFloat = 220
    var corner: CGFloat = Theme.cardRadius

    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        placeholder
                    case .empty:
                        ZStack { placeholder; ProgressView() }
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
    }

    private var placeholder: some View {
        LinearGradient(
            colors: [Theme.accent.opacity(0.85), Theme.accentDark],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "car.side.fill")
                .font(.system(size: 54, weight: .regular))
                .foregroundColor(.white.opacity(0.85))
        )
    }
}
