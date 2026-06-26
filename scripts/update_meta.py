#!/usr/bin/env python3
"""
Update meta/db.toml with a new version hash and timestamp.

Computes a hash of the current database state (advisories + snapshots)
and writes it to meta/db.toml along with the current timestamp.
"""

import hashlib
import toml
from datetime import datetime, timezone
from pathlib import Path

META_DIR = Path("meta")
ADVISORIES_DIR = Path("advisories/packages")
SNAPSHOTS_DIR = Path("snapshots/packages")


def compute_db_hash() -> str:
    """
    Compute a hash representing the current database state.

    Hashes the contents of all advisory and snapshot TOML files.
    """
    hasher = hashlib.sha256()

    # Hash advisories
    advisory_files = sorted(ADVISORIES_DIR.glob("*.toml")) if ADVISORIES_DIR.exists() else []
    for path in advisory_files:
        hasher.update(path.read_bytes())

    # Hash snapshots
    snapshot_files = []
    if SNAPSHOTS_DIR.exists():
        for pkg_dir in sorted(SNAPSHOTS_DIR.iterdir()):
            if pkg_dir.is_dir():
                hashes_file = pkg_dir / "hashes.toml"
                if hashes_file.exists():
                    snapshot_files.append(hashes_file)

    for path in snapshot_files:
        hasher.update(path.read_bytes())

    return hasher.hexdigest()[:16]  # Use first 16 chars for readability


def count_entries() -> tuple[int, int]:
    """Count advisories and snapshot packages."""
    advisory_count = len(list(ADVISORIES_DIR.glob("*.toml"))) if ADVISORIES_DIR.exists() else 0
    snapshot_count = len([d for d in SNAPSHOTS_DIR.iterdir() if d.is_dir()]) if SNAPSHOTS_DIR.exists() else 0
    return advisory_count, snapshot_count


def main():
    META_DIR.mkdir(parents=True, exist_ok=True)
    meta_path = META_DIR / "db.toml"

    # Load existing meta if present
    existing = {}
    if meta_path.exists():
        existing = toml.load(meta_path)

    # Compute new values
    db_hash = compute_db_hash()
    advisory_count, snapshot_count = count_entries()
    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")

    # Preserve schema_version if set, otherwise default to 1
    schema_version = existing.get("meta", {}).get("schema_version", 1)

    # Build new meta
    meta = {
        "meta": {
            "version": db_hash,
            "db_version": existing.get("meta", {}).get("db_version", "1.0.0"),
            "last_updated": today,
            "last_sync": now,
            "advisory_count": advisory_count,
            "snapshot_package_count": snapshot_count,
            "schema_version": schema_version,
        }
    }

    with open(meta_path, "w") as f:
        toml.dump(meta, f)

    print(f"Updated meta/db.toml:")
    print(f"  version: {db_hash}")
    print(f"  last_sync: {now}")
    print(f"  advisory_count: {advisory_count}")
    print(f"  snapshot_package_count: {snapshot_count}")


if __name__ == "__main__":
    main()
