#!/usr/bin/env nix
#! nix shell --inputs-from .# nixpkgs#python3 nixpkgs#nix-prefetch --command python3

"""Update script for claude package.

Claude Code provides version info at a stable endpoint and distributes
platform-specific binaries with checksums in manifest.json.

Inspired by:
https://github.com/numtide/nix-ai-tools/blob/91132d4e72ed07374b9d4a718305e9282753bac9/packages/coderabbit-cli/update.py
"""

import json
import re
import subprocess
from pathlib import Path
from typing import Optional
from urllib.request import urlopen


def fetch_claude_version() -> str:
    """Fetch the latest version from Claude Code's stable endpoint."""
    url = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/stable"
    with urlopen(url) as response:
        return response.read().decode("utf-8").strip()


def fetch_manifest(version: str) -> dict:
    """Fetch the manifest.json for a specific version."""
    url = f"https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases/{version}/manifest.json"
    with urlopen(url) as response:
        return json.loads(response.read().decode("utf-8"))


def sha256_to_sri(sha256_hex: str) -> str:
    """Convert a SHA256 hex hash to SRI format."""
    result = subprocess.run(
        ["nix", "hash", "to-sri", "--type", "sha256", sha256_hex],
        capture_output=True,
        text=True,
        check=True,
    )
    return result.stdout.strip()


def get_current_version() -> Optional[str]:
    """Get the current version from default.nix."""
    default_nix = Path(__file__).parent / "default.nix"
    content = default_nix.read_text()

    match = re.search(r'version = "([^"]+)";', content)
    return match.group(1) if match else None


def update_default_nix(version: str, hashes: dict[str, str]) -> None:
    """Update default.nix with new version and hashes using regex."""
    default_nix = Path(__file__).parent / "default.nix"
    content = default_nix.read_text()

    # Update version
    content = re.sub(
        r'version = "[^"]+";',
        f'version = "{version}";',
        content,
        count=1,
    )

    # Update each platform hash
    for platform, hash_value in hashes.items():
        # Match the platform block and update its hash
        pattern = rf'({platform} = \{{[^}}]*?hash = ")[^"]+(")'
        content = re.sub(pattern, rf'\g<1>{hash_value}\g<2>', content, flags=re.DOTALL)

    default_nix.write_text(content)


def main() -> None:
    """Update the claude package."""
    current_version = get_current_version()
    latest_version = fetch_claude_version()

    print(f"Current version: {current_version}")
    print(f"Latest version: {latest_version}")

    print(f"Updating claude from {current_version} to {latest_version}")

    # Define platforms mapping (Nix platform -> manifest platform)
    platforms = {
        "x86_64-linux": "linux-x64",
        "aarch64-linux": "linux-arm64",
        "x86_64-darwin": "darwin-x64",
        "aarch64-darwin": "darwin-arm64",
    }

    # Fetch manifest and extract hashes
    print("Fetching manifest.json...")
    manifest = fetch_manifest(latest_version)
    hashes = {}

    for nix_platform, manifest_platform in platforms.items():
        checksum = manifest["platforms"][manifest_platform]["checksum"]
        sri_hash = sha256_to_sri(checksum)
        hashes[nix_platform] = sri_hash
        print(f"  {nix_platform}: {sri_hash}")

    print()

    # Update default.nix
    update_default_nix(latest_version, hashes)
    print(f"Updated claude to version {latest_version}")


if __name__ == "__main__":
    main()
