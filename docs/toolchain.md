# Toolchain

`build.sh` is a POSIX shell script. It relies only on tools that macOS and ordinary Linux systems already have, pins one Godot release, and keeps everything it downloads or writes inside `build/`.

## What it downloads

All files come from the [Godot 4.7.2 release](https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable) (18 August 2026).

| File | Needed for | Download | Checked against |
| --- | --- | --- | --- |
| `Godot_v4.7.2-stable_macos.universal.zip` | the editor on a Mac | 170.6 MB | SHA-512 from the release's `SHA512-SUMS.txt` |
| `Godot_v4.7.2-stable_linux.x86_64.zip` | the editor on Linux | 77.9 MB | SHA-512 from the release's `SHA512-SUMS.txt` |
| `templates/macos.zip` | the macOS export | 122.9 MB | CRC-32 and length (by gzip), then SHA-256 |
| `templates/windows_release_x86_64.exe` | the Windows export | 37.9 MB | CRC-32 and length (by gzip), then SHA-256 |

A macOS build therefore downloads about 294 MB, and a Windows build on a Mac about 209 MB.

## Taking one template out of the archive

Godot ships every export template in one zip archive, `Godot_v4.7.2-stable_export_templates.tpz`, of 1.28 GB. GitHub serves release files with HTTP range support, so `build.sh` asks only for the bytes of the member it needs. A zip member is stored as a raw deflate stream: the script puts a ten-byte gzip header in front of it and a trailer with the member's CRC-32 and length behind it, and `gzip -d` inflates it while checking both. The SHA-256 of the result is then compared with a value computed from the official archive.

The byte ranges, CRC-32s, lengths and SHA-256s are constants in `build.sh`, read once from the archive's central directory. `curl --max-filesize` stops the download if a server ever ignores the range and starts sending the whole archive.

## A self-contained editor

An empty `._sc_` file beside the editor (beside `Godot.app` on a Mac) puts Godot into self-contained mode: its settings, caches and export templates go to `build/toolchain/editor_data` instead of the home directory. Export templates are looked up in `editor_data/export_templates/4.7.2.stable/`, which is where `build.sh` puts them.

`build/.gdignore` stops Godot from treating anything under `build/` as part of the project.

## Import and export

The editor and the template download in parallel. Then one command, `--headless --export-release macOS build/Seeking.app` (or `Windows build/Seeking.exe`), imports every asset into `.godot/imported/` following the committed `.import` files and exports with the matching preset in `export_presets.cfg`; an export waits for the import on its own, so no separate `--import` run is needed.

The macOS preset builds one universal binary for Apple silicon and Intel. Godot only allows that when `rendering/textures/vram_compression/import_etc2_astc` is on; every texture is imported losslessly, so the setting adds nothing to the export. The app is signed ad hoc by Godot's built-in signer (`codesign/codesign=1`), the same on every host, with no entitlements, and it is not notarised. It needs macOS 13 or later on Apple silicon and macOS 11 or later on Intel.

The Windows preset builds a single x86_64 executable with the game data embedded and the icon from `art/ui/icon.ico`.

## Gatekeeper

macOS checks an app with Gatekeeper only if it carries the `com.apple.quarantine` attribute, which browsers, mail and chat apps add to what they download. Neither `git clone`, `curl` nor Godot's exporter adds it, so an app built with `build.sh` opens directly. A copy that has been sent to someone does carry it; because the app is not notarised, macOS then refuses to open it until the attribute is cleared (`xattr -dr com.apple.quarantine Seeking.app`) or the app is allowed in System Settings → Privacy & Security → Open Anyway.

## Moving to another Godot release

1. Change `GODOT_VERSION` in `build.sh`.
2. Copy the new editors' SHA-512s from the release's `SHA512-SUMS.txt`.
3. For each template, read from the new `.tpz`'s central directory the member's compressed size, CRC-32 and length, and its data offset: the local header offset plus 30 bytes plus the name and extra-field lengths of the local header. Python's `zipfile` reports all but the data offset (`ZipInfo.header_offset` gives the local header). Record the SHA-256 of the extracted file.
4. Read the release notes for changes to export options and project settings, then build both targets and play them.
