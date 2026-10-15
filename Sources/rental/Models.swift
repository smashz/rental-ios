import SwiftUI

/// A listed car. This Codable shape is the contract shared with the web
/// Client Dashboard (dashboard/server.js): owners upload cars there and the
/// app renders exactly these fields. Keep the keys in sync with the backend.
struct Vehicle: Identifiable, Codable, Hashable {
    var id: String
    var make: String
    var model: String
    var year: Int
    var trim: String?
    var dailyPrice: Double
    var currency: String
    var city: String
    var rating: Double
    var trips: Int
    var hostName: String
    var description: String
    var seats: Int
    var doors: Int
    var transmission: String      // "Automatic" / "Manual"
    var fuelType: String          // "Gas" / "Electric" / "Hybrid"
    var instantBook: Bool
    var unlimitedMiles: Bool
    var features: [String]
    var photos: [String]          // absolute URLs served by the dashboard
    var available: Bool

    var title: String { "\(make) \(model)" }
    var subtitle: String {
        var parts = ["\(year)"]
        if let trim, !trim.isEmpty { parts.append(trim) }
        return parts.joined(separator: " · ")
    }

    /// First photo URL, if any resolves.
    var heroURL: URL? { photos.first.flatMap(URL.init(string:)) }
}

/// A booked trip (guest side). Mirrors Turo's "Trips" tab rows.
struct Trip: Identifiable, Codable, Hashable {
    var id: String
    var vehicleTitle: String
    var vehiclePhoto: String?
    var city: String
    var start: Date
    var end: Date
    var total: Double
    var currency: String
    var status: Status

    enum Status: String, Codable {
        case upcoming = "Upcoming"
        case inProgress = "In progress"
        case completed = "Completed"
        case cancelled = "Cancelled"
    }

    var photoURL: URL? { vehiclePhoto.flatMap(URL.init(string:)) }
}

/// A signed-in account. The same account works in the web dashboard and here.
struct User: Codable, Hashable, Identifiable {
    var id: String
    var email: String
    var name: String
}

/// Response shape from /api/auth/login and /api/auth/register.
struct AuthResponse: Codable {
    var token: String
    var user: User
}

/// An inbox conversation thread.
struct Conversation: Identifiable, Hashable {
    var id = UUID().uuidString
    var name: String
    var lastMessage: String
    var vehicle: String
    var unread: Bool
}

extension Double {
    /// Currency formatting, defaulting to USD symbol rules.
    func money(_ currency: String = "USD") -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = currency
        f.maximumFractionDigits = (self.rounded() == self) ? 0 : 2
        return f.string(from: NSNumber(value: self)) ?? "\(currency) \(self)"
    }
}
