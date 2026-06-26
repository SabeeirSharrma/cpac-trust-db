# cpac-trust-db

> *Community-maintained trust data for CPAC.*

> **The Cinder Project** — *"Burn the Blind Spots"*

---

## What is cpac-trust-db?

`cpac-trust-db` is the trust data backend for CPAC. It stores two categories of data:

1. **PKGBUILD snapshots** — anonymized, crowdsourced snapshots submitted by CPAC clients, used to detect divergence from known-good package states
2. **Advisories** — maintainer-curated records of known malicious, compromised, or suspicious packages (e.g. Atomic Arch-style hijacks)

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

**Owner/Main Developer: [Sabeeir Sharrma](https://github.com/SabeeirSharrma)
*Part of The Cinder Project — github.com/SabeeirSharrma/cpac-trust-db*
