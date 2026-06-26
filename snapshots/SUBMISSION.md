# Snapshot Submission Guide

This guide explains how PKGBUILD snapshots are submitted to cpac-trust-db.

## Who Can Submit

**Automated CPAC clients only.** No manual PRs for snapshot data.

## How It Works

### 1. User Runs CPAC

When a user runs `cpac install`, `cpac trust`, or `cpac audit`:
- CPAC fetches the PKGBUILD locally
- Pass 1 sanitization strips paths, hostname, IPs, emails
- Pass 2 anomaly detection flags suspicious patterns
- Data is queued for submission

### 2. Submission on Next Update

Queued entries are sent in batch on `cpac update` via `POST /api/submit/snapshot` — never mid-install, never blocking the install flow.

### 3. Aggregation

After submission:
1. Data is written directly to Supabase (skips GitHub entirely)
2. GitHub Actions runs on a schedule (e.g. nightly)
3. Reads aggregated snapshot data from Supabase
4. Compiles + commits updated `hashes.toml` files to repo
5. One single commit per scheduled run, no overlap possible

Final storage:
- `hashes.toml` — hash submissions
- `pkgbuilds/` — full PKGBUILD submissions (opt-in)

## Consent Levels

| Level | What's Submitted | Privacy |
|---|---|---|
| `hash` | SHA-256 hash of PKGBUILD | High — only hash is stored |
| `full` | Sanitized PKGBUILD text | Medium — text is redacted |

## Privacy

- Submissions are anonymous and aggregated (no per-user data)
- Full PKGBUILDs undergo Pass 1 structural redaction:
  - Local paths are stripped
  - Hostname is removed
  - Local IPs are removed
  - Non-public emails are removed

## File Structure

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

## Questions?

Open a GitHub issue or reach out on Discord.
