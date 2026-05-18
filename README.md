<div align="center">
  <img src="./assets/Droplit-iOS-Default-128x128@1x.png" width="128" height="128" alt="Droplit icon" />

  <h1>Droplit</h1>
  <p><strong>Native macOS media optimizer — drag, drop, and optimize from anywhere.</strong></p>

  <p>
    Built with <a href="https://developer.apple.com/xcode/swiftui/">SwiftUI</a>,
    <a href="https://developer.apple.com/documentation/appkit">AppKit</a>, and
    local open-source CLI tools.
  </p>

  <p>
    <a href="#features">Features</a> •
    <a href="#install">Install</a> •
    <a href="#development">Development</a> •
    <a href="#documentation">Documentation</a> •
    <a href="#security">Security</a> •
    <a href="#license">License</a>
  </p>

  <p>
    <a href="https://github.com/duongductrong/Ghosted/stargazers"><img alt="GitHub Stars" src="https://img.shields.io/github/stars/duongductrong/Ghosted?style=flat&amp;logo=github" /></a>
    <a href="https://github.com/duongductrong/Ghosted/network/members"><img alt="GitHub Forks" src="https://img.shields.io/github/forks/duongductrong/Ghosted?style=flat&amp;logo=github" /></a>
  </p>
</div>

## Features

- **Quick Access** — a non-activating floating panel that appears while you drag a supported file. Shake the cursor (or hold for a configurable delay) to summon the drop zone, then release to optimize.
- **Local Optimizers** — uses your own installed CLI tools for maximum quality and privacy:
  - `pngquant` for PNG
  - `jpegoptim` for JPEG
  - `gifsicle` for GIF
  - `ffmpeg` for video
  - `vips` (libvips) for image resizing and WebP conversion
  - `gifski` for video-to-GIF workflows
  - `gs` (Ghostscript) for PDFs
- **Format Conversion** — one-tap conversion from the original source file:
  - Images → PNG, JPEG, WebP, or HEIC
  - Video / GIF → GIF, MOV, or MP4
- **Concurrency Queue** — processes up to your configured number of jobs in parallel; extra drops queue automatically. Cancel a running job at any time by swiping its card away.
- **Drag Out** — drag a completed card into any external app, Finder folder, or browser.
- **Smart Output** — save optimized files to a chosen folder, or use Droplit's temporary app storage with configurable auto-expiration (1–90 days).
- **Homebrew Bootstrap** — detects missing optimizers on launch and offers one-click `brew install` when Homebrew is available.
- **Onboarding** — guided first-run setup for installing dependencies and optional permissions.
- **System Settings-style UI** — native `NavigationSplitView` settings with sidebar search, grouped controls, and a dedicated About page.

## Install

> Requires **macOS 15.0** or later.
> 
> A working **Homebrew** installation is recommended so Droplit can install missing optimizer tools automatically.

### Build from source

```bash
# Clone the repository
git clone https://github.com/duongductrong/Ghosted.git
cd Ghosted

# Build and run in Xcode, or use the helper script:
./scripts/build_and_run.sh
```

After first launch, complete the in-app onboarding to install the required optimizer tools.

## Development

For local setup, source builds, and project architecture, see [docs/STRUCTURE.md](docs/STRUCTURE.md).

```bash
# Quick start
./scripts/build_and_run.sh
```

## Documentation

- [Project structure and runtime architecture](docs/STRUCTURE.md)
- [Design tokens and visual states](docs/DESIGN_TOKENS.md)

## Security

Droplit runs optimizer commands locally via CLI binaries you already own or install through Homebrew. No data is uploaded to any server, and no telemetry is collected. Optimized files are written either to a folder you choose or to a local temporary directory under `~/Library/Application Support/Droplit/Temporary Outputs/` with automatic cleanup.

## License

BSD 3-Clause License. See [LICENSE](LICENSE).
