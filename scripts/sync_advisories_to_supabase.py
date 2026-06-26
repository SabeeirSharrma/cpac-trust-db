#!/usr/bin/env python3
"""
Sync advisories from TOML files to Supabase.

Reads all advisory TOML files from advisories/packages/ and upserts them
to the Supabase advisories table. This ensures the API can serve advisories.
"""

import os
import sys
import hashlib
import toml
import requests
from pathlib import Path

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")

ADVISORIES_DIR = Path("advisories/packages")

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates",
}


def load_advisory(path: Path) -> dict:
    """Load and normalize a single advisory TOML file."""
    data = toml.load(path)
    advisory = data.get("advisory", {})
    details = data.get("details", {})
    references = data.get("references", {})

    return {
        "package": advisory.get("package"),
        "severity": advisory.get("severity"),
        "status": advisory.get("status"),
        "reported": advisory.get("reported"),
        "updated": advisory.get("updated"),
        "reported_by": advisory.get("reported_by"),
        "cve": advisory.get("cve", ""),
        "summary": details.get("summary", ""),
        "description": details.get("description", ""),
        "affected_versions": details.get("affected_versions", []),
        "safe_versions": details.get("safe_versions", []),
        "reference_urls": references.get("urls", []),
        "file_hash": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def upsert_advisory(advisory: dict):
    """Upsert a single advisory to Supabase."""
    url = f"{SUPABASE_URL}/rest/v1/advisories"
    # Use package as the conflict target for upsert
    response = requests.post(
        url,
        headers={**HEADERS, "Prefer": "resolution=merge-duplicates,return=minimal"},
        json=advisory,
    )
    if response.status_code not in (200, 201, 204):
        print(f"  Error upserting {advisory['package']}: {response.status_code} {response.text}")
        return False
    return True


def main():
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        print("Error: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")
        sys.exit(1)

    if not ADVISORIES_DIR.exists():
        print("No advisories directory found, skipping")
        return

    advisory_files = [
        f for f in ADVISORIES_DIR.glob("*.toml")
        if not f.name.startswith("_")  # Skip example/template files
    ]
    if not advisory_files:
        print("No advisory files found")
        return

    print(f"Syncing {len(advisory_files)} advisories to Supabase...")
    success_count = 0

    for path in sorted(advisory_files):
        try:
            advisory = load_advisory(path)
            if upsert_advisory(advisory):
                print(f"  ✓ {advisory['package']}")
                success_count += 1
        except Exception as e:
            print(f"  ✗ {path.name}: {e}")

    print(f"Synced {success_count}/{len(advisory_files)} advisories")


if __name__ == "__main__":
    main()
