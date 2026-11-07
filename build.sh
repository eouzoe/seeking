#!/bin/sh
set -eu
trap 'exit 130' INT TERM

GODOT_VERSION=4.7.2
TAG="$GODOT_VERSION-stable"
RELEASES="https://github.com/godotengine/godot-builds/releases/download/$TAG"
TEMPLATE_ARCHIVE="$RELEASES/Godot_v${TAG}_export_templates.tpz"

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
OUT="$ROOT/build"
TOOLS="$OUT/toolchain"
TEMPLATES="$TOOLS/editor_data/export_templates/$GODOT_VERSION.stable"

usage() {
	cat <<EOF
Usage: ./build.sh [mac | win | godot <args>]

  mac            build/Seeking.app (default)
  win            build/Seeking.exe
  godot <args>   run the pinned Godot $GODOT_VERSION editor

Downloads go to build/toolchain and are checked against pinned checksums.
EOF
}

say() {
	printf '==> %s\n' "$*"
}

die() {
	printf 'build.sh: %s\n' "$*" >&2
	exit 1
}

digest() {
	if command -v "sha${1}sum" >/dev/null 2>&1; then
		line=$("sha${1}sum" "$2")
	elif command -v shasum >/dev/null 2>&1; then
		line=$(shasum -a "$1" "$2")
	else
		line=$(openssl dgst "-sha$1" -r "$2")
	fi
	printf '%s' "${line%% *}"
}

verify() {
	[ "$(digest "$1" "$2")" = "$3" ] || die "checksum mismatch: $2"
}

download() {
	url=$1 file=$2 range=${3-} limit=${4-}
	if [ -n "$range" ]; then
		curl -fsSL --connect-timeout 30 --retry 5 --max-filesize "$limit" -r "$range" -o "$file.part" "$url"
	else
		curl -fsSL --connect-timeout 30 --retry 5 -o "$file.part" "$url"
	fi || die "download failed: $url"
	mv "$file.part" "$file"
}

le32() {
	printf "$(printf '\\%03o\\%03o\\%03o\\%03o' $(($1 & 255)) $(($1 >> 8 & 255)) $(($1 >> 16 & 255)) $(($1 >> 24 & 255)))"
}

host() {
	case "$(uname -s)/$(uname -m)" in
	Darwin/*) echo macos ;;
	Linux/x86_64) echo linux ;;
	*) die "unsupported machine: $(uname -s) $(uname -m) (macOS or x86_64 Linux needed)" ;;
	esac
}

editor() {
	case "$HOST" in
	macos)
		archive="Godot_v${TAG}_macos.universal.zip" size=171
		sum=38aa16e5bba2083941fc5b3e54be0089bd4cc35e32415f5b9fd9a8a6a7b9818255d44532ea8ef94b5aef56c4b407c2d634fa4f657e4ebe681ebbf59b7bac69ca
		GODOT="$TOOLS/Godot.app/Contents/MacOS/Godot"
		;;
	linux)
		archive="Godot_v${TAG}_linux.x86_64.zip" size=78
		sum=9aa00f7a605200940bce3027a567b782f49bd8e940dd06ae9e987bd65aee1b1467edd56ed84fcdcbdd44354bf613bdbb4e5d2913e925850368e150c59ed54c65
		GODOT="$TOOLS/Godot_v${TAG}_linux.x86_64"
		;;
	esac
	if [ ! -x "$GODOT" ]; then
		say "downloading the Godot $GODOT_VERSION editor ($size MB)"
		mkdir -p "$TOOLS"
		download "$RELEASES/$archive" "$TOOLS/$archive"
		verify 512 "$TOOLS/$archive" "$sum"
		if [ "$HOST" = macos ]; then
			ditto -x -k "$TOOLS/$archive" "$TOOLS"
		else
			if command -v unzip >/dev/null 2>&1; then
				unzip -q -o "$TOOLS/$archive" -d "$TOOLS"
			else
				bsdtar -xf "$TOOLS/$archive" -C "$TOOLS"
			fi
			chmod +x "$GODOT"
		fi
		rm -f "$TOOLS/$archive"
	fi
	: >"$TOOLS/._sc_"
}

template() {
	name=$1 offset=$2 packed=$3 crc=$4 size=$5 sum=$6
	if [ -f "$TEMPLATES/$name" ] && [ "$(digest 256 "$TEMPLATES/$name")" = "$sum" ]; then
		return 0
	fi
	say "downloading the $name export template ($((packed / 1048576)) MB of the template archive)"
	mkdir -p "$TEMPLATES"
	download "$TEMPLATE_ARCHIVE" "$TEMPLATES/$name.deflate" "$offset-$((offset + packed - 1))" "$packed"
	{
		printf '\037\213\010\000\000\000\000\000\000\377'
		cat "$TEMPLATES/$name.deflate"
		le32 "$crc"
		le32 "$size"
	} | gzip -dc >"$TEMPLATES/$name.part" || die "could not unpack $name"
	rm -f "$TEMPLATES/$name.deflate"
	verify 256 "$TEMPLATES/$name.part" "$sum"
	mv "$TEMPLATES/$name.part" "$TEMPLATES/$name"
}

prepare() {
	command -v curl >/dev/null 2>&1 || die "curl is needed to download Godot"
	HOST=$(host)
	if [ "$HOST" = linux ] && ! command -v unzip >/dev/null 2>&1 && ! command -v bsdtar >/dev/null 2>&1; then
		die "unzip or bsdtar is needed to unpack the editor"
	fi
	mkdir -p "$OUT"
	: >"$OUT/.gdignore"
}

fetch_both() {
	prepare
	template "$@" &
	pid=$!
	trap 'kill "$pid" $(pgrep -P "$pid" 2>/dev/null) 2>/dev/null' EXIT
	editor
	wait "$pid" || die "could not get the $1 export template"
	trap - EXIT
}

export_project() {
	preset=$1 target=$2
	say "importing and exporting $preset to ${target#"$ROOT"/}"
	rm -rf "$target"
	"$GODOT" --headless --path "$ROOT" --export-release "$preset" "$target" || die "the $preset export failed"
	[ -e "$target" ] || die "the $preset export did not produce $target"
}

case "${1:-mac}" in
mac | macos)
	fetch_both macos.zip 863271911 122879307 0x2986734b 123597580 88df5e2e6fee99088699be66e6d42e4da4fb0c5619d054297d755a49558a4792
	export_project macOS "$OUT/Seeking.app"
	say "done: build/Seeking.app (open build/Seeking.app)"
	;;
win | windows)
	fetch_both windows_release_x86_64.exe 1243455810 37890306 0x1ee85628 109268480 d34d36f3be1a6c49c56525ae86469b92e4f417ddf0b43cf00dd80c385c4b0562
	export_project Windows "$OUT/Seeking.exe"
	say "done: build/Seeking.exe"
	;;
godot)
	shift
	prepare
	editor
	exec "$GODOT" "$@"
	;;
-h | --help | help)
	usage
	;;
*)
	usage >&2
	exit 2
	;;
esac
