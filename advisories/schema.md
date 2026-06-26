# Advisory Schema

Each advisory is a TOML file located at `advisories/packages/<package-name>.toml`.

## Format

```toml
[advisory]
package = "package-name"            # required: package name
severity = "critical"               # required: critical | high | medium | low
status = "confirmed"                # required: confirmed | suspected | resolved
reported = "2026-06-14"             # required: date reported (YYYY-MM-DD)
updated = "2026-06-14"              # required: date last updated (YYYY-MM-DD)
reported_by = "The Cinder Project"  # required: who reported it
cve = ""                           # optional: CVE ID if applicable

[details]
summary = "Short summary"           # required: one-line summary
description = """                   # required: detailed description
Full description of the advisory.
"""
affected_versions = ["1.0.0-1"]     # required: list of affected versions
safe_versions = ["1.0.1-1"]        # optional: known safe versions (empty list = none)

[references]
urls = [                            # optional: reference URLs
  "https://example.com/advisory"
]
```

## Fields

### advisory.package
- **Type:** string
- **Required:** yes
- **Description:** The package name as it appears in the AUR

### advisory.severity
- **Type:** string
- **Required:** yes
- **Values:** `critical`, `high`, `medium`, `low`
- **Description:** Severity level of the advisory

### advisory.status
- **Type:** string
- **Required:** yes
- **Values:** `confirmed`, `suspected`, `resolved`
- **Description:** Current status of the advisory

### advisory.reported
- **Type:** string
- **Required:** yes
- **Format:** YYYY-MM-DD
- **Description:** Date the advisory was first reported

### advisory.updated
- **Type:** string
- **Required:** yes
- **Format:** YYYY-MM-DD
- **Description:** Date the advisory was last updated

### advisory.reported_by
- **Type:** string
- **Required:** yes
- **Description:** Who reported the advisory

### advisory.cve
- **Type:** string
- **Required:** no
- **Description:** CVE identifier if applicable

### details.summary
- **Type:** string
- **Required:** yes
- **Description:** One-line summary of the advisory

### details.description
- **Type:** string (multiline)
- **Required:** yes
- **Description:** Detailed description of the advisory

### details.affected_versions
- **Type:** array of strings
- **Required:** yes
- **Description:** List of affected package versions

### details.safe_versions
- **Type:** array of strings
- **Required:** no
- **Description:** List of known safe versions (empty = no known safe version)

### references.urls
- **Type:** array of strings
- **Required:** no
- **Description:** List of reference URLs
