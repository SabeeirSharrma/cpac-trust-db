---
title: Advisories
description: Maintainer-curated records of malicious or compromised packages.
order: 6
---

# Advisories

Maintained directly by The Cinder Project core team. Stored as TOML in the GitHub repo, synced to Supabase via GitHub Actions on merge.

## Format

```toml
[advisory]
package = "malicious-pkg"
severity = "critical"          # critical | high | medium | low
status = "confirmed"           # confirmed | suspected | resolved
reported = "2026-06-14"
updated = "2026-06-14"
reported_by = "The Cinder Project"
cve = ""                       # if applicable

[details]
summary = "PKGBUILD modified to execute remote script post-install"
description = """
On 2026-06-14, maintainer transferred ownership and introduced a
curl | bash call targeting an external IP.
"""
affected_versions = ["1.2.3-1", "1.2.4-1"]
safe_versions = []

[references]
urls = ["https://thecinderproject.qd.je/advisories/malicious-pkg-2026-06-14"]
```

See [advisories/schema.md](../advisories/schema.md) for full field specification.

## Submission

Community members report via GitHub issue or Discord. Core team reviews evidence and publishes. No automated advisory submissions.

## Trust Score Impact

| Severity | Trust Penalty | Recommendation Floor |
|---|---|---|
| Critical | -30 | DANGER |
| High | -20 | WARNING |
| Medium | -10 | CAUTION |
| Low | -5 | No floor change |
| Suspected (any) | -15 | WARNING |
| Resolved | 0 | No penalty |

---

*Part of The Cinder Project*
