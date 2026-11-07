# Seeking

Godot 4.7.2 project at the repository root. `./build.sh -h` lists the targets.

- `build.sh` runs on macOS or x86_64 Linux with nothing installed.
- Logs and saves: `~/Library/Application Support/Godot/app_userdata/Seeking/`.
- The app is ad-hoc signed, not notarised. If macOS refuses a copy that was downloaded or sent: `xattr -dr com.apple.quarantine Seeking.app`.
