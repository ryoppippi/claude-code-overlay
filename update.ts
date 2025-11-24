#!/usr/bin/env nix
/*
#! nix shell --inputs-from .# nixpkgs#bun -c bun
*/

/**
 * Update script for claude package.
 *
 * Claude Code provides version info at a stable endpoint and distributes
 * platform-specific binaries with checksums in manifest.json.
 *
 * Inspired by:
 * https://github.com/numtide/nix-ai-tools/blob/91132d4e72ed07374b9d4a718305e9282753bac9/packages/coderabbit-cli/update.py
 */

import { $ } from "bun";
import * as v from "valibot@1.1.0";
import { join } from "node:path";

const BASE_URL = "https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases";

// Define schemas
const ManifestPlatformSchema = v.object({
	checksum: v.string(),
	size: v.number(),
});

const ManifestSchema = v.object({
	version: v.string(),
	buildDate: v.string(),
	platforms: v.record(v.string(), ManifestPlatformSchema),
});

type Manifest = v.InferOutput<typeof ManifestSchema>;

// Platform mappings (Nix platform -> manifest platform)
const platforms = {
	"x86_64-linux": "linux-x64",
	"aarch64-linux": "linux-arm64",
	"x86_64-darwin": "darwin-x64",
	"aarch64-darwin": "darwin-arm64",
} as const;

type NixPlatform = keyof typeof platforms;

/**
 * Fetch the latest version from Claude Code's stable endpoint.
 */
async function fetchClaudeVersion(): Promise<string> {
	const url = `${BASE_URL}/stable`;
	const response = await fetch(url);
	const text = await response.text();
	return text.trim();
}

/**
 * Fetch the manifest.json for a specific version.
 */
async function fetchManifest(version: string): Promise<Manifest> {
	const url = `${BASE_URL}/${version}/manifest.json`;
	const response = await fetch(url);
	const json = await response.json();
	return v.parse(ManifestSchema, json);
}

/**
 * Convert a SHA256 hex hash to SRI format.
 */
async function sha256ToSri(sha256Hex: string): Promise<string> {
	const result = await $`nix hash to-sri --type sha256 ${sha256Hex}`.text();
	return result.trim();
}

/**
 * Get the current version from default.nix.
 */
async function getCurrentVersion(): Promise<string | null> {
	const defaultNixPath = join(import.meta.dir, "default.nix");
	const content = await Bun.file(defaultNixPath).text();

	const match = content.match(/version = "([^"]+)";/);
	return match?.[1] ?? null;
}

/**
 * Update default.nix with new version and hashes using regex.
 */
async function updateDefaultNix(version: string, hashes: Record<NixPlatform, string>): Promise<void> {
	const defaultNixPath = join(import.meta.dir, "default.nix");
	let content = await Bun.file(defaultNixPath).text();

	// Update version
	content = content.replace(
		/version = "[^"]+";/,
		`version = "${version}";`,
	);

	// Update each platform hash
	for (const [platform, hashValue] of Object.entries(hashes)) {
		const pattern = new RegExp(
			`(${platform} = \\{[^}]*?hash = ")[^"]+(")`,
			"s",
		);
		content = content.replace(pattern, `$1${hashValue}$2`);
	}

	await Bun.write(defaultNixPath, content);
}

// Main execution
const currentVersion = await getCurrentVersion();
const latestVersion = await fetchClaudeVersion();

console.log(`Current version: ${currentVersion}`);
console.log(`Latest version: ${latestVersion}`);

console.log(`Updating claude from ${currentVersion} to ${latestVersion}`);

// Fetch manifest and extract hashes
console.log("Fetching manifest.json...");
const manifest = await fetchManifest(latestVersion);
const hashes: Record<NixPlatform, string> = {} as Record<NixPlatform, string>;

for (const [nixPlatform, manifestPlatform] of Object.entries(platforms)) {
	const checksum = manifest.platforms[manifestPlatform].checksum;
	const sriHash = await sha256ToSri(checksum);
	hashes[nixPlatform as NixPlatform] = sriHash;
	console.log(`  ${nixPlatform}: ${sriHash}`);
}

console.log();

// Update default.nix
await updateDefaultNix(latestVersion, hashes);
console.log(`Updated claude to version ${latestVersion}`);
