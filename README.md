# Rental — iOS app

A car-sharing marketplace, **UI modelled on a static analysis of the decrypted
Turo iOS app** (`com.relayrides.ios.RelayRides` 26.41.0). Independent demo — not
affiliated with Turo. Built with **xtool** in WSL2 (no Xcode).

Renters sign in, browse cars, view details, book trips. Owners sign in with the
**same account** and manage their listings (uploaded via the web Client
Dashboard). App and dashboard share one backend and one account system.

```
 Owner (web dashboard)         Backend (Node + SQLite)       Renter (this app)
┌────────────────────┐  POST  ┌────────────────────┐  GET  ┌────────────────┐
│ login + upload car │ ─────▶ │ Express · JWT auth  │ ────▶ │ SearchView     │
└────────────────────┘ Bearer │ data/rental.db      │ JSON  │ DataStore      │
          same /api/auth/* account works in both ───────────────────┘
```

## Projects / locations

| Part | Location | Stack |
|------|----------|-------|
| iOS app (this) | `~/iOS/rental` (`\\wsl.localhost\Ubuntu\home\smash\iOS\rental`) | SwiftUI + xtool |
| Client Dashboard + backend | `C:\Users\guara\Documents\iOS\dashboard` (Windows) | Node/Express + SQLite + Tailwind |

The dashboard has its own `README.md` with the API, auth, database and full
networking guide. This file covers the app.

## Build & run (WSL2 + xtool)

```bash
cd ~/iOS/rental
xtool dev build        # compile only → produces xtool/rental.app
xtool dev              # build + install/run on the connected iPhone
```

Swift 6.4.1 / xtool 1.22.x come from swiftly via `~/.profile`, so builds must run
in a **login shell**: `wsl -e bash -l build.sh` from Windows (see `build.sh`).

## Sign in

The app opens to a login screen (purple-on-black). Use the seeded demo account
or register a new one (works in the dashboard too):

```
email:    demo@rental.app
password: demo1234
```

- **Search** — public catalogue of all cars.
- **Trips** — every trip you're in, as guest *and* host (tap for the shared
  detail screen with status actions + messaging).
- **Host** — *your* listings (from `/api/vehicles/mine`) + incoming bookings on
  your cars. Tap a listing to **edit** it; tap a booking to manage it.
- **Inbox** — your trip conversations (one thread per trip).
- **Account** — who you're signed in as, plus Log out.

### Trips & messaging

A trip links a renter and a host; the backend serves the **same trip to both**
with a `role` that decides which actions you see. Instant-Book cars confirm
immediately; others are *Requested* until the host approves. Status moves
(confirm / decline / start / complete / cancel) and the per-trip message thread
are all persisted server-side — see the dashboard README for the API, the
status lifecycle table and role-gating rules.

If the backend is unreachable the app shows bundled **sample cars** so it's always
demoable; a banner reports the exact URL + error.

## Pointing the app at the backend  ← the setting people miss

`Sources/rental/DataStore.swift` has one line:

```swift
static let apiBase = URL(string: "http://130.44.100.86:3000")!   // ~line 21
```

Change it to an address the **iPhone** can reach, then rebuild + reinstall:

| App runs on… | `apiBase` |
|---|---|
| iPhone on the same Wi-Fi as the backend PC | `http://<PC-LAN-IP>:3000` (e.g. `192.168.0.11`) |
| iPhone anywhere, backend on a public-IP host/server | `http://<SERVER-PUBLIC-IP>:3000` |

Notes:
- On a **physical iPhone, `localhost` means the phone itself** — never use it.
- **NAT hairpin:** a phone on your home Wi-Fi hitting your *public* IP often fails
  even if an outside browser works — use the LAN IP for local testing.
- **Dynamic public IP:** when your ISP rotates it, update this line (or use DDNS)
  and rebuild, or the app falls back to samples.
- The backend must allow inbound TCP 3000 (firewall / router / cloud security
  group). Full networking recipe — incl. Windows firewall + WSL portproxy
  commands — is in the dashboard's `README.md`.
- **Test first:** open `http://<apiBase-host>:3000/api/vehicles` in the phone's
  browser. JSON = reachable.

## Theme

Dynamic light/dark via `Theme.swift`. Accent is **purple** (`#8B5CF6`) in both
modes; dark mode uses a **pure-black background** with near-black raised cards.
Follows the system appearance.

## Source layout (`Sources/rental/`)

```
RentalApp.swift        @main, login gate (AuthView vs RootView), 5-tab bar
AuthView.swift         Login / register screen
Theme.swift            Design tokens (dark/purple), shared components
Models.swift           Vehicle, Trip, Message, User, AuthResponse (Codable)
DataStore.swift        App state: auth, catalogue, trips, messages, listing edit
SearchView.swift       Explore feed + vehicle cards
VehicleDetailView.swift Listing detail + sticky book CTA
CheckoutView.swift     Dates, protection plan, price breakdown, books via API
TripsView.swift        Booked / history trips (guest + host) → TripDetailView
TripDetailView.swift   Shared trip screen: status actions + message link
MessageThreadView.swift Per-trip chat thread
HostView.swift         Earnings, bookings on your cars, your listings
EditListingView.swift  In-app listing editor (PUT / snooze / delete)
InboxView.swift        Trip conversations
ProfileView.swift      Account + logout
```

Dates for trips/messages travel as epoch-ms numbers; `DataStore` decodes them
with `.millisecondsSince1970`. The `Trip`/`Message` shapes match
`dashboard/server.js` (`tripForClient` / `messageForClient`).

The `Vehicle` shape in `Models.swift` is the contract with the backend
(`db.js` / `server.js`) — keep them in sync.
