# Contributing to cpac-trust-db

Thank you for your interest in cpac-trust-db.

## Contribution Policy

**At this time, we are not accepting unsolicited pull requests or direct commits to this repository.**

This repository is maintained strictly by the core developers/maintainers. Any commits, pull requests, or code modifications by individuals who have not been explicitly invited as collaborators or granted prior written permission will be **rejected and closed immediately**.

### Why this policy?

CPAC is a security-focused tool — its trust engine, resolver, and sanitization pipeline are the parts of the codebase that users rely on to make safe install decisions. An unreviewed external change to those areas isn't just a process risk, it's a real attack surface. Until CPAC's contribution review process is more established, we're keeping the codebase strictly maintainer-controlled to protect that trust.

### How to get involved

If you're interested in contributing code, reach out to the project maintainers first — contact options are listed on our GitHub Pages site:

- **Owner / Maintainer / Main Developer:** [Sabeeir Sharrma](https://github.com/sabeeirsharrma)

Only after being officially invited as a collaborator, joining our organization, or receiving explicit permission from the core team may you begin submitting changes.

### Bug reports and suggestions

You don't need prior permission for this part — bug reports, feature suggestions, and general feedback are welcome through either:

- Opening a new [issue](https://github.com/sabeeirsharrma/cpac-trust-db/issues) on this repository
- Our [Discord server](https://discord.com/invite/3ZMtEgJjFT)

---

## Report a Suspected Advisory

If you discover a malicious, compromised, or suspicious package:

1. **Open a GitHub issue** with:
   - Package name
   - Affected versions
   - Description of the issue
   - Evidence (links, diffs, screenshots)
2. Core team reviews and publishes the advisory if confirmed

**Do not submit advisories directly.** Only core team members can publish advisories.

---

## What NOT to Submit

- **No manual PKGBUILD snapshots.** Snapshots are submitted automatically by CPAC clients that are opted-in.
- **No automated advisory submissions.** Advisories are reviewed by the core team.
- **No secrets or credentials.** Never commit API keys, tokens, or private data, all data from cpac clients is sanitized.

---

## Code of Conduct

Be respectful. We're all here to make the Arch ecosystem safer.

---

*Part of The Cinder Project*
