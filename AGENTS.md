# Seeking: notes for coding agents

Seeking is a Godot 4.7.2 game written entirely in GDScript. The repository root is the Godot project (`project.godot`); there are no compiled extensions, package managers or submodules.

## Build

| Command | Result |
| --- | --- |
| `./build.sh` | the macOS app, `build/Seeking.app` (universal: Apple silicon and Intel) |
| `./build.sh windows` | the Windows executable, `build/Seeking.exe` |
| `./build.sh godot <args>` | the pinned Godot editor run with `<args>`, e.g. `./build.sh godot -e` opens the project |

- The script runs on macOS and on x86_64 Linux. It needs only tools those systems ship with: `curl`, `gzip`, `ditto` (macOS) or `unzip` (Linux), and `shasum`, `sha256sum` or `openssl`.
- The first run downloads Godot into `build/toolchain` (about 300 MB on a Mac) and checks every file against a checksum pinned in the script. Later runs reuse it. Nothing is written outside the repository.
- A good run ends with `==> done: build/Seeking.app`. Any failure stops at once with a `build.sh:` line naming what went wrong; a checksum mismatch means a corrupt or tampered download, so delete `build/toolchain` and run again.
- To play without exporting, after one `./build.sh`: `./build.sh godot --path .`

## Check a build

- `open build/Seeking.app` shows a dark loading screen with a warm light, then the title. Hold Space to start.
- `codesign --verify --deep --strict build/Seeking.app` prints nothing: Godot's built-in signer gives the app an ad-hoc signature, which Apple silicon requires.
- `lipo -archs build/Seeking.app/Contents/MacOS/Seeking` prints `x86_64 arm64`.
- Logs and saves live in `~/Library/Application Support/Godot/app_userdata/Seeking/` (`logs/godot.log`, `progress.cfg`).
- The app is not notarised. A copy built on the Mac that runs it is never quarantined, so Gatekeeper does not stop it. A copy that arrived through a browser or a chat app is: clear it with `xattr -dr com.apple.quarantine Seeking.app`, or use System Settings → Privacy & Security → Open Anyway.

## Working on the code

- Keep Godot at 4.7.2. The checksums and archive offsets in `build.sh` belong to that release; [docs/toolchain.md](docs/toolchain.md) explains how to move to another.
- GDScript is fully typed (`var x: float`, `func f(a: int) -> void`); an inferred `Variant` counts as an error.
- Scripts load each other with `preload("res://…")` constants rather than global class names.
- The simulation in `sim/` is deterministic at a fixed 120 Hz: never feed it frame time, wall-clock time or randomness.
- `view/` only reads what `game/` hands it and never changes the simulation. Art parameters live in `look/`.
- `build/` and `.godot/` are local caches, ignored by git.

[docs/architecture.md](docs/architecture.md) describes how the pieces fit together.
