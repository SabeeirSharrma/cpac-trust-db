---
title: Governance
description: Submission policies and review processes.
order: 10
---

# Governance

## Submission Policy

| Data Type | Who Can Submit | Review Required |
|---|---|---|
| Advisories (published) | Maintainers only | N/A — maintainer publishes directly |
| Advisories (proposed) | Approved volunteers | Yes — maintainer approval required |
| Snapshots (hash) | Automated CPAC clients | No — aggregated automatically |
| Snapshots (full) | Automated CPAC clients | No — aggregated automatically |

## Roles

### Maintainers

- Can publish advisories directly to the database
- Review and approve/reject volunteer-submitted advisories
- Manage volunteer accounts
- Full access to the maintainer panel

### Volunteers

- Submit advisories for review via the volunteer panel
- Rate-limited to 5 submissions per day
- Submissions go to a pending queue for maintainer approval
- Cannot publish directly — all advisories require review

## Advisory Workflow

```
Volunteer runs comparer → flags package
        ↓
Fills advisory form → submits
        ↓
Goes to pending queue (rate-limited: 5/day)
        ↓
Maintainer reviews → approves or rejects
        ↓
Approved → published to advisories table (goes live immediately)
Rejected → volunteer notified with reviewer notes
```

## Access Requests

Access to the volunteer/maintainer panels is granted via Discord ticket. No public signups. Contact the project maintainer to request access.

## Reporting

Community members can **report** potential advisories via:
- GitHub issues
- Discord server

Core team reviews evidence and publishes the advisory if confirmed.

---

*Part of The Cinder Project*
