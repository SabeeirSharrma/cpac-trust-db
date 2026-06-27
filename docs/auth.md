---
title: Auth Model
description: Authentication and authorization for the trust API and panels.
order: 9
---

# Auth Model

## Public API

| Operation | Auth Required |
|---|---|
| Read advisories | None — fully public |
| Read snapshots | None — fully public |
| GET `/api/meta` | None — fully public |
| POST `/api/snapshots` | Bearer token (per-install, anonymous) |
| Write advisories (direct) | Maintainer only (Supabase RLS) |

## Panel Auth

The maintainer and volunteer panels use **Supabase Auth** (email/password).

| Panel | Access | Auth Method |
|---|---|---|
| `/panel/login` | Anyone with credentials | Supabase Auth |
| `/panel/volunteer` | Volunteers only | Supabase Auth + role check |
| `/panel/maintainer` | Maintainers only | Supabase Auth + role check |

### No Public Signups

Accounts are created manually by administrators. To request access, open a ticket on Discord. Credentials are shared via DM.

### Roles

| Role | Capabilities | Rate Limit |
|---|---|---|
| `maintainer` | Publish advisories, review/approve/reject submissions, manage panels | Unlimited |
| `volunteer` | Submit advisories for review, use comparer tool | 5 submissions/day |

### RLS Policies

- **Profiles**: users read their own; maintainers read all
- **Pending advisories**: volunteers read/insert their own; maintainers read/update all
- **Advisories**: public read; maintainer write via `approve_advisory()` function

## Anonymous Tokens

Anonymous tokens are issued on first CPAC run. They are used for rate limiting and abuse prevention only — not linked to any user identity.

---

*Part of The Cinder Project*
