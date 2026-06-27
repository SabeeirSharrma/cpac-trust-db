#!/usr/bin/env python3
"""
Sync snapshot hashes from TOML files to Supabase.

Reads all hashes.toml files from snapshots/packages/ and upserts them
to the Supabase snapshots table. This seeds initial data and syncs
community-maintained snapshot entries.
"""

import os
import sys
import toml
import requests
from pathlib import Path

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")

SNAPSHOTS_DIR = Path("snapshots/packages")

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
    "Prefer": "resolution=merge-duplicates",
}


def load_snapshot_entries(package_name: str, path: Path) -> list:
    """Load all entries from a hashes.toml file."""
    data = toml.load(path)
    entries = data.get("entry", [])

    result = []
    for entry in entries:
        row = {
            "package": package_name,
            "version": entry.get("version"),
            "sha256": entry.get("sha256"),
            "submitted_count": entry.get("submitted_count", 0),
            "first_seen": entry.get("first_seen"),
            "last_seen": entry.get("last_seen"),
        }
        # Include pkgbuild_text if present (consent=full submissions)
        if "pkgbuild_text" in entry:
            row["pkgbuild_text"] = entry["pkgbuild_text"]
        result.append(row)

    return result


def upsert_snapshot(snapshot: dict):
    """Upsert a single snapshot to Supabase."""
    url = f"{SUPABASE_URL}/rest/v1/snapshots"
    response = requests.post(
        url,
        headers={**HEADERS, "Prefer": "resolution=merge-duplicates,return=minimal"},
        json=snapshot,
    )
    if response.status_code not in (200, 201, 204):
        print(f"  Error upserting {snapshot['package']}@{snapshot['version']}: {response.status_code} {response.text}")
        return False
    return True


def main():
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        print("Error: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")
        sys.exit(1)

    if not SNAPSHOTS_DIR.exists():
        print("No snapshots directory found, skipping")
        return

    # Find all hashes.toml files
    hashes_files = list(SNAPSHOTS_DIR.glob("*/hashes.toml"))
    if not hashes_files:
        print("No snapshot hashes files found")
        return

    print(f"Syncing {len(hashes_files)} package snapshots to Supabase...")
    success_count = 0
    total_entries = 0

    for path in sorted(hashes_files):
        package_name = path.parent.name
        try:
            entries = load_snapshot_entries(package_name, path)
            if not entries:
                continue

            ok = True
            for entry in entries:
                if not upsert_snapshot(entry):
                    ok = False

            if ok:
                print(f"  ✓ {package_name} ({len(entries)} entries)")
                success_count += 1
                total_entries += len(entries)
            else:
                print(f"  ⚠ {package_name} (partial failure)")
        except Exception as e:
            print(f"  ✗ {package_name}: {e}")

    print(f"Synced {success_count}/{len(hashes_files)} packages ({total_entries} total entries)")


if __name__ == "__main__":
    main()
