# Seeking

A wordless, hand-painted swinging game. Hold to cast the hook and catch a branch; let go, and the swing carries you on.

This is an early build: the prologue and the opening of the spring chapter. Ready-made builds are on [itch.io](https://eouzoe.itch.io/seeking); this repository holds the game's source and a script that builds it.

## Build and play on a Mac

You need macOS 13 or later on Apple silicon, or macOS 11 or later on an Intel Mac. Nothing has to be installed first: no Xcode, no Homebrew, no Godot.

```sh
git clone https://github.com/eouzoe/seeking.git
cd seeking
./build.sh
open build/Seeking.app
```

The first run downloads about 300 MB (the Godot editor and the macOS export template) into `build/toolchain`; later runs reuse it. The app is built on your own Mac rather than downloaded, so macOS does not quarantine it and it opens without the unidentified-developer prompt. Drag it to Applications to keep it.

## Controls

- Hold Space or the left mouse button to cast and hold the hook; let go to fly.
- Esc pauses; Esc twice returns to the title screen.
- F11 toggles full screen (Control–Command–F on a Mac).

## Other platforms

- `./build.sh windows` writes `build/Seeking.exe`, a single file with nothing to install. It runs on macOS or x86_64 Linux.
- On x86_64 Linux, `./build.sh` builds the same macOS app.

## Further reading

- [docs/toolchain.md](docs/toolchain.md): what `build.sh` downloads, how it checks it and how it exports.
- [docs/architecture.md](docs/architecture.md): how the game is put together.
- [AGENTS.md](AGENTS.md): notes for coding agents.

## Credits

Music by Scott Buckley (CC BY 4.0), sounds from Freesound and Kenney (CC0), made with Godot Engine (MIT). See [CREDITS.md](CREDITS.md).
