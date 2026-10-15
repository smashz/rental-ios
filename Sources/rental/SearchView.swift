import SwiftUI

/// The marketplace landing screen. Mirrors Turo's Search tab: a prominent
/// "Where to?" search field, a horizontal row of filter pills, then a vertical
/// feed of large vehicle cards.
struct SearchView: View {
    @EnvironmentObject var store: DataStore
    @State private var query = ""
    @State private var instantOnly = false
    @State private var electricOnly = false

    var filtered: [Vehicle] {
        store.vehicles.filter { v in
            (query.isEmpty
             || v.title.localizedCaseInsensitiveContains(query)
             || v.city.localizedCaseInsensitiveContains(query))
            && (!instantOnly || v.instantBook)
            && (!electricOnly || v.fuelType == "Electric")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    searchField
                    filterPills
                    if case .failed(let msg) = store.loadState {
                        offlineBanner(msg)
                    }
                    header
                    ForEach(filtered) { vehicle in
                        NavigationLink(value: vehicle) {
                            VehicleCard(vehicle: vehicle)
                        }
                        .buttonStyle(.plain)
                    }
                    if filtered.isEmpty {
                        Text("No cars match your search.")
                            .foregroundColor(Theme.subtle)
                            .padding(.top, 40)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
            .background(Theme.field.opacity(0.35).ignoresSafeArea())
            .navigationTitle("Explore cars")
            .navigationDestination(for: Vehicle.self) { VehicleDetailView(vehicle: $0) }
            .refreshable { await store.refresh() }
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundColor(Theme.subtle)
            TextField("Where to? City, airport, address", text: $query)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14).padding(.vertical, 14)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.controlRadius).stroke(Theme.hairline, lineWidth: 1))
        .padding(.top, 8)
    }

    private var filterPills: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                Button { } label: { Pill(text: "Dates", systemImage: "calendar") }
                Button { instantOnly.toggle() } label: {
                    Pill(text: "Instant Book", systemImage: "bolt.fill", selected: instantOnly)
                }
                Button { electricOnly.toggle() } label: {
                    Pill(text: "Electric", systemImage: "leaf.fill", selected: electricOnly)
                }
                Button { } label: { Pill(text: "Price", systemImage: "slider.horizontal.3") }
            }
        }
    }

    private var header: some View {
        HStack {
            Text("\(filtered.count) cars available")
                .font(.title3.bold()).foregroundColor(Theme.ink)
            Spacer()
            if store.usingLiveData {
                Label("Live", systemImage: "dot.radiowaves.left.and.right")
                    .font(.caption.weight(.semibold))
                    .foregroundColor(Theme.accent)
            }
        }
    }

    private func offlineBanner(_ msg: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.exclamationmark")
            Text(msg).font(.footnote)
            Spacer()
        }
        .foregroundColor(Theme.subtle)
        .padding(12)
        .background(Theme.field)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A single vehicle card in the feed: hero photo, save button, title,
/// rating and the per-day price.
struct VehicleCard: View {
    @EnvironmentObject var store: DataStore
    let vehicle: Vehicle

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topTrailing) {
                VehiclePhoto(url: vehicle.heroURL, height: 200, corner: Theme.cardRadius)
                Button { store.toggleSaved(vehicle.id) } label: {
                    Image(systemName: store.isSaved(vehicle.id) ? "heart.fill" : "heart")
                        .foregroundColor(store.isSaved(vehicle.id) ? .red : .white)
                        .padding(10)
                        .background(.black.opacity(0.25), in: Circle())
                }
                .padding(10)
                if vehicle.instantBook {
                    Label("Instant Book", systemImage: "bolt.fill")
                        .font(.caption2.weight(.bold))
                        .foregroundColor(Theme.ink)
                        .padding(.horizontal, 8).padding(.vertical, 5)
                        .background(.white, in: Capsule())
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(vehicle.title).font(.headline).foregroundColor(Theme.ink)
                    Spacer()
                    RatingLabel(rating: vehicle.rating, trips: vehicle.trips)
                }
                Text(vehicle.subtitle).font(.subheadline).foregroundColor(Theme.subtle)
                Text(vehicle.city).font(.subheadline).foregroundColor(Theme.subtle)
                HStack(spacing: 4) {
                    Text(vehicle.dailyPrice.money(vehicle.currency)).font(.subheadline.bold())
                        .foregroundColor(Theme.ink)
                    Text("/ day").font(.subheadline).foregroundColor(Theme.subtle)
                }
                .padding(.top, 2)
            }
            .padding(14)
        }
        .card()
    }
}
