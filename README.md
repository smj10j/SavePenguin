# Save Penguin (Penguin Rescue)

A universal iOS strategy puzzle game. Players place toolbox items to guide penguins to safety
while avoiding sharks. Available on the App Store as **Save Penguin** (app id: 570590917).

Development started October 14, 2012.

## iOS App

Built with Objective-C, Cocos2D, Box2D physics, LevelHelper, and SpriteHelper.

Open `Penguin Rescue.xcodeproj` in Xcode to build. See `CLAUDE.md` for full architecture notes.

## Website & API

Live at **https://savepenguin.pages.dev** — hosted on Cloudflare Pages (free tier).

The website and API are unified under a single Cloudflare Pages deployment:

| Path | Purpose |
|------|---------|
| `https://savepenguin.pages.dev/` | Landing page |
| `https://savepenguin.pages.dev/server` | REST API (game scores, plays, users) |

### Architecture

```
web/
├── dist/               # Deployed to Cloudflare Pages
│   ├── index.html      # Static landing page (converted from original index.php)
│   ├── css/style.css
│   ├── images/         # WebP images (converted from PNG source in web/subdomains/www/images/)
│   ├── privacy.htm
│   └── _worker.js      # Cloudflare Pages Worker — handles /server API routes,
│                       #   falls through to static assets for everything else
├── subdomains/www/     # Original PHP source (reference only, not deployed)
│   └── images/         # PNG source images — edit these, then run convert-images.sh
└── schema.sql          # D1 database schema (reference; already applied to production)
```

### Database

**Cloudflare D1** (SQLite, free tier) — `savepenguin-db`

Database ID: `0bb65740-525a-4a72-a042-b667dc076790`

Tables: `users`, `level_packs`, `levels`, `plays`, `scores`, `scores_summary`

Schema source of truth: `web/schema.sql`

### API Endpoints

All at `POST /server` or `GET /server`:

| Method | `action` param | Description |
|--------|---------------|-------------|
| POST | `saveUser` | Register a device UUID |
| POST | `savePlay` | Record a level play event |
| POST | `saveScore` | Record a level completion score |
| GET  | `getWorldScores` | Aggregated score stats per level (24hr cache) |

### Cloudflare Configuration

Root `wrangler.toml` configures the Pages project and D1 binding. No manual dashboard
setup required — everything is in code.

## Deployment

### Prerequisites

```sh
npm install -g wrangler
wrangler login
```

### Deploy website + API

```sh
bash scripts/deploy-web.sh
```

This runs `wrangler pages deploy web/dist --project-name savepenguin`.

### Update images

If source PNG images in `web/subdomains/www/images/` change, regenerate WebP and redeploy:

```sh
brew install webp   # first time only
bash scripts/convert-images.sh
bash scripts/deploy-web.sh
```

### Database schema changes

Apply changes to the live D1 database:

```sh
wrangler d1 execute savepenguin-db --remote --file=web/schema.sql
```

## Mobile API Configuration

The iOS app points to the API via `Penguin Rescue/Managers/APIManager.h`:

```objc
#define SERVER_HOST @"savepenguin.pages.dev"
#define SERVER_PATH @"/server"
#define SERVER_URL  [NSString stringWithFormat:@"https://%@%@", SERVER_HOST, SERVER_PATH]
```
