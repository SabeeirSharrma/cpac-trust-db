# PKGBUILD Snapshots

Crowdsourced PKGBUILD snapshots submitted by CPAC clients for detecting package divergence.

## Submission Guidelines

**Who can submit:** Automated CPAC clients only (no manual PRs).

**Consent levels:**
- `hash` — submits only the SHA-256 hash of the PKGBUILD
- `full` — submits the sanitized PKGBUILD text

**Privacy:**
- Submissions are anonymous and aggregated (no per-user data)
- Full PKGBUILDs are sanitized through Pass 1 structural redaction before submission
- Local paths, hostname, local IPs, and non-public emails are stripped

**Submission process:**
1. CPAC fetches PKGBUILD locally
2. Pass 1 sanitization (strip paths/hostname/IPs/emails)
3. Pass 2 anomaly detection (flag suspicious patterns)
4. Queue locally for submission
5. On `cpac update` → batch POST to `/api/submit/snapshot`
6. GitHub Actions aggregates into TOML → commits to repo → syncs to Supabase

## Directory Structure

```
snapshots/packages/
  <package-name>/
    hashes.toml          # Aggregated hash submissions
    pkgbuilds/           # Full PKGBUILD submissions (opt-in)
      <version>_<hash>.pkgbuild
```

## Trust Score Impact

- **Majority hash match:** Trust signal boost
- **Minority hash match:** Warning signal
- **No known submissions:** Warning signal
