# Seeking

Godot 4.7.2 game, GDScript only. The repository root is the Godot project.

## Build

- `./build.sh` → `build/Seeking.app` (universal macOS app).
- `./build.sh windows` → `build/Seeking.exe`.
- `./build.sh godot <args>` runs the pinned editor, e.g. `./build.sh godot -e`.

Runs on macOS (13+ on Apple silicon, 11+ on Intel) or x86_64 Linux with no prior installs. The first run downloads about 300 MB into `build/`; nothing is written elsewhere. Output ends with `==> done`; any failure prints `build.sh: <reason>` and exits non-zero.

## Run

`open build/Seeking.app`. Hold Space or the left mouse button to swing; Esc pauses. Logs and saves: `~/Library/Application Support/Godot/app_userdata/Seeking/`.

## Pitfalls

- The app is signed ad hoc and not notarised. If macOS refuses to open a copy that was downloaded or sent: `xattr -dr com.apple.quarantine Seeking.app`.
- Godot is pinned to 4.7.2: the checksums and byte ranges in `build.sh` belong to that release.
