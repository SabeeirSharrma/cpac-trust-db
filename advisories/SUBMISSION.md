# Advisory Submission Guide

This guide explains how to submit advisories to cpac-trust-db.

## Who Can Submit

**Core team only.** Community members can report potential advisories via GitHub issues, but only core team members can publish advisories.

## How to Report

### Step 1: Gather Evidence

Collect as much as possible:
- Package name
- Affected versions
- Description of the issue
- Links to relevant discussions, commits, or diffs
- Screenshots if helpful

### Step 2: Open a GitHub Issue

Use the "Advisory Report" issue template and fill in:
- Package name
- Severity level (critical/high/medium/low)
- Affected versions
- Description of the issue
- Evidence

### Step 3: Review

Core team reviews the evidence and either:
- Publishes the advisory (creates the TOML file)
- Requests more information
- Closes the issue if not confirmed

## Severity Guidelines

| Severity | Use When |
|---|---|
| Critical | Remote code execution, data exfiltration, system compromise |
| High | Malware, backdoors, credential theft |
| Medium | Suspicious behavior, potential supply chain risk |
| Low | Minor issues, policy violations |

## File Format

Advisories are stored as TOML files in `advisories/packages/<package-name>.toml`. See [schema.md](schema.md) for the full specification.

Example:
```toml
[advisory]
package = "malicious-pkg"
severity = "critical"
status = "confirmed"
reported = "2026-06-14"
updated = "2026-06-14"
reported_by = "The Cinder Project"
cve = ""

[details]
summary = "Package PKGBUILD modified to execute remote script post-install"
description = """
On 2026-06-14, the maintainer of malicious-pkg transferred ownership and
introduced a curl | bash call in the post_install() function targeting
an external IP.
"""
affected_versions = ["1.2.3-1", "1.2.4-1"]
safe_versions = []

[references]
urls = [
  "https://thecinderproject.qd.je/advisories/malicious-pkg-2026-06-14"
]
```

## Questions?

Open a GitHub issue or reach out on Discord.
