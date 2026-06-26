---
title: Auth Model
description: Authentication and authorization for the trust API.
order: 9
---

# Auth Model

## Overview

| Operation | Auth Required |
|---|---|
| Read advisories | None — fully public |
| Read snapshots | None — fully public |
| GET `/api/meta` | None — fully public |
| POST `/api/submit/snapshot` | Bearer token (per-install, anonymous) |
| Write advisories | Maintainer only (Supabase RLS) |

## Anonymous Tokens

Anonymous tokens are issued on first CPAC run. They are used for rate limiting and abuse prevention only — not linked to any user identity.

## Row-Level Security (RLS)

Supabase RLS policies enforce:
- **Public read** — anyone can query advisories and snapshots
- **Authenticated write** — only token holders can submit snapshots
- **Maintainer write** — only core team can create/edit advisories

---

*Part of The Cinder Project*
