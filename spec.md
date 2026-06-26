# cpac-trust-db
> *Community-maintained trust data for CPAC.*

> **The Cinder Project** — *"Burn the Blind Spots"*

---

## What is cpac-trust-db?

`cpac-trust-db` is the trust data backend for CPAC. It stores two categories of data:

1. **PKGBUILD snapshots** — anonymized, crowdsourced snapshots submitted by CPAC users,
   used to detect divergence from known-good package states
2. **Advisories** — maintainer-curated records of known malicious, compromised, or
   suspicious packages (e.g. Atomic Arch-style hijacks)

CPAC syncs a local copy of this database on `cpac update` and queries it entirely
offline at runtime. No live network request is made during `cpac install`, `cpac trust`,
or `cpac audit` — only during sync.

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

CPAC compiles the raw TOML/text from the repo into a local binary database format
on sync, so runtime queries are fast and don't require parsing the raw repo files.

### Sync behavior

- `cpac update` pulls the latest `cpac-trust-db` as part of its normal run
- If the local copy is stale (configurable, default: synced with cache TTL),
  CPAC warns the user but continues using the local copy — **never blocks on network**
- If no local copy exists yet (fresh install), CPAC fetches on first run

---

## Data Categories

### 1. Advisories (maintainer-curated)

Maintained directly by The Cinder Project core team. Each advisory is a TOML file:

```toml
# advisories/packages/malicious-pkg.toml

[advisory]
package = "malicious-pkg"
severity = "critical"          # critical | high | medium | low
status = "confirmed"           # confirmed | suspected | resolved
reported = "2026-06-14"
updated = "2026-06-14"
reported_by = "The Cinder Project"
cve = ""                       # if applicable

[details]
summary = "Package PKGBUILD modified to execute remote script post-install"
description = """
On 2026-06-14, the maintainer of malicious-pkg transferred ownership and
introduced a curl | bash call in the post_install() function targeting
an external IP. Confirmed via Atomic Arch incident analysis.
"""
affected_versions = ["1.2.3-1", "1.2.4-1"]
safe_versions = []             # empty = no known safe version

[references]
urls = [
  "https://thecinderproject.qd.je/advisories/malicious-pkg-2026-06-14"
]
```

**Submission:** Maintainer-only. Open a GitHub issue with evidence; core team
reviews and merges. No automated submissions for advisories.

**Effect on trust score:** A confirmed advisory applies a `-30` penalty to the
affected package's trust score, regardless of other signals. A suspected advisory
applies `-15`.

---

### 2. PKGBUILD Snapshots (automated client submissions)

Submitted anonymously by CPAC clients that have opted into crowdsourced sharing.
Two formats depending on user consent level:

#### Hash submissions (consent level: `hash`)

```toml
# snapshots/packages/firefox/hashes.toml

[[entry]]
version = "152.0.1-1"
sha256 = "abc123..."           # SHA-256 of the full PKGBUILD text
submitted_count = 847          # how many clients submitted this hash
first_seen = "2026-05-01"
last_seen = "2026-06-20"

[[entry]]
version = "152.0.1-1"
sha256 = "def456..."           # different hash = potential divergence
submitted_count = 2
first_seen = "2026-06-14"
last_seen = "2026-06-14"
```

#### Full PKGBUILD submissions (consent level: `full`)

```
snapshots/packages/firefox/pkgbuilds/
  152.0.1-1_abc123.pkgbuild    # filename = version + hash
  152.0.1-1_def456.pkgbuild    # minority hash — potentially suspicious
```

Full PKGBUILDs are sanitized through Pass 1 structural redaction before submission
(local paths, hostname, local IPs, non-public emails stripped). See `CPAC_SPEC.md`
for the full sanitization pipeline.

**Submission:** Automated only. CPAC clients submit directly; no manual PRs for
snapshot data. Submissions are batched and aggregated, not stored individually
per-user (no way to trace a submission back to a specific user).

**Effect on trust score:** A package where the user's PKGBUILD hash matches the
majority consensus gets a trust signal boost. A package where the user's hash
matches a small minority (or no known submissions) gets a warning signal.

---

## Submission Pipeline

```
User runs: cpac install some-aur-package
               ↓
CPAC fetches PKGBUILD locally
               ↓
Pass 1 sanitization (strip paths/hostname/IPs/emails)
               ↓
Pass 2 anomaly detection (flag suspicious patterns → trust signals)
               ↓
If consent = hash:  compute SHA-256, queue for submission
If consent = full:  queue sanitized PKGBUILD for submission
               ↓
On next cpac update: batch-submit queued entries to cpac-trust-db API
               ↓
Aggregated into hashes.toml / pkgbuilds/ in the repo
```

Submissions are **queued locally** and sent in batch on `cpac update` — never
sent mid-install, never blocking the install flow.

---

## Advisory Severity → Trust Score Impact

| Severity | Trust Penalty | Recommendation Floor |
|---|---|---|
| Critical | -30 | DANGER |
| High | -20 | WARNING |
| Medium | -10 | CAUTION |
| Low | -5 | No floor change |
| Suspected (any) | -15 | WARNING |
| Resolved | 0 | No penalty |

---

## Database Versioning

`meta/db.toml` tracks the schema version so CPAC can handle breaking changes:

```toml
[meta]
db_version = "1.0.0"
last_updated = "2026-06-26"
advisory_count = 12
snapshot_package_count = 847
schema_version = 1
```

If CPAC encounters a `schema_version` higher than it supports, it warns the
user to update CPAC rather than silently misreading the data.

---

## Governance

| Data Type | Who Can Submit | Review Required |
|---|---|---|
| Advisories | Core team only | Yes — maintainer merge |
| PKGBUILD snapshots (hash) | Automated CPAC clients | No — aggregated automatically |
| PKGBUILD snapshots (full) | Automated CPAC clients | No — aggregated automatically |

Community members can **report** potential advisories via GitHub issues or the
Discord server. Core team reviews evidence and publishes the advisory if confirmed.

---

## Related Projects

| Project | Role |
|---|---|
| `cpac` | Consumes cpac-trust-db; submits snapshots on `cpac update` |
| `cinderos` | Ships CPAC (and therefore cpac-trust-db) by default |
| `website` | Advisory public index at `thecinderproject.qd.je/advisories` |

---

## Roadmap

- [ ] Initial advisory schema + first entries
- [ ] Snapshot aggregation pipeline (automated client submissions)
- [ ] CPAC integration — sync on `cpac update`, query local copy
- [ ] Public advisory index on website
- [ ] Schema v2 — richer metadata (maintainer transfer history, popularity trends)

---

*Part of The Cinder Project — github.com/SabeeirSharrma/cpac-trust-db*