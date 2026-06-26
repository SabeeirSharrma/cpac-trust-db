# Snapshot Schema

Snapshots are stored in `snapshots/packages/<package-name>/`.

## Hash Submissions (hashes.toml)

Each package has a `hashes.toml` file containing aggregated hash submissions.

### Format

```toml
[[entry]]
version = "152.0.1-1"
sha256 = "abc123..."              # SHA-256 of the full PKGBUILD text
submitted_count = 847             # how many clients submitted this hash
first_seen = "2026-05-01"         # date this hash was first seen
last_seen = "2026-06-20"          # date this hash was last seen

[[entry]]
version = "152.0.1-1"
sha256 = "def456..."              # different hash = potential divergence
submitted_count = 2
first_seen = "2026-06-14"
last_seen = "2026-06-14"
```

### Fields

#### entry.version
- **Type:** string
- **Required:** yes
- **Description:** Package version (e.g., `152.0.1-1`)

#### entry.sha256
- **Type:** string
- **Required:** yes
- **Description:** SHA-256 hash of the full PKGBUILD text

#### entry.submitted_count
- **Type:** integer
- **Required:** yes
- **Description:** Number of clients that submitted this hash

#### entry.first_seen
- **Type:** string
- **Required:** yes
- **Format:** YYYY-MM-DD
- **Description:** Date this hash was first seen

#### entry.last_seen
- **Type:** string
- **Required:** yes
- **Format:** YYYY-MM-DD
- **Description:** Date this hash was last seen

## Full PKGBUILD Submissions (pkgbuilds/)

Full PKGBUILDs are stored in `pkgbuilds/` directory with filename format:
```
<version>_<hash>.pkgbuild
```

Example:
```
snapshots/packages/firefox/pkgbuilds/
  152.0.1-1_abc123.pkgbuild
  152.0.1-1_def456.pkgbuild
```

### Sanitization

Before submission, full PKGBUILDs undergo Pass 1 structural redaction:
- Local paths are stripped
- Hostname is removed
- Local IPs are removed
- Non-public emails are removed
