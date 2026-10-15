import SwiftUI

/// In-app listing editor (host side). Opened from the Host tab by tapping a
/// listing. Saves edits with PUT /api/vehicles/:id and can snooze (toggle
/// availability) or delete the listing — the same operations the web dashboard
/// offers. Photo uploads stay in the web dashboard; this edits the details.
struct EditListingView: View {
    @State var vehicle: Vehicle
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss

    @State private var featuresText = ""
    @State private var saving = false
    @State private var confirmDelete = false
    @State private var error: String?

    var body: some View {
        Form {
            Section("Car") {
                labeled("Make") { TextField("Make", text: $vehicle.make) }
                labeled("Model") { TextField("Model", text: $vehicle.model) }
                labeled("Trim") { TextField("Trim", text: Binding(
                    get: { vehicle.trim ?? "" }, set: { vehicle.trim = $0 })) }
                labeled("Year") { TextField("Year", value: $vehicle.year, format: .number).keyboardType(.numberPad) }
            }

            Section("Pricing & location") {
                labeled("Price / day") { TextField("Price", value: $vehicle.dailyPrice, format: .number).keyboardType(.decimalPad) }
                labeled("Currency") { TextField("USD", text: $vehicle.currency) }
                labeled("City") { TextField("City", text: $vehicle.city) }
            }

            Section("Specs") {
                labeled("Seats") { TextField("Seats", value: $vehicle.seats, format: .number).keyboardType(.numberPad) }
                labeled("Doors") { TextField("Doors", value: $vehicle.doors, format: .number).keyboardType(.numberPad) }
                Picker("Transmission", selection: $vehicle.transmission) {
                    Text("Automatic").tag("Automatic"); Text("Manual").tag("Manual")
                }
                Picker("Fuel", selection: $vehicle.fuelType) {
                    Text("Gas").tag("Gas"); Text("Electric").tag("Electric"); Text("Hybrid").tag("Hybrid")
                }
            }

            Section("Booking options") {
                Toggle("Instant Book", isOn: $vehicle.instantBook)
                Toggle("Unlimited miles", isOn: $vehicle.unlimitedMiles)
                Toggle("Listed (available)", isOn: $vehicle.available)
            }

            Section("Description") {
                TextField("Describe the car…", text: $vehicle.description, axis: .vertical)
                    .lineLimit(3...8)
            }

            Section("Features") {
                TextField("Comma separated", text: $featuresText, axis: .vertical)
                    .lineLimit(1...4)
                Text("e.g. All-wheel drive, Apple CarPlay, Heated seats")
                    .font(.caption).foregroundColor(Theme.subtle)
            }

            if let error {
                Section { Text(error).foregroundColor(.red).font(.subheadline) }
            }

            Section {
                Button(role: .destructive) { confirmDelete = true } label: {
                    HStack { Image(systemName: "trash"); Text("Delete listing") }
                }
            }
        }
        .navigationTitle("Edit listing")
        .navigationBarTitleDisplayMode(.inline)
        .tint(Theme.accent)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(saving ? "Saving…" : "Save") { save() }.disabled(saving)
            }
        }
        .onAppear { featuresText = vehicle.features.joined(separator: ", ") }
        .confirmationDialog("Delete this listing? This can't be undone.",
                            isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { delete() }
            Button("Keep", role: .cancel) {}
        }
    }

    private func labeled<C: View>(_ title: String, @ViewBuilder _ field: () -> C) -> some View {
        HStack {
            Text(title).foregroundColor(Theme.subtle).frame(width: 110, alignment: .leading)
            field()
        }
    }

    private func save() {
        guard !saving else { return }
        saving = true; error = nil
        vehicle.features = featuresText
            .split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        Task {
            let saved = await store.saveListing(vehicle)
            saving = false
            if saved != nil { dismiss() } else { error = store.lastError ?? "Couldn't save." }
        }
    }

    private func delete() {
        Task {
            if await store.deleteListing(vehicle.id) { dismiss() }
            else { error = store.lastError ?? "Couldn't delete." }
        }
    }
}
