# Rental

A car-sharing marketplace, **UI modelled on a static analysis of the decrypted
Turo iOS app** (`com.relayrides.ios.RelayRides` 26.41.0). Independent demo — not
affiliated with Turo.

Two pieces, both under this folder:

| Part | Path | Stack | Role |
|------|------|-------|------|
| iOS app | `Sources/rental/` | SwiftUI, built with **xtool** | What renters use: Search → car detail → checkout → trips |
| Client Dashboard | `dashboard/` | Node/Express + Tailwind | What **car owners** use to upload their cars |

They share one contract: the `Vehicle` JSON shape. Owners publish cars in the
dashboard → the app loads them from `GET /api/vehicles`.

```
 Owner (web)                 Backend                      Renter (iOS)
┌───────────────┐   POST    ┌──────────────┐   GET      ┌──────────────┐
│ Tailwind form │ ────────▶ │ Express API  │ ─────────▶ │ SearchView   │
│ + photo upload│  multipart│ data + files │  JSON      │ DataStore    │
└───────────────┘           └──────────────┘            └──────────────┘
```

## Run the iOS app (WSL2 + xtool)

```bash
cd ~/iOS/rental
xtool dev build            # produces xtool/rental.app
# xtool dev           # build + install/run on a connected device/sim
```

## Run the Client Dashboard

```bash
cd ~/iOS/rental/dashboard
npm install
npm start                  # http://localhost:3000
```

Open <http://localhost:3000>, fill in the "List your car" form, attach photos,
Publish. Then launch the app (Search tab) — on the Simulator it reads
`http://localhost:3000` and your new car appears. On a physical device, set
`DataStore.apiBase` in `Sources/rental/DataStore.swift` to your machine's LAN IP.

If the dashboard isn't running, the app falls back to bundled sample inventory,
so it's always demoable.

## API

| Method | Route | Purpose |
|--------|-------|---------|
| GET    | `/api/vehicles` | List all cars (the app's catalogue) |
| GET    | `/api/vehicles/:id` | One car |
| POST   | `/api/vehicles` | Create (multipart: fields + up to 10 photos) |
| PUT    | `/api/vehicles/:id` | Update fields |
| POST   | `/api/vehicles/:id/photos` | Add photos |
| DELETE | `/api/vehicles/:id` | Remove a listing |

The `Vehicle` shape is defined in both `dashboard/server.js` (`normalize`) and
`Sources/rental/Models.swift` — keep them in sync.
