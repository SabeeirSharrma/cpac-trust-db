# cpac-trust-db

> *Community-maintained trust data for CPAC.*

> **The Cinder Project** — *"Burn the Blind Spots"*

---

## What is cpac-trust-db?

`cpac-trust-db` is the trust data backend for CPAC. It stores:

1. **PKGBUILD snapshots** — anonymized, crowdsourced snapshots submitted by CPAC clients, used to detect divergence from known-good package states
2. **Advisories** — maintainer-curated records of known malicious, compromised, or suspicious packages (e.g. Atomic Arch-style hijacks)
3. **Advisory history** — append-only version history of advisory changes (never overwritten)
4. **AI analysis cache** — on-demand AI analysis results cached for 3 hours

CPAC clients connect via a Cloudflare Worker proxy at `api.thecinderproject.qd.je` which forwards to Supabase.

---

## Features

### Advisory Lifecycle
- Advisories are versioned (append-only history, never overwritten)
- Each package has one canonical "current" advisory plus version history
- Snapshot retention: 2-5 days based on package size, core packages never cleaned

### Reputation System
- **Strike tracking** — rejected submissions increment strikes, approved submissions reduce strikes
- **Trust tiers** — Trusted (80%+ rate, 20+ approved), Standard, Probation (2 strikes), Suspended (3+ strikes)
- **Volunteer/maintainer reputation views** — approval rates, active days, submission counts

### Email Notifications
- **Weekly advisory reports** — HTML email with submission summary, approval rate, trust tier
- **Staggered sending** — reports sent based on account creation day (Mon→Mon, etc.)
- **Zero activity = no email** — volunteers with no submissions that week receive no report

### Admin Panel
- Account management (create volunteer/maintainer/admin accounts)
- Pending advisory review
- Published advisories viewer
- Package comparer with suspicious pattern detection
- Volunteer reputation stats
- Inactivity monitoring

### Worker Endpoints
- `GET /aur/info/<pkg>` — AUR RPC proxy (CORS fix for browser)
- `GET /aur/pkgbuild/<pkg>` — PKGBUILD fetch proxy
- `POST /accounts/create` — admin account creation (generates random password, sends email)
- `POST /reports/generate` — generates weekly reports for volunteers due today
- `POST /reports/send` — sends queued reports via Resend

---

## Documentation

Full documentation is in the [`docs/`](docs/) directory:

- [Architecture](docs/architecture.md) — System design and tech stack
- [API Endpoints](docs/api.md) — REST API reference
- [Staleness Check](docs/staleness-check.md) — How CPAC detects stale data
- [Local Cache](docs/local-cache.md) — Local storage structure
- [Advisories](docs/advisories.md) — Advisory data format and trust impact
- [Snapshots](docs/snapshots.md) — Snapshot data format and submission pipeline
- [GitHub Actions](docs/github-actions.md) — Sync pipeline (TOML → Supabase)
- [Auth Model](docs/auth.md) — Authentication and authorization
- [Governance](docs/governance.md) — Who can submit what
- [Roadmap](docs/roadmap.md) — Planned features
- [Related Projects](docs/related.md) — Ecosystem overview

---

## Repository Structure

```
cpac-trust-db/
├── advisories/
│   ├── README.md
│   ├── schema.md
│   ├── SUBMISSION.md
│   └── packages/
│       └── <package-name>.toml
├── snapshots/
│   ├── README.md
│   ├── schema.md
│   ├── SUBMISSION.md
│   └── packages/
│       └── <package-name>/
│           ├── hashes.toml
│           └── pkgbuilds/
├── meta/
│   └── db.toml
├── scripts/
│   ├── sync_advisories_to_supabase.py
│   ├── sync_snapshots_to_supabase.py
│   └── sync_snapshots_from_supabase.py
├── worker/
│   ├── src/index.ts
│   ├── wrangler.toml
│   ├── package.json
│   └── README.md
├── supabase/
│   └── migrations/
├── web/
│   └── index.astro
├── docs/
│   ├── index.md
│   ├── architecture.md
│   ├── api.md
│   ├── staleness-check.md
│   ├── local-cache.md
│   ├── advisories.md
│   ├── snapshots.md
│   ├── github-actions.md
│   ├── auth.md
│   ├── governance.md
│   ├── roadmap.md
│   └── related.md
├── .github/
│   └── workflows/
│       └── sync.yml
├── CONTRIBUTING.md
├── RECORDED-CHANGES.md
├── rn.md
├── spec.md
└── README.md
```

---

# Made By

**Owner/Main Developer: [Sabeeir Sharrma](https://github.com/SabeeirSharrma)**

*Part of The Cinder Project — github.com/SabeeirSharrma/cpac-trust-db*
