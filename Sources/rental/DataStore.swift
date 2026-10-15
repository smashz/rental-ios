import SwiftUI

/// Central app state. On launch it tries to load the live catalogue from the
/// Client Dashboard backend (the Node/Express server in ./dashboard). If that
/// isn't reachable it falls back to bundled sample inventory so the app is
/// always demoable. This is the seam that connects owner uploads → the app.
@MainActor
final class DataStore: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var trips: [Trip] = []
    @Published var savedIDs: Set<String> = []
    @Published var loadState: LoadState = .idle
    @Published var usingLiveData = false
    /// Last non-auth action error (booking, status change, messaging), for UI.
    @Published var lastError: String?

    // Auth
    @Published var currentUser: User?
    @Published var myVehicles: [Vehicle] = []
    @Published var authError: String?
    private var token: String? {
        didSet { UserDefaults.standard.set(token, forKey: "rental_token") }
    }
    var isAuthenticated: Bool { currentUser != nil }

    enum LoadState: Equatable { case idle, loading, loaded, failed(String) }

    /// Base URL of the dashboard backend (the hosted server's public address).
    /// If the server's IP/host changes, update this one line and rebuild.
    static let apiBase = URL(string: "http://130.44.100.86:3000")!

    /// Guards against overlapping refreshes (initial `.task` + pull-to-refresh),
    /// which is what produces the spurious "cancelled" error.
    private var isRefreshing = false

    init() {
        vehicles = DataStore.sampleVehicles
        token = UserDefaults.standard.string(forKey: "rental_token")
    }

    /// Trips and messages carry dates as epoch-ms numbers on the wire.
    private func tripDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .millisecondsSince1970
        return d
    }

    // MARK: - Auth

    private func endpoint(_ path: String) -> URL {
        DataStore.apiBase.appendingPathComponent(path)
    }

    private func newSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.waitsForConnectivity = true
        return URLSession(configuration: config)
    }

    /// Restore a previous session on launch if we still hold a valid token.
    func restoreSession() async {
        guard let token, !token.isEmpty else { return }
        do {
            var req = URLRequest(url: endpoint("api/auth/me"))
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, resp) = try await newSession().data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { logout(); return }
            let wrapper = try JSONDecoder().decode([String: User].self, from: data)
            currentUser = wrapper["user"]
            await loadMine()
            await loadTrips()
        } catch {
            // Offline — keep the token; the user can retry. Don't force logout.
        }
    }

    func login(email: String, password: String) async -> Bool {
        await authRequest(path: "api/auth/login", body: ["email": email, "password": password])
    }

    func register(name: String, email: String, password: String) async -> Bool {
        await authRequest(path: "api/auth/register",
                          body: ["name": name, "email": email, "password": password])
    }

    private func authRequest(path: String, body: [String: String]) async -> Bool {
        authError = nil
        do {
            var req = URLRequest(url: endpoint(path))
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await newSession().data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            if code == 200 || code == 201 {
                let auth = try JSONDecoder().decode(AuthResponse.self, from: data)
                self.token = auth.token
                self.currentUser = auth.user
                await loadMine()
                await loadTrips()
                return true
            } else {
                let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
                authError = msg ?? "Sign in failed (\(code))"
                return false
            }
        } catch {
            authError = "Can't reach the server: \(error.localizedDescription)"
            return false
        }
    }

    func logout() {
        token = nil
        currentUser = nil
        myVehicles = []
        trips = []
    }

    /// The signed-in owner's own listings (Host tab).
    func loadMine() async {
        guard let token else { return }
        do {
            var req = URLRequest(url: endpoint("api/vehicles/mine"))
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            let (data, resp) = try await newSession().data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
            myVehicles = try JSONDecoder().decode([Vehicle].self, from: data)
        } catch { /* keep previous */ }
    }

    func refresh() async {
        if isRefreshing { return }        // don't let a second refresh cancel the first
        isRefreshing = true
        defer { isRefreshing = false }

        loadState = .loading
        let url = DataStore.apiBase.appendingPathComponent("api/vehicles")
        do {
            var req = URLRequest(url: url)
            req.cachePolicy = .reloadIgnoringLocalCacheData
            req.timeoutInterval = 12
            // Dedicated session so SwiftUI tearing down the refresh Task doesn't
            // cancel the shared session's request out from under us.
            let config = URLSessionConfiguration.ephemeral
            config.waitsForConnectivity = true
            let session = URLSession(configuration: config)
            let (data, resp) = try await session.data(for: req)
            guard let http = resp as? HTTPURLResponse, http.statusCode == 200 else {
                throw URLError(.badServerResponse)
            }
            let decoded = try JSONDecoder().decode([Vehicle].self, from: data)
            self.vehicles = decoded.isEmpty ? DataStore.sampleVehicles : decoded
            self.usingLiveData = !decoded.isEmpty
            self.loadState = .loaded
        } catch is CancellationError {
            // A cancelled refresh is not a failure — keep whatever we have.
            loadState = usingLiveData ? .loaded : .idle
        } catch let err as URLError where err.code == .cancelled {
            loadState = usingLiveData ? .loaded : .idle
        } catch {
            // Only fall back to samples if we never got live data.
            if !usingLiveData {
                self.vehicles = DataStore.sampleVehicles
                self.loadState = .failed("Samples — \(url.absoluteString) failed: \(error.localizedDescription)")
            } else {
                self.loadState = .loaded
            }
        }
    }

    func toggleSaved(_ id: String) {
        if savedIDs.contains(id) { savedIDs.remove(id) } else { savedIDs.insert(id) }
    }

    func isSaved(_ id: String) -> Bool { savedIDs.contains(id) }

    // MARK: - Trips

    /// Build an authed request, or nil if we hold no token.
    private func authed(_ path: String, method: String = "GET", json: [String: Any]? = nil) -> URLRequest? {
        guard let token else { return nil }
        var req = URLRequest(url: endpoint(path))
        req.httpMethod = method
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let json {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try? JSONSerialization.data(withJSONObject: json)
        }
        return req
    }

    private func errorMessage(_ data: Data, fallback: String) -> String {
        (try? JSONDecoder().decode([String: String].self, from: data))?["error"] ?? fallback
    }

    /// All trips the signed-in user is part of — as renter or as host.
    func loadTrips() async {
        guard let req = authed("api/trips") else { return }
        do {
            let (data, resp) = try await newSession().data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return }
            trips = try tripDecoder().decode([Trip].self, from: data)
        } catch { /* keep previous */ }
    }

    /// Book `vehicle`. Returns the created trip, or nil (with `lastError` set).
    func bookTrip(for vehicle: Vehicle, start: Date, end: Date, plan: String, total: Double) async -> Trip? {
        lastError = nil
        let body: [String: Any] = [
            "vehicleId": vehicle.id,
            "start": start.timeIntervalSince1970 * 1000,
            "end": end.timeIntervalSince1970 * 1000,
            "plan": plan,
            "total": total,
        ]
        guard let req = authed("api/trips", method: "POST", json: body) else {
            lastError = "Please sign in again."; return nil
        }
        do {
            let (data, resp) = try await newSession().data(for: req)
            let code = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard code == 200 || code == 201 else {
                lastError = errorMessage(data, fallback: "Booking failed (\(code))"); return nil
            }
            let trip = try tripDecoder().decode(Trip.self, from: data)
            trips.insert(trip, at: 0)
            return trip
        } catch {
            lastError = "Can't reach the server: \(error.localizedDescription)"; return nil
        }
    }

    /// Move a trip to a new status (role-gated server-side). Updates in place.
    @discardableResult
    func setTripStatus(_ trip: Trip, to status: Trip.Status) async -> Trip? {
        lastError = nil
        guard let req = authed("api/trips/\(trip.id)", method: "PATCH", json: ["status": status.rawValue]) else {
            return nil
        }
        do {
            let (data, resp) = try await newSession().data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else {
                lastError = errorMessage(data, fallback: "Couldn't update the trip"); return nil
            }
            let updated = try tripDecoder().decode(Trip.self, from: data)
            if let i = trips.firstIndex(where: { $0.id == updated.id }) { trips[i] = updated }
            return updated
        } catch {
            lastError = "Can't reach the server: \(error.localizedDescription)"; return nil
        }
    }

    // MARK: - Messages

    func loadMessages(tripId: String) async -> [Message] {
        guard let req = authed("api/trips/\(tripId)/messages") else { return [] }
        do {
            let (data, resp) = try await newSession().data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { return [] }
            // Reading clears this trip's unread badge; reflect it locally.
            if let i = trips.firstIndex(where: { $0.id == tripId }) { trips[i].unreadCount = 0 }
            return try tripDecoder().decode([Message].self, from: data)
        } catch { return [] }
    }

    func sendMessage(tripId: String, body: String) async -> Message? {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let req = authed("api/trips/\(tripId)/messages", method: "POST", json: ["body": trimmed])
        else { return nil }
        do {
            let (data, resp) = try await newSession().data(for: req)
            guard ((resp as? HTTPURLResponse)?.statusCode ?? 0) == 201 else { return nil }
            let msg = try tripDecoder().decode(Message.self, from: data)
            if let i = trips.firstIndex(where: { $0.id == tripId }) { trips[i].lastMessage = msg.body }
            return msg
        } catch { return nil }
    }

    // MARK: - Listing management (host)

    /// Save edits to one of the owner's listings (PUT). Updates local caches.
    func saveListing(_ v: Vehicle) async -> Vehicle? {
        lastError = nil
        let body: [String: Any] = [
            "make": v.make, "model": v.model, "year": v.year, "trim": v.trim ?? "",
            "dailyPrice": v.dailyPrice, "currency": v.currency, "city": v.city,
            "description": v.description, "seats": v.seats, "doors": v.doors,
            "transmission": v.transmission, "fuelType": v.fuelType,
            "instantBook": v.instantBook, "unlimitedMiles": v.unlimitedMiles,
            "features": v.features, "available": v.available,
        ]
        guard let req = authed("api/vehicles/\(v.id)", method: "PUT", json: body) else { return nil }
        do {
            let (data, resp) = try await newSession().data(for: req)
            guard ((resp as? HTTPURLResponse)?.statusCode ?? 0) == 200 else {
                lastError = errorMessage(data, fallback: "Couldn't save the listing"); return nil
            }
            let updated = try JSONDecoder().decode(Vehicle.self, from: data)
            if let i = myVehicles.firstIndex(where: { $0.id == updated.id }) { myVehicles[i] = updated }
            if let i = vehicles.firstIndex(where: { $0.id == updated.id }) { vehicles[i] = updated }
            return updated
        } catch {
            lastError = "Can't reach the server: \(error.localizedDescription)"; return nil
        }
    }

    @discardableResult
    func deleteListing(_ id: String) async -> Bool {
        guard let req = authed("api/vehicles/\(id)", method: "DELETE") else { return false }
        do {
            let (_, resp) = try await newSession().data(for: req)
            let ok = ((resp as? HTTPURLResponse)?.statusCode ?? 0) == 204
            if ok {
                myVehicles.removeAll { $0.id == id }
                vehicles.removeAll { $0.id == id }
            }
            return ok
        } catch { return false }
    }
}

// MARK: - Sample inventory (fallback when the dashboard isn't running)

extension DataStore {
    static let sampleVehicles: [Vehicle] = [
        Vehicle(id: "s1", make: "Tesla", model: "Model 3", year: 2023, trim: "Long Range",
                dailyPrice: 95, currency: "USD", city: "San Francisco, CA",
                rating: 4.97, trips: 213, hostName: "Marcus",
                description: "Clean, quiet, and quick. Autopilot enabled, charges included for local trips. Perfect for city weekends and airport runs.",
                seats: 5, doors: 4, transmission: "Automatic", fuelType: "Electric",
                instantBook: true, unlimitedMiles: true,
                features: ["All-wheel drive", "Apple CarPlay", "Heated seats", "Backup camera"],
                photos: [], available: true),
        Vehicle(id: "s2", make: "Jeep", model: "Wrangler", year: 2021, trim: "Sport S",
                dailyPrice: 78, currency: "USD", city: "Denver, CO",
                rating: 4.89, trips: 142, hostName: "Priya",
                description: "Built for the mountains. Removable top, all-terrain tires, roof rack for your gear.",
                seats: 5, doors: 4, transmission: "Automatic", fuelType: "Gas",
                instantBook: false, unlimitedMiles: false,
                features: ["4x4", "Roof rack", "Bluetooth", "Tow hitch"],
                photos: [], available: true),
        Vehicle(id: "s3", make: "Porsche", model: "911", year: 2022, trim: "Carrera",
                dailyPrice: 320, currency: "USD", city: "Los Angeles, CA",
                rating: 5.00, trips: 61, hostName: "Dana",
                description: "A weekend to remember. Sport exhaust, PDK, meticulously maintained. Coastline drives recommended.",
                seats: 2, doors: 2, transmission: "Automatic", fuelType: "Gas",
                instantBook: true, unlimitedMiles: false,
                features: ["Sport exhaust", "Carbon trim", "Premium sound"],
                photos: [], available: true),
        Vehicle(id: "s4", make: "Toyota", model: "RAV4", year: 2020, trim: "Hybrid XLE",
                dailyPrice: 62, currency: "USD", city: "Austin, TX",
                rating: 4.92, trips: 308, hostName: "Leo",
                description: "Reliable, roomy, and great on gas. Ideal for families and road trips.",
                seats: 5, doors: 4, transmission: "Automatic", fuelType: "Hybrid",
                instantBook: true, unlimitedMiles: true,
                features: ["Apple CarPlay", "Lane assist", "All-wheel drive"],
                photos: [], available: true)
    ]
}
