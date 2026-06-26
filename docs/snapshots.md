---
title: Snapshots
description: Crowdsourced PKGBUILD snapshots for detecting package divergence.
order: 7
---

# PKGBUILD Snapshots

Submitted anonymously by CPAC clients that opted into crowdsourced sharing. Two formats depending on user consent level.

## Hash Submissions (consent: `hash`)

```toml
[[entry]]
version = "152.0.1-1"
sha256 = "abc123..."
submitted_count = 847
first_seen = "2026-05-01"
last_seen = "2026-06-20"

[[entry]]
version = "152.0.1-1"
sha256 = "def456..."           # minority hash — potential divergence
submitted_count = 2
first_seen = "2026-06-14"
last_seen = "2026-06-14"
```

## Full PKGBUILD Submissions (consent: `full`)

Stored as sanitized PKGBUILD text. Pass 1 structural redaction (local paths, hostname, local IPs, non-public emails) runs locally before submission. See `CPAC_SPEC.md` for the full sanitization pipeline.

## Submission Pipeline

```
cpac install some-aur-package
        ↓
Fetch PKGBUILD locally
        ↓
Pass 1 sanitization (strip paths/hostname/IPs/emails)
        ↓
Pass 2 anomaly detection (flag suspicious patterns → trust signals, shown to user)
        ↓
consent=hash → compute SHA-256, queue locally
consent=full → queue sanitized PKGBUILD locally
        ↓
cpac update → batch POST to /api/submit/snapshot
        ↓
GitHub Actions aggregates into TOML → commits to repo → syncs to Supabase
```

Submissions are **queued locally and sent in batch on `cpac update`** — never sent mid-install, never blocking the install flow.

## Trust Score Impact

- Hash matches majority consensus → positive trust signal
- Hash matches small minority or no known submissions → warning signal

---

*Part of The Cinder Project*
