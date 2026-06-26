# Advisories

Maintainer-curated records of known malicious, compromised, or suspicious packages.

## Submission Guidelines

**Who can submit:** Core team only (The Cinder Project).

**How to submit:**
1. Open a GitHub issue with evidence of the compromised package
2. Include package name, affected versions, and description of the issue
3. Core team reviews and merges the advisory

**No automated submissions.** Community members can report potential advisories via GitHub issues or Discord, but only core team members can publish advisories.

## File Format

Each advisory is a TOML file in `packages/<package-name>.toml`. See [schema.md](schema.md) for the full specification.

## Trust Score Impact

| Severity | Trust Penalty | Recommendation Floor |
|---|---|---|
| Critical | -30 | DANGER |
| High | -20 | WARNING |
| Medium | -10 | CAUTION |
| Low | -5 | No floor change |
| Suspected (any) | -15 | WARNING |
| Resolved | 0 | No penalty |
