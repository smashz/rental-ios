import SwiftUI

/// Central app state. On launch it tries to load the live catalogue from the
/// Client Dashboard backend (the Node/Express server in ./dashboard). If that
/// isn't reachable it falls back to bundled sample inventory so the app is
/// always demoable. This is the seam that connects owner uploads → the app.
@MainActor
final class DataStore: ObservableObject {
    @Published var vehicles: [Vehicle] = []
    @Published var trips: [Trip] = []
    @Published var conversations: [Conversation] = []
    @Published var savedIDs: Set<String> = []
    @Published var loadState: LoadState = .idle
    @Published var usingLiveData = false

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
        trips = DataStore.sampleTrips
        conversations = DataStore.sampleConversations
        vehicles = DataStore.sampleVehicles
        token = UserDefaults.standard.string(forKey: "rental_token")
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

    func addTrip(for vehicle: Vehicle, start: Date, end: Date, total: Double) {
        let trip = Trip(
            id: UUID().uuidString,
            vehicleTitle: vehicle.title,
            vehiclePhoto: vehicle.photos.first,
            city: vehicle.city,
            start: start, end: end,
            total: total, currency: vehicle.currency,
            status: .upcoming
        )
        trips.insert(trip, at: 0)
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

    static let sampleTrips: [Trip] = {
        let cal = Calendar.current
        let now = Date()
        return [
            Trip(id: "t1", vehicleTitle: "Tesla Model 3", vehiclePhoto: nil, city: "San Francisco, CA",
                 start: cal.date(byAdding: .day, value: 6, to: now)!,
                 end: cal.date(byAdding: .day, value: 9, to: now)!,
                 total: 312, currency: "USD", status: .upcoming),
            Trip(id: "t2", vehicleTitle: "Toyota RAV4", vehiclePhoto: nil, city: "Austin, TX",
                 start: cal.date(byAdding: .day, value: -20, to: now)!,
                 end: cal.date(byAdding: .day, value: -17, to: now)!,
                 total: 204, currency: "USD", status: .completed)
        ]
    }()

    static let sampleConversations: [Conversation] = [
        Conversation(name: "Marcus", lastMessage: "The car is charged and ready for pickup!", vehicle: "Tesla Model 3", unread: true),
        Conversation(name: "Leo", lastMessage: "Thanks for the great trip — 5 stars!", vehicle: "Toyota RAV4", unread: false)
    ]
}
