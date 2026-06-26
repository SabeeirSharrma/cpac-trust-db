#!/usr/bin/env python3
"""
Sync aggregated snapshot data from Supabase to TOML files.

Reads aggregated snapshot hashes from Supabase and writes updated
hashes.toml files to snapshots/packages/<package-name>/.
"""

import os
import sys
import hashlib
import toml
import requests
from datetime import datetime
from pathlib import Path

SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_SERVICE_KEY = os.environ.get("SUPABASE_SERVICE_KEY")

SNAPSHOTS_DIR = Path("snapshots/packages")

HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
}


def fetch_aggregated_snapshots() -> dict:
    """
    Fetch aggregated snapshot data from Supabase.

    Returns a dict of {package_name: [{version, sha256, submitted_count, first_seen, last_seen}, ...]}
    """
    url = f"{SUPABASE_URL}/rest/v1/snapshots"
    params = {
        "select": "package,version,sha256,submitted_count,first_seen,last_seen",
        "order": "package,version,sha256",
    }

    response = requests.get(url, headers=HEADERS, params=params)
    if response.status_code != 200:
        print(f"Error fetching snapshots: {response.status_code} {response.text}")
        sys.exit(1)

    rows = response.json()

    # Aggregate by package
    packages = {}
    for row in rows:
        pkg = row["package"]
        if pkg not in packages:
            packages[pkg] = []
        packages[pkg].append({
            "version": row["version"],
            "sha256": row["sha256"],
            "submitted_count": row["submitted_count"],
            "first_seen": row["first_seen"],
            "last_seen": row["last_seen"],
        })

    return packages


def write_hashes_toml(package_name: str, entries: list):
    """Write aggregated hash entries to a hashes.toml file."""
    pkg_dir = SNAPSHOTS_DIR / package_name
    pkg_dir.mkdir(parents=True, exist_ok=True)

    # Build TOML structure
    data = {"entry": entries}

    output_path = pkg_dir / "hashes.toml"
    with open(output_path, "w") as f:
        toml.dump(data, f)

    return output_path


def main():
    if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
        print("Error: SUPABASE_URL and SUPABASE_SERVICE_KEY must be set")
        sys.exit(1)

    print("Fetching aggregated snapshots from Supabase...")
    packages = fetch_aggregated_snapshots()
    print(f"Found {len(packages)} packages with snapshots")

    updated_count = 0
    for package_name, entries in sorted(packages.items()):
        try:
            output_path = write_hashes_toml(package_name, entries)
            print(f"  ✓ {package_name} ({len(entries)} entries)")
            updated_count += 1
        except Exception as e:
            print(f"  ✗ {package_name}: {e}")

    print(f"Updated {updated_count}/{len(packages)} package snapshots")


if __name__ == "__main__":
    main()
