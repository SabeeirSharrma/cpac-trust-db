# cpac-trust-db

> *Community-maintained trust data for CPAC.*

> **The Cinder Project** — *"Burn the Blind Spots"*

---

## What is cpac-trust-db?

`cpac-trust-db` is the trust data backend for CPAC. It stores two categories of data:

1. **PKGBUILD snapshots** — anonymized, crowdsourced snapshots submitted by CPAC users, used to detect divergence from known-good package states
2. **Advisories** — maintainer-curated records of known malicious, compromised, or suspicious packages (e.g. Atomic Arch-style hijacks)

CPAC syncs a local copy of this database on `cpac update` and queries it entirely offline at runtime. No live network request is made during `cpac install`, `cpac trust`, or `cpac audit` — only during sync.

---

## Architecture

```
cpac-trust-db/
├── advisories/
│   ├── README.md              # Advisory submission guidelines
│   ├── schema.md              # Advisory format specification
│   └── packages/
│       ├── <package-name>.toml   # One file per flagged package
│       └── ...
├── snapshots/
│   ├── README.md              # Snapshot submission guidelines
│   ├── schema.md              # Snapshot format specification
│   └── packages/
│       ├── <package-name>/
│       │   ├── hashes.toml    # Aggregated hash submissions
│       │   └── pkgbuilds/     # Full PKGBUILD submissions (opt-in)
│       └── ...
├── meta/
│   └── db.toml                # Database version, last updated, schema version
└── README.md
```

---

## How CPAC Consumes It

```
cpac update
    ↓
Pull latest cpac-trust-db (git pull or HTTP fetch)
    ↓
Store locally at ~/.cpac/trust-db/
    ↓
cpac install / cpac trust / cpac audit
    ↓
Query local copy — no network required
    ↓
Expired local copy → warn user to run cpac update
```

### Local storage

```
~/.cpac/trust-db/
  advisories.db     # compiled advisory index (fast lookup by package name)
  snapshots.db      # compiled snapshot index (fast lookup by package + version)
  meta.toml         # last sync timestamp, db version
```

CPAC compiles the raw TOML/text from the repo into a local binary database format on sync, so runtime queries are fast and don't require parsing the raw repo files.

### Sync behavior

- `cpac update` pulls the latest `cpac-trust-db` as part of its normal run
- If the local copy is stale (configurable, default: synced with cache TTL), CPAC warns the user but continues using the local copy — **never blocks on network**
- If no local copy exists yet (fresh install), CPAC fetches on first run

---

## Data Categories

### 1. Advisories (maintainer-curated)

Maintained directly by The Cinder Project core team. See [advisories/README.md](advisories/README.md) for submission guidelines and [advisories/schema.md](advisories/schema.md) for the format specification.

### 2. PKGBUILD Snapshots (automated client submissions)

Submitted anonymously by CPAC clients that have opted into crowdsourced sharing. See [snapshots/README.md](snapshots/README.md) for submission guidelines and [snapshots/schema.md](snapshots/schema.md) for the format specification.

---

## Database Versioning

`meta/db.toml` tracks the schema version so CPAC can handle breaking changes:

```toml
[meta]
db_version = "1.0.0"
last_updated = "2026-06-26"
advisory_count = 0
snapshot_package_count = 0
schema_version = 1
```

If CPAC encounters a `schema_version` higher than it supports, it warns the user to update CPAC rather than silently misreading the data.

---

## Governance

| Data Type | Who Can Submit | Review Required |
|---|---|---|
| Advisories | Core team only | Yes — maintainer merge |
| PKGBUILD snapshots (hash) | Automated CPAC clients | No — aggregated automatically |
| PKGBUILD snapshots (full) | Automated CPAC clients | No — aggregated automatically |

Community members can **report** potential advisories via GitHub issues or the Discord server. Core team reviews evidence and publishes the advisory if confirmed.

---

## Related Projects

| Project | Role |
|---|---|
| `cpac` | Consumes cpac-trust-db; submits snapshots on `cpac update` |
| `cinderos` | Ships CPAC (and therefore cpac-trust-db) by default |
| `website` | Advisory public index at `thecinderproject.qd.je/advisories` |

---

*Part of The Cinder Project — github.com/SabeeirSharrma/cpac-trust-db*
