import SwiftUI

/// The booking flow. Mirrors Turo's Checkout: trip start/end pickers, a
/// pickup location row, a selectable protection plan, an itemised price
/// breakdown, and the final "Request to book" / "Confirm booking" CTA.
struct CheckoutView: View {
    let vehicle: Vehicle
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var start = Date()
    @State private var end = Calendar.current.date(byAdding: .day, value: 3, to: Date())!
    @State private var plan: ProtectionPlan = .standard
    @State private var confirmed = false
    @State private var booking = false
    @State private var bookedStatus: Trip.Status = .upcoming

    enum ProtectionPlan: String, CaseIterable, Identifiable {
        case minimum = "Minimum", standard = "Standard", premier = "Premier"
        var id: String { rawValue }
        var rate: Double {   // fraction of trip cost
            switch self { case .minimum: return 0.15; case .standard: return 0.25; case .premier: return 0.40 }
        }
        var blurb: String {
            switch self {
            case .minimum: return "$3,000 deductible"
            case .standard: return "$500 deductible"
            case .premier: return "$0 deductible"
            }
        }
    }

    private var nights: Int {
        max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
    }
    private var tripCost: Double { vehicle.dailyPrice * Double(nights) }
    private var protectionCost: Double { (tripCost * plan.rate).rounded() }
    private var serviceFee: Double { (tripCost * 0.10).rounded() }
    private var total: Double { tripCost + protectionCost + serviceFee }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryCard
                datesSection
                pickupSection
                protectionSection
                priceBreakdown
            }
            .padding(16)
            .padding(.bottom, 110)
        }
        .background(Theme.background.ignoresSafeArea())
        .overlay(alignment: .bottom) { cta }
        .navigationTitle("Checkout")
        .navigationBarTitleDisplayMode(.inline)
        .alert(bookedStatus == .requested ? "Request sent!" : "You're all set!", isPresented: $confirmed) {
            Button("View trip") { dismiss() }
        } message: {
            Text(bookedStatus == .requested
                 ? "Your request for the \(vehicle.title) in \(vehicle.city) was sent to the host. You'll be notified when they confirm."
                 : "Your \(vehicle.title) is booked in \(vehicle.city). We've added it to your Trips.")
        }
        .alert("Couldn't book", isPresented: Binding(
            get: { store.lastError != nil && !confirmed },
            set: { if !$0 { store.lastError = nil } })) {
            Button("OK", role: .cancel) { store.lastError = nil }
        } message: {
            Text(store.lastError ?? "")
        }
    }

    private var summaryCard: some View {
        HStack(spacing: 12) {
            VehiclePhoto(url: vehicle.heroURL, height: 72, corner: 10).frame(width: 96)
            VStack(alignment: .leading, spacing: 4) {
                Text(vehicle.title).font(.headline).foregroundColor(Theme.ink)
                Text(vehicle.subtitle).font(.subheadline).foregroundColor(Theme.subtle)
                RatingLabel(rating: vehicle.rating, trips: vehicle.trips)
            }
            Spacer()
        }
        .padding(12)
        .card()
    }

    private var datesSection: some View {
        section("Trip dates") {
            DatePicker("Trip start", selection: $start, displayedComponents: [.date, .hourAndMinute])
            DatePicker("Trip end", selection: $end, in: start..., displayedComponents: [.date, .hourAndMinute])
            Text("\(nights) day trip").font(.subheadline).foregroundColor(Theme.subtle)
        }
    }

    private var pickupSection: some View {
        section("Pickup & return location") {
            HStack(spacing: 10) {
                Image(systemName: "mappin.and.ellipse").foregroundColor(Theme.accent)
                Text(vehicle.city).foregroundColor(Theme.ink)
                Spacer()
                Text("Change").font(.subheadline.weight(.semibold)).foregroundColor(Theme.accent)
            }
        }
    }

    private var protectionSection: some View {
        section("Protection plan") {
            ForEach(ProtectionPlan.allCases) { p in
                Button { plan = p } label: {
                    HStack {
                        Image(systemName: plan == p ? "largecircle.fill.circle" : "circle")
                            .foregroundColor(plan == p ? Theme.accent : Theme.subtle)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.rawValue).font(.headline).foregroundColor(Theme.ink)
                            Text(p.blurb).font(.subheadline).foregroundColor(Theme.subtle)
                        }
                        Spacer()
                        Text("+\((tripCost * p.rate).rounded().money(vehicle.currency))")
                            .font(.subheadline).foregroundColor(Theme.ink)
                    }
                }
                if p != ProtectionPlan.allCases.last { Divider().background(Theme.hairline) }
            }
        }
    }

    private var priceBreakdown: some View {
        section("Price details") {
            row("\(vehicle.dailyPrice.money(vehicle.currency)) × \(nights) days", tripCost.money(vehicle.currency))
            row("\(plan.rawValue) protection", protectionCost.money(vehicle.currency))
            row("Service fee", serviceFee.money(vehicle.currency))
            Divider().background(Theme.hairline)
            HStack {
                Text("Total").font(.headline).foregroundColor(Theme.ink)
                Spacer()
                Text(total.money(vehicle.currency)).font(.headline).foregroundColor(Theme.ink)
            }
        }
    }

    private var cta: some View {
        VStack(spacing: 0) {
            PrimaryButton(title: booking ? "Booking…"
                          : (vehicle.instantBook ? "Confirm booking" : "Request to book")) {
                guard !booking else { return }
                booking = true
                Task {
                    let trip = await store.bookTrip(for: vehicle, start: start, end: end,
                                                    plan: plan.rawValue, total: total)
                    booking = false
                    if let trip {
                        bookedStatus = trip.status
                        confirmed = true
                    }
                }
            }
            .padding(16)
            .disabled(booking)
        }
        .background(.ultraThinMaterial)
        .overlay(Rectangle().frame(height: 1).foregroundColor(Theme.hairline), alignment: .top)
    }

    // MARK: helpers
    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.title3.bold()).foregroundColor(Theme.ink)
            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).foregroundColor(Theme.ink)
            Spacer()
            Text(value).foregroundColor(Theme.ink)
        }
        .font(.subheadline)
    }
}
