# Admin Platform — Build Prompt (HISTORICAL)

> **Obsolete scaffold.** The shipped admin is Vite + React in `admin/` — see [services/ADMIN.md](services/ADMIN.md). Do not use this prompt to rebuild Next.js.

Paste the section below ("PROMPT FOR CLAUDE") into Claude (Sonnet 4.6, in Claude.ai or Claude Code) to scaffold the web admin platform. After Claude builds the skeleton, paste in your Claude Design exports — the prompt explicitly leaves visual styling open so it can adopt your design.

The prompt is self-contained: it includes the product context, every entity, every page, the full API contract, the auth model, and the rules of the road. A new Claude session can act on it cold.

---

## How to use this

1. **Open a new Claude.ai chat** (Sonnet 4.6 preferred) OR open Claude Code in an empty directory you want the admin project to live in
2. Paste the entire `PROMPT FOR CLAUDE` block below as your first message
3. Claude will scaffold pages, API routes, auth, and components
4. When Claude pauses for design guidance, paste your **Claude Design** screenshots / exports — the prompt tells Claude to expect this and apply your design system once provided

---

## PROMPT FOR CLAUDE

(begin paste — everything between the rules is the prompt)

---

I'm building the admin web platform for **DrapeAI**, an AI personal stylist mobile app. The mobile app + backend already exist; this admin platform is a brand-new project that talks to the same FastAPI backend.

**Your job**: scaffold a production-ready admin web app — pages, components, auth, API integration, charts. Use **Next.js 15 (App Router) + TypeScript + Tailwind + shadcn/ui + TanStack Query + Recharts**. Generate the full file tree and code. Don't write throwaway scripts. Don't add a database — this app is read/write against the existing FastAPI backend over HTTP.

I will paste **Claude Design** screenshots / exports later in the conversation. Until I do, use a clean default style (neutral palette, generous whitespace, serif headings + sans body) — but structure your components so swapping in my design tokens is a one-file change (`tailwind.config.ts` + a `theme.ts` constants file).

### What the product is (context — read carefully)

DrapeAI is a personal AI stylist app:
- Users photograph clothing → AI tags it (category, color, formality, fabric, pattern, season) and stores a 1536-dim embedding
- Users complete a 9-step onboarding (name, age, gender, style goals, occasions, color preferences, fit, location/climate, optional body/skin/budget/lifestyle)
- AI generates outfit recommendations (rule engine + LLM ranker) which the user can save, dislike, refine via chat, or organise into "Lookbooks"
- "Wardrobe gap" analysis suggests what to buy next
- Multi-provider AI routing across OpenAI / Anthropic / NVIDIA NIM / Groq with automatic failover and per-provider cost tracking

The admin platform exists to:
1. **See and manage every user** — search, view detail, suspend, delete, reset
2. **Inspect every user's wardrobe** — items, outfits, lookbooks — with full preview
3. **Monitor AI spend and usage** — daily charts per provider, alerts on cost caps
4. **Curate content** — flag or remove inappropriate uploads
5. **Observe app health** — error rates, request volumes, latencies
6. **Send push notifications** to user segments (e.g. "all users who haven't opened the app in 7 days")

### Tech stack — non-negotiable

- **Next.js 15** with App Router (`/src/app`)
- **TypeScript**, strict mode
- **Tailwind CSS** + **shadcn/ui** (install Button, Input, Table, Dialog, Sheet, Tabs, Card, Badge, DropdownMenu, Toast, Select, Calendar, Skeleton, Avatar, Separator, ScrollArea — at minimum)
- **TanStack Query v5** for server state (no SWR, no useEffect-fetch)
- **Recharts** for charts
- **Zod** for schemas (validate every API response)
- **lucide-react** for icons
- **Instrument Serif** (headings) + **Inter** (body) + **JetBrains Mono** (numerics) via `next/font/google` — these match the mobile app
- **next-auth** (Auth.js v5) with **Email + Password** credentials provider only. No social login on admin.
- **dayjs** for dates

### Auth model — implement this exactly

The existing FastAPI backend has **no admin role yet** — that needs to change. Add it like this:

1. On the backend `users` table, assume there's a new column: `role TEXT NOT NULL DEFAULT 'user' CHECK (role IN ('user', 'admin', 'superadmin'))`. Generate the migration SQL inline at the top of the project as `migrations/0003_add_admin_role.sql` so the user can apply it.
2. Backend should expose a new admin login endpoint: `POST /admin/login` taking `{email, password}` returning `{token, user: {id, email, name, role}}`. Generate the FastAPI route code as well — write it to `backend/admin_routes.py` so the user can drop it into the API.
3. Admin tokens are JWTs signed with `ADMIN_JWT_SECRET` (env var). 8-hour expiry.
4. Every admin API call sends `Authorization: Bearer <admin-jwt>`. The Next.js app stores the JWT in an **httpOnly cookie** set by a `/api/auth/[...nextauth]/route.ts` handler.
5. Middleware (`middleware.ts`) protects all routes under `/(admin)/*` — redirect to `/login` if no valid session.
6. The `superadmin` role can view destructive actions (delete user, force-purge wardrobe); `admin` can view + suspend but not delete.

### Backend API — what exists today

The mobile-facing API runs at `http://localhost:8000` in dev. The admin needs **new endpoints** the backend doesn't have yet. Generate the FastAPI handler code for these as `backend/admin_routes.py`, mounted at `/admin/*`:

**Users**
- `GET /admin/users?search=&page=&limit=&sort=&filter[onboardingDone]=&filter[role]=` → paginated list with totals
- `GET /admin/users/{id}` → full user incl. preferences, item count, outfit count, last login, total spend caused
- `PATCH /admin/users/{id}` → update role, suspend (`is_suspended` boolean — add this column), notes
- `DELETE /admin/users/{id}` → cascade delete (already CASCADE in schema)
- `POST /admin/users/{id}/reset-onboarding` → set `onboarding_done = FALSE`

**Wardrobe inspection**
- `GET /admin/users/{id}/items?page=` → all items with image_url, tags, wear_count
- `GET /admin/users/{id}/outfits?page=&saved=` → outfits with item thumbnails resolved
- `GET /admin/users/{id}/lookbooks` → lookbooks with outfit counts
- `POST /admin/items/{id}/flag` → mark inappropriate (add `is_flagged` column)
- `DELETE /admin/items/{id}` → soft delete

**Analytics**
- `GET /admin/analytics/overview?days=30` → `{dau, mau, new_users, total_users, total_items, total_outfits, total_cost_usd, avg_items_per_user}`
- `GET /admin/analytics/costs?days=30` → daily series per provider: `[{date, openai, anthropic, nvidia, groq}]`
- `GET /admin/analytics/usage?days=30` → daily series: `[{date, uploads, outfits_generated, chat_refinements, gap_analyses}]`
- `GET /admin/analytics/top-users?metric=cost|items|outfits&days=30&limit=20`

**Push notifications**
- `GET /admin/push/segments` → list saved segments (`active_7d`, `inactive_30d`, etc.)
- `POST /admin/push/send` → body `{segment_id|user_ids, title, body, deep_link?}` → returns send count

**Content moderation**
- `GET /admin/items/flagged?page=` → all flagged items with user info
- `POST /admin/items/{id}/unflag`

**System health**
- `GET /admin/health/providers` → live status of OpenAI / Anthropic / NVIDIA / Groq (ping each)
- `GET /admin/health/errors?days=7` → error count per route from Sentry (if `SENTRY_DSN` set) or from a new `errors_daily` view

### Data shapes — Zod schemas to generate

Generate `/src/lib/api/schemas.ts` with Zod schemas matching every response. Key entities:

```ts
// User row from /admin/users/{id}
{
  id: string;                    // Firebase UID
  email: string | null;
  phone: string | null;
  display_name: string | null;
  photo_url: string | null;
  role: 'user' | 'admin' | 'superadmin';
  is_suspended: boolean;
  onboarding_done: boolean;
  last_login_at: string | null;  // ISO
  created_at: string;            // ISO
  preferences: {
    name: string | null;
    age: number | null;
    gender: string | null;
    style_goals: string[];
    color_preferences: string[];
    occasions: string[];
    location_city: string | null;
    climate: string | null;
    body_type: string | null;
    skin_undertone: string | null;
    height_cm: number | null;
    budget_tier: 'budget' | 'mid' | 'luxury' | null;
    lifestyle: string[];
    fit_preference: string | null;
    style_profile: string | null;
  } | null;
  stats: {
    items_count: number;
    outfits_count: number;
    saved_outfits_count: number;
    lookbooks_count: number;
    total_cost_usd: number;
  };
}

// Item
{
  id: string;
  user_id: string;
  image_url: string;
  thumbnail_url: string | null;
  category: string;
  sub_category: string;
  primary_color: string;
  secondary_colors: string[];
  pattern: string;
  fabric: string;
  style_tags: string[];
  formality: 1 | 2 | 3 | 4 | 5;
  season_tags: string[];
  ethnic_flag: boolean;
  confidence: number;
  brand: string | null;
  wear_count: number;
  is_active: boolean;
  is_flagged: boolean;
  created_at: string;
}

// Outfit
{
  id: string;
  user_id: string;
  item_ids: string[];
  items: Item[];        // resolved by admin endpoint
  occasion: string | null;
  weather_temp: number | null;
  weather_cond: string | null;
  generated_by: 'ai' | 'shuffle' | 'manual';
  rule_score: number | null;
  llm_rank: number | null;
  llm_reason: string | null;
  is_saved: boolean;
  is_worn: boolean;
  created_at: string;
}

// Analytics
{ date: string; openai: number; anthropic: number; nvidia: number; groq: number }
```

### Pages — build all of these

Use the App Router (`src/app/(admin)/...`). All admin pages share a sidebar layout (`src/app/(admin)/layout.tsx`).

| Route | Page | Description |
|---|---|---|
| `/login` | LoginPage | Email + password, calls `/admin/login`, sets cookie, redirects to `/` |
| `/` | DashboardPage | KPI cards (DAU, MAU, new users 7d, total cost 30d), 2 charts (cost per provider, usage trend), recent signups table (5), top spenders table (5) |
| `/users` | UsersPage | Searchable + filterable + paginated table of all users. Columns: avatar+name, email, phone, items, outfits, total cost, last login, role badge, suspended badge, "Actions" dropdown |
| `/users/[id]` | UserDetailPage | Tabs: **Overview** (profile + stats + role/suspend controls), **Wardrobe** (paginated item grid with image previews), **Outfits** (paginated cards with item thumbnails + LLM reason), **Lookbooks** (cards), **Activity** (timeline of feedback events + uploads) |
| `/items` | ItemsPage | Global item browser w/ filters (category, color, formality, flagged-only, user). Used for moderation |
| `/items/flagged` | FlaggedItemsPage | Only items where `is_flagged = true`. Each row: thumbnail, user, why it was flagged, unflag / delete buttons |
| `/analytics` | AnalyticsPage | Full-page charts: cost per provider stacked bar (30d), usage trends line chart, top 20 users by cost / by items, retention cohort if data allows |
| `/notifications` | NotificationsPage | Two tabs: **Segments** (list + count), **Compose** (pick segment OR paste user IDs, write title + body + optional deep link, preview as iOS / Android push, send button) |
| `/system/providers` | ProvidersPage | Live status table of OpenAI / Anthropic / NVIDIA / Groq (green/red dot, last ping, spend this month, monthly cap progress bar) |
| `/system/errors` | ErrorsPage | Table of errors grouped by route + day, counts |
| `/settings` | SettingsPage | Admin profile (change own name / password), env summary (read-only), JWT secret rotation button (superadmin only) |

### Layout — always present

Left sidebar (240px, collapsible to 64px) with sections:
- **OVERVIEW**: Dashboard
- **USERS**: All users, Flagged items
- **CONTENT**: Items, Outfits browser
- **INSIGHTS**: Analytics, Activity
- **OPERATIONS**: Notifications, Providers, Errors
- **SETTINGS**: Settings, Sign out

Top bar (64px): page title, breadcrumbs, global search (cmd+K opens a Command palette for jumping to any user by name/email), bell icon for system alerts, user avatar dropdown.

### Component conventions

- Every table uses `TanStack Table` headlessly with `shadcn/ui` styling — sortable headers, column pinning, sticky header
- Every list endpoint that takes `page` and `limit` gets a reusable `<Pagination />` component
- Every async page uses `<Suspense />` + `<Skeleton />` placeholders matching the final layout shape
- Toasts for every successful mutation (sonner via shadcn)
- Confirmation dialogs (shadcn `<AlertDialog />`) for every destructive action — delete user, delete item, force-purge wardrobe
- Image previews use Next.js `<Image />` with `unoptimized` for R2 URLs (or a remote pattern in `next.config.ts` — add `r2.cloudflarestorage.com` to `remotePatterns`)

### File structure to scaffold

```
admin/
├── package.json
├── tsconfig.json
├── tailwind.config.ts
├── next.config.ts
├── middleware.ts
├── .env.example
├── src/
│   ├── app/
│   │   ├── layout.tsx
│   │   ├── (auth)/login/page.tsx
│   │   ├── (admin)/
│   │   │   ├── layout.tsx
│   │   │   ├── page.tsx                       # /
│   │   │   ├── users/
│   │   │   │   ├── page.tsx                   # /users
│   │   │   │   └── [id]/
│   │   │   │       ├── page.tsx               # /users/[id]
│   │   │   │       ├── wardrobe/page.tsx
│   │   │   │       ├── outfits/page.tsx
│   │   │   │       └── lookbooks/page.tsx
│   │   │   ├── items/page.tsx
│   │   │   ├── items/flagged/page.tsx
│   │   │   ├── analytics/page.tsx
│   │   │   ├── notifications/page.tsx
│   │   │   ├── system/
│   │   │   │   ├── providers/page.tsx
│   │   │   │   └── errors/page.tsx
│   │   │   └── settings/page.tsx
│   │   ├── api/auth/[...nextauth]/route.ts
│   ├── components/
│   │   ├── ui/                                # shadcn primitives
│   │   ├── layout/Sidebar.tsx
│   │   ├── layout/TopBar.tsx
│   │   ├── layout/CommandPalette.tsx
│   │   ├── tables/UsersTable.tsx
│   │   ├── tables/ItemsTable.tsx
│   │   ├── charts/CostChart.tsx
│   │   ├── charts/UsageChart.tsx
│   │   ├── user/UserDetailHeader.tsx
│   │   ├── user/WardrobeGrid.tsx
│   │   ├── user/OutfitCard.tsx
│   │   └── shared/Pagination.tsx
│   ├── lib/
│   │   ├── api/client.ts                      # fetch wrapper w/ JWT, error handling
│   │   ├── api/users.ts                       # typed API functions
│   │   ├── api/items.ts
│   │   ├── api/outfits.ts
│   │   ├── api/analytics.ts
│   │   ├── api/notifications.ts
│   │   ├── api/schemas.ts                     # Zod
│   │   └── auth.ts                            # next-auth config
│   ├── hooks/useUsers.ts                      # TanStack Query hooks
│   ├── hooks/useUserDetail.ts
│   ├── hooks/useAnalytics.ts
│   └── theme.ts                               # design tokens (colors, fonts, radius)
├── backend/
│   ├── admin_routes.py                        # FastAPI router to copy into /api/app/routes/
│   └── migrations/0003_add_admin_role.sql
└── README.md
```

### Environment variables

`.env.example`:
```
NEXT_PUBLIC_API_URL=http://localhost:8000
ADMIN_JWT_SECRET=change-me-to-32-random-bytes
NEXTAUTH_SECRET=change-me-too
NEXTAUTH_URL=http://localhost:3001
```

### Things to actively avoid

- Don't add Prisma / a database in this Next.js app — the FastAPI backend is the source of truth
- Don't fetch from server components if it requires the user's JWT — use TanStack Query in client components for any authenticated data so the JWT in the cookie can be read
- Don't use `useEffect` for data fetching — use TanStack Query
- Don't write CSS modules — Tailwind only
- Don't add a styled component library (Chakra, MUI, etc.) — shadcn/ui only
- Don't generate placeholder lorem ipsum — leave content empty with `<Skeleton />` and show "No data yet" empty states

### Deliverable shape — what I want back from you

1. **`README.md`** with: project description, `pnpm install && pnpm dev`, env setup, the backend migration step, and a screenshot placeholder section I can fill in later
2. **All files in the tree above** with working code
3. **One commit message** suggestion at the end summarising what was built

When I paste in Claude Design exports later, you'll update `theme.ts`, `tailwind.config.ts`, and the typography in `globals.css` to match — and apply the design system to the existing pages without restructuring them.

Start now. Begin with the migration SQL, then the FastAPI admin routes, then the Next.js scaffold. Print the file tree first so I know what's coming, then output each file with its full path and content.

---

(end paste)

---

## After Claude builds the skeleton

1. **Apply the backend migration**:
   ```bash
   docker exec infra-db-1 psql -U drapeai -d drapeai -f /migrations/0003_add_admin_role.sql
   ```
   Then create your first superadmin by inserting a row manually and hashing a password.

2. **Drop the admin routes into the API**:
   - Copy `backend/admin_routes.py` → `/api/app/routes/admin_routes.py`
   - Register it in `/api/app/main.py` with `app.include_router(admin_router, prefix="/admin")`
   - Add `python-jose[cryptography]` and `passlib[bcrypt]` to `api/requirements.txt`
   - Add `ADMIN_JWT_SECRET` to `.env`
   - Restart the API container

3. **Run the admin**:
   ```bash
   cd admin
   pnpm install
   pnpm dev   # http://localhost:3001
   ```

4. **Iterate on design**:
   - Paste Claude Design screenshots into the same Claude chat
   - Tell Claude: *"Apply this design to the existing pages. Update `theme.ts`, `tailwind.config.ts`, fonts in `globals.css`, and component styles. Don't restructure the components — only restyle them."*
   - Claude will refit your design over the working skeleton without breaking the data layer
