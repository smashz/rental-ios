import SwiftUI

/// The listing detail page. Mirrors Turo's VehicleDetails flow: swipeable
/// photos, title + rating, host row, a specs grid, feature chips, the
/// description, and a sticky bottom bar with the price and primary CTA
/// ("Book instantly" for Instant Book cars, otherwise "Request to book").
struct VehicleDetailView: View {
    let vehicle: Vehicle
    @EnvironmentObject var store: DataStore
    @State private var showCheckout = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                photos
                VStack(alignment: .leading, spacing: 16) {
                    titleBlock
                    Divider().background(Theme.hairline)
                    hostRow
                    Divider().background(Theme.hairline)
                    specsGrid
                    featuresBlock
                    descriptionBlock
                    policies
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 120)
        }
        .ignoresSafeArea(edges: .top)
        .overlay(alignment: .bottom) { bottomBar }
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $showCheckout) {
            CheckoutView(vehicle: vehicle)
        }
    }

    private var photos: some View {
        TabView {
            ForEach(Array(photoURLs.enumerated()), id: \.offset) { _, url in
                VehiclePhoto(url: url, height: 300, corner: 0)
            }
        }
        .frame(height: 300)
        .tabViewStyle(.page(indexDisplayMode: photoURLs.count > 1 ? .automatic : .never))
    }

    /// At least one slide so the pager renders even for sample cars.
    private var photoURLs: [URL?] {
        vehicle.photos.isEmpty ? [nil] : vehicle.photos.map(URL.init(string:))
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(vehicle.title).font(.title.bold()).foregroundColor(Theme.ink)
            Text(vehicle.subtitle).font(.title3).foregroundColor(Theme.subtle)
            HStack(spacing: 10) {
                RatingLabel(rating: vehicle.rating, trips: vehicle.trips)
                Text("·").foregroundColor(Theme.subtle)
                Text(vehicle.city).font(.subheadline).foregroundColor(Theme.subtle)
            }
        }
    }

    private var hostRow: some View {
        HStack(spacing: 12) {
            Circle().fill(Theme.accent.opacity(0.15))
                .frame(width: 48, height: 48)
                .overlay(Text(String(vehicle.hostName.prefix(1)))
                    .font(.headline).foregroundColor(Theme.accentDark))
            VStack(alignment: .leading, spacing: 2) {
                Text("Hosted by \(vehicle.hostName)").font(.headline).foregroundColor(Theme.ink)
                Text("Typically responds within an hour").font(.subheadline).foregroundColor(Theme.subtle)
            }
            Spacer()
        }
    }

    private var specsGrid: some View {
        let specs: [(String, String)] = [
            ("person.2.fill", "\(vehicle.seats) seats"),
            ("car.fill", "\(vehicle.doors) doors"),
            ("gearshift.layout.sixspeed", vehicle.transmission),
            ("fuelpump.fill", vehicle.fuelType),
            (vehicle.unlimitedMiles ? "infinity" : "road.lanes", vehicle.unlimitedMiles ? "Unlimited miles" : "Mileage limit"),
            (vehicle.instantBook ? "bolt.fill" : "checkmark.seal.fill", vehicle.instantBook ? "Instant Book" : "Request to book")
        ]
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
            ForEach(specs, id: \.1) { icon, label in
                HStack(spacing: 10) {
                    Image(systemName: icon).foregroundColor(Theme.accent).frame(width: 24)
                    Text(label).font(.subheadline).foregroundColor(Theme.ink)
                    Spacer()
                }
            }
        }
    }

    @ViewBuilder private var featuresBlock: some View {
        if !vehicle.features.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Features").font(.title3.bold()).foregroundColor(Theme.ink)
                FlowChips(items: vehicle.features)
            }
        }
    }

    private var descriptionBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("About this car").font(.title3.bold()).foregroundColor(Theme.ink)
            Text(vehicle.description).font(.body).foregroundColor(Theme.ink.opacity(0.85))
        }
    }

    private var policies: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Free cancellation up to 24h before trip", systemImage: "arrow.uturn.left.circle")
            Label("Protection plans available at checkout", systemImage: "shield.lefthalf.filled")
        }
        .font(.subheadline).foregroundColor(Theme.subtle)
    }

    private var bottomBar: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 0) {
                Text(vehicle.dailyPrice.money(vehicle.currency)).font(.title3.bold())
                    .foregroundColor(Theme.ink)
                Text("per day").font(.caption).foregroundColor(Theme.subtle)
            }
            Spacer()
            Button { showCheckout = true } label: {
                Text(vehicle.instantBook ? "Book instantly" : "Request to book")
                    .font(.headline).foregroundColor(.white)
                    .padding(.horizontal, 28).padding(.vertical, 16)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.controlRadius, style: .continuous))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.hairline), alignment: .top)
    }
}

/// A simple wrapping chip layout for feature tags.
struct FlowChips: View {
    let items: [String]
    var body: some View {
        FlexibleView(data: items, spacing: 8, lineSpacing: 8) { item in
            Text(item)
                .font(.subheadline)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Theme.field)
                .clipShape(Capsule())
                .foregroundColor(Theme.ink)
        }
    }
}

/// Minimal flexible (wrapping) layout so feature chips reflow on any width.
struct FlexibleView<Data: Collection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let content: (Data.Element) -> Content

    @State private var totalHeight: CGFloat = .zero

    var body: some View {
        GeometryReader { geo in
            self.layout(in: geo)
        }
        .frame(height: totalHeight)
    }

    private func layout(in geo: GeometryProxy) -> some View {
        var x: CGFloat = 0
        var y: CGFloat = 0
        return ZStack(alignment: .topLeading) {
            ForEach(Array(data), id: \.self) { item in
                content(item)
                    .alignmentGuide(.leading) { d in
                        if abs(x - d.width) > geo.size.width {
                            x = 0; y -= d.height + lineSpacing
                        }
                        let result = x
                        if item == data.reversed().first { x = 0 } else { x -= d.width + spacing }
                        return result
                    }
                    .alignmentGuide(.top) { _ in
                        let result = y
                        if item == data.reversed().first { y = 0 }
                        return result
                    }
            }
        }
        .background(heightReader)
    }

    private var heightReader: some View {
        GeometryReader { geo -> Color in
            DispatchQueue.main.async { totalHeight = geo.size.height }
            return Color.clear
        }
    }
}
