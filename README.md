# 🚀 Launchpad

A premium, self-hosted **desktop-style app launcher** built as a single HTML file — no build tools, no npm, no framework. Just open it in a browser.

Backed by **Supabase** for real-time sync across devices, with full offline fallback via `localStorage`.

---

## ✨ Features

### UI & Layout
- **App grid** — responsive card grid with smooth hover/click animations
- **Table view** — sortable, filterable data table of all apps with sync status
- **Dark / light mode** — toggle with one click, persisted across sessions
- **Category chips** — filter apps by tag in one click
- **Drag & drop reorder** — drag cards to reorder; order syncs to Supabase instantly
- **Smooth animations** — spring physics on hover, ripple on click, staggered card entrance

### App Management
- **Add / Edit / Delete** apps via a polished modal form
- **Live icon preview** — supports emoji or any image URL
- **Per-app category** — free-text tag used for filtering
- **Sync status badge** — green dot (synced) or yellow dot (local only) on each card

### Open Modes
- **New Tab** — opens the app URL in a new browser tab
- **iFrame modal** — opens inside a macOS-style in-app window with a fake titlebar

### Supabase Integration
- **Auto-connect on load** — no manual setup after first-time config; credentials are hardcoded and the connection is tested silently
- **Real-time sync via WebSocket** — Supabase Realtime channel watches the `apps` table; any INSERT / UPDATE / DELETE from any device updates the UI instantly
- **30-second polling fallback** — catches any changes the WebSocket missed
- **Bidirectional merge** — local-only apps are pushed to Supabase; remote-only apps are pulled in; deleted remote rows are removed locally
- **Silent background syncs** — auto-polls run without toast notifications or visible loading bars
- **Connection status badge** — shows `Connecting…` → `Supabase · host` → `Supabase · host · live` as the WS connects

### Other
- **Search** — filters grid and table in real time (`Ctrl/⌘ K` to focus)
- **CSV export** — downloads all apps as a spreadsheet
- **Keyboard shortcuts** — `⌘K` search, `Esc` close modals
- **PWA-ready** — service worker registered automatically; works offline after first load

---

## 📁 File Structure

```
launchpad/
├── app-launcher-pocketbase.html   # The entire app (HTML + CSS + JS)
├── launchpad_supabase.sql         # SQL to create the Supabase table
└── README.md
```

Everything lives in one `.html` file — no build step, no dependencies to install.

---

## ⚡ Quick Start

### 1. Set up Supabase

You need a running Supabase instance — either [cloud](https://supabase.com) or [self-hosted](https://supabase.com/docs/guides/self-hosting).

Run the SQL in `launchpad_supabase.sql` via **Supabase Dashboard → SQL Editor → New Query**:

```sql
CREATE TABLE IF NOT EXISTS public.apps (
  id          BIGSERIAL PRIMARY KEY,
  name        TEXT        NOT NULL,
  url         TEXT        NOT NULL,
  icon        TEXT        DEFAULT '',
  category    TEXT        DEFAULT '',
  "order"     INTEGER     DEFAULT 0,
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.apps DISABLE ROW LEVEL SECURITY;

GRANT ALL ON public.apps TO anon;
GRANT ALL ON public.apps TO authenticated;
GRANT USAGE, SELECT ON SEQUENCE public.apps_id_seq TO anon;
GRANT USAGE, SELECT ON SEQUENCE public.apps_id_seq TO authenticated;
```

> See `launchpad_supabase.sql` for the full script including indexes, triggers, and optional RLS policies.

### 2. Configure credentials

Open `app-launcher-pocketbase.html` and update the `PB` config object near the top of the `<script>` section:

```js
let PB = {
  url:       'http://YOUR_SUPABASE_HOST:PORT',  // e.g. http://192.168.1.20:8200
  anonKey:   'eyJ...',                          // your anon/public key
  table:     'apps',                            // table name (default: apps)
  connected:  false,
};
```

### 3. Open the file

Just open `app-launcher-pocketbase.html` in any modern browser. That's it — no server needed.

```bash
# macOS
open app-launcher-pocketbase.html

# Linux
xdg-open app-launcher-pocketbase.html

# Windows
start app-launcher-pocketbase.html
```

On load the app will:
1. Auto-connect to Supabase silently
2. Pull all apps from the `apps` table
3. Open a WebSocket for real-time updates
4. Fall back to polling every 30 seconds

---

## 🗄️ Supabase Table Schema

| Column | Type | Notes |
|---|---|---|
| `id` | `BIGSERIAL` | Auto-increment primary key |
| `name` | `TEXT` | App display name (required) |
| `url` | `TEXT` | Full URL to open (required) |
| `icon` | `TEXT` | Emoji character or image URL |
| `category` | `TEXT` | Free-text tag for filtering |
| `order` | `INTEGER` | Sort order (updated on drag-and-drop) |
| `created_at` | `TIMESTAMPTZ` | Auto-set on insert |
| `updated_at` | `TIMESTAMPTZ` | Auto-updated via trigger |

---

## 🔄 Sync Architecture

```
┌─────────────────────────────────────────────────────────┐
│                      Browser                            │
│                                                         │
│   localStorage ◄──── merge ────► Supabase REST API      │
│        │                              │                 │
│        │              ┌───────────────┘                 │
│        │              │  Supabase Realtime (WebSocket)  │
│        │              │  INSERT / UPDATE / DELETE        │
│        │              ▼                                  │
│        └──────► syncWithPB(silent)                      │
│                       │                                 │
│              every 30s polling fallback                 │
└─────────────────────────────────────────────────────────┘
```

**Three sync layers:**

| Layer | Trigger | Visibility |
|---|---|---|
| Initial sync | On successful auto-connect | Shows sync bar + toast |
| Realtime | Supabase WebSocket `postgres_changes` event | Silent |
| Polling | `setInterval` every 30 seconds | Silent |

**Merge logic:**
- Local apps with no `pbId` → pushed to Supabase, assigned a remote ID
- Remote rows not in local state → pulled in
- Remote rows that were deleted → removed from local state
- Drag-and-drop reorder → `order` field patched in Supabase for all affected rows

---

## ⚙️ Configuration Reference

All configuration is at the top of the `<script>` block inside the HTML file.

```js
// Supabase connection
let PB = {
  url:       'http://192.168.1.20:8200',  // Supabase base URL
  anonKey:   'eyJ...',                    // anon/public API key
  table:     'apps',                      // Postgres table name
  connected:  false,                      // managed at runtime
};

// App state (persisted to localStorage)
let S = {
  apps:        [],       // app records
  theme:       'dark',   // 'dark' | 'light'
  iframeMode:  false,    // false = new tab, true = iframe modal
  view:        'grid',   // 'grid' | 'table'
  filter:      '',       // search query
  tblFilter:   '',       // table view filter
  activeCat:   'All',    // active category chip
  editingId:   null,     // ID of app being edited
  sortCol:     'name',   // table sort column
  sortDir:     1,        // 1 = asc, -1 = desc
};
```

---

## 🌐 API Calls Made

The app uses Supabase's **PostgREST** REST API directly — no SDK required.

| Operation | Method | Endpoint |
|---|---|---|
| Health check | `GET` | `/rest/v1/apps?limit=1` |
| Fetch all apps | `GET` | `/rest/v1/apps?order=order.asc&limit=500` |
| Create app | `POST` | `/rest/v1/apps` |
| Update app | `PATCH` | `/rest/v1/apps?id=eq.{id}` |
| Delete app | `DELETE` | `/rest/v1/apps?id=eq.{id}` |
| Realtime | `WebSocket` | `/realtime/v1/websocket?apikey=…` |

All requests include:
```
apikey: <anon-key>
Authorization: Bearer <anon-key>
Content-Type: application/json
Prefer: return=representation
```

---

## 🖥️ Browser Support

| Browser | Support |
|---|---|
| Chrome 90+ | ✅ Full |
| Firefox 88+ | ✅ Full |
| Safari 15+ | ✅ Full |
| Edge 90+ | ✅ Full |

Requires: `fetch`, `WebSocket`, `localStorage`, `CSS Grid`, `CSS custom properties`.

---

## 🔒 Security Notes

- The anon key is embedded in the HTML file. This is acceptable for **local / self-hosted** use where the file is not publicly served.
- If you deploy this publicly, move credentials to a backend proxy or use Supabase Row Level Security (RLS) with an authenticated user instead of the anon role.
- The iFrame modal uses `sandbox="allow-scripts allow-same-origin allow-forms allow-popups"` — this intentionally allows scripts inside framed apps. Remove `allow-scripts` if you need stricter isolation.

### Enabling RLS (optional hardening)

```sql
ALTER TABLE public.apps ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow public access" ON public.apps
  FOR ALL USING (true) WITH CHECK (true);
```

---

## 🛠️ Self-Hosted Supabase Setup

If you're running Supabase locally (e.g. via Docker):

```bash
git clone https://github.com/supabase/supabase
cd supabase/docker
cp .env.example .env
# Edit .env — set ANON_KEY, SERVICE_ROLE_KEY, etc.
docker compose up -d
```

Then point `PB.url` at your Docker host (e.g. `http://192.168.1.20:8200`) and paste your `ANON_KEY` into `PB.anonKey`.

---

## 📸 Screenshots

> _Add screenshots of the grid view, table view, and the add-app modal here._

---

## 🗺️ Roadmap

- [ ] Spotlight search overlay (`⌘Space`)
- [ ] Pinned / favourite apps row
- [ ] Folder / group support
- [ ] Usage tracking (open count, last opened)
- [ ] Import bookmarks from Chrome / Firefox
- [ ] Supabase Auth — per-user app lists
- [ ] Browser extension
- [ ] Keyboard navigation (arrow keys + Enter)

---

## 📄 License

MIT — do whatever you want with it.

---

## 🙏 Built With

- [Supabase](https://supabase.com) — Postgres + PostgREST + Realtime
- [Syne](https://fonts.google.com/specimen/Syne) & [DM Sans](https://fonts.google.com/specimen/DM+Sans) — Google Fonts
- Zero runtime dependencies
