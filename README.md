# Claude Code Overlay

A Nix flake overlay that provides pre-built Claude Code CLI binaries from official Anthropic releases.

This overlay downloads binaries directly from Anthropic's distribution servers, similar to [mitchellh/zig-overlay](https://github.com/mitchellh/zig-overlay).

## Features

- ✅ Automatic updates via GitHub Actions (hourly checks)
- ✅ Multi-platform support: Linux (x86_64, aarch64) and macOS (x86_64, aarch64)
- ✅ Direct downloads from official Anthropic servers
- ✅ SHA256 checksum verification
- ✅ Flake and non-flake support

## Why Use This Overlay?

While there are existing Claude Code packages in the Nix ecosystem ([nix-ai-tools](https://github.com/numtide/nix-ai-tools/blob/main/packages/claude-code/package.nix) and [nixpkgs](https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/cl/claude-code/package.nix)), this overlay provides the **official pre-built binary distribution** with several advantages:

### Performance Benefits
- **Native binary execution**: Official pre-built binaries from Anthropic run significantly faster than Node.js-based distributions
- **Lower startup time**: No Node.js runtime overhead
- **Reduced memory footprint**: Direct binary execution without JavaScript engine

### Official Support
- **Recommended by Anthropic**: The official Claude Code documentation recommends using the pre-built binary distribution for optimal performance
- **Direct from source**: Binaries are downloaded directly from Anthropic's official distribution servers
- **Guaranteed compatibility**: Official builds are tested and verified by Anthropic

### Additional Benefits
- **Faster updates**: Automated hourly checks ensure you get the latest version quickly
- **Consistent behaviour**: Same binaries used across all platforms match official installation methods
- **Simplified maintenance**: No need to rebuild from source or manage Node.js dependencies

If you prioritise performance and want the officially supported distribution, this overlay is the recommended choice.

## Unfree Licence Notice

Claude Code is distributed under an unfree licence. You must explicitly allow unfree packages to use this overlay.

### Option 1: Per-Package Allowance (Recommended)

The safest approach - only allows Claude Code specifically:

**For NixOS** (`configuration.nix`):
```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  "claude"
];
```

**For home-manager** (`home.nix`):
```nix
nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
  "claude"
];
```

**For standalone config** (`~/.config/nixpkgs/config.nix`):
```nix
{
  allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
    "claude"
  ];
}
```

### Option 2: Environment Variable (Temporary)

For ad-hoc usage without persistent configuration:

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run --impure github:ryoppippi/claude-code-overlay
```

**Note:** Requires `--impure` flag to access environment variables in flakes.

### Option 3: Global Allow (Not Recommended)

Only use if you understand the implications:

```nix
nixpkgs.config.allowUnfree = true;
```

This permits **all** unfree packages system-wide without explicit review.

## Usage

### Quick Start

Try Claude Code without installation:

```bash
# Run Claude Code directly (requires --impure for unfree licence)
NIXPKGS_ALLOW_UNFREE=1 nix run --impure github:ryoppippi/claude-code-overlay

# Or enter a shell with Claude Code available
NIXPKGS_ALLOW_UNFREE=1 nix shell --impure github:ryoppippi/claude-code-overlay
claude --version
```

To avoid typing `NIXPKGS_ALLOW_UNFREE=1 --impure` every time, configure unfree package allowance as described in the [Unfree Licence Notice](#unfree-licence-notice) section above.

### With Flakes

#### Run directly

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run --impure github:ryoppippi/claude-code-overlay
```

#### Add to your flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    claude-code-overlay.url = "github:ryoppippi/claude-code-overlay";
  };

  outputs = { self, nixpkgs, claude-code-overlay, ... }: {
    nixosConfigurations.yourhostname = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        ({ pkgs, lib, ... }: {
          nixpkgs.config.allowUnfreePredicate = pkg: builtins.elem (lib.getName pkg) [
            "claude"
          ];
          nixpkgs.overlays = [ claude-code-overlay.overlays.default ];
          environment.systemPackages = [ pkgs.claudepkgs.default ];
        })
      ];
    };
  };
}
```

#### Using in `home-manager`

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager.url = "github:nix-community/home-manager";
    claude-code-overlay.url = "github:ryoppippi/claude-code-overlay";
  };

  outputs = { nixpkgs, home-manager, claude-code-overlay, ... }: {
    homeConfigurations."user@hostname" = home-manager.lib.homeManagerConfiguration {
      pkgs = import nixpkgs {
        system = "x86_64-linux";
        config.allowUnfreePredicate = pkg:
          builtins.elem (nixpkgs.lib.getName pkg) [ "claude" ];
        overlays = [ claude-code-overlay.overlays.default ];
      };

      modules = [
        {
          home.packages = [ pkgs.claudepkgs.default ];
        }
      ];
    };
  };
}
```

### Without Flakes

```nix
let
  claude-code-overlay = import (builtins.fetchTarball {
    url = "https://github.com/ryoppippi/claude-code-overlay/archive/main.tar.gz";
  });
  pkgs = import <nixpkgs> {
    config.allowUnfreePredicate = pkg:
      builtins.elem (pkgs.lib.getName pkg) [ "claude" ];
    overlays = [ claude-code-overlay.overlays.default ];
  };
in
  pkgs.claudepkgs.default
```

## Available Packages

- `default` - Latest stable version
- `claude` - Claude Code CLI package

## How It Works

1. The `update.py` script fetches the latest stable version from Anthropic's release server
2. It uses `nix-prefetch-url` to fetch SHA256 checksums for all platforms
3. GitHub Actions runs the update script hourly and commits any changes
4. The flake provides pre-built binaries for all supported platforms

## Supported Platforms

- `x86_64-linux`
- `aarch64-linux`
- `x86_64-darwin` (macOS Intel)
- `aarch64-darwin` (macOS Apple Silicon)

## Development

### Setup development environment

**Option 1: Using direnv (Recommended)**

If you have [direnv](https://direnv.net/) installed:

```bash
direnv allow
```

This automatically loads the development environment and installs pre-commit hooks when you enter the directory.

**Option 2: Manual**

Enter the development shell to set up pre-commit hooks:

```bash
nix develop
```

This will automatically install git pre-commit hooks that run:
- **alejandra** - Nix code formatter
- **deadnix** - Dead code detection
- **statix** - Nix linter

### Update sources manually

```bash
nix develop
./update
```

### Test the overlay

```bash
NIXPKGS_ALLOW_UNFREE=1 nix build --impure
./result/bin/claude --version
```

### Run checks manually

```bash
# Format all Nix files
nix fmt

# Run all checks (formatting, linting, builds)
nix flake check
```

## Credits

- Claude Code CLI by [Anthropic](https://anthropic.com)

## Licence

MIT
