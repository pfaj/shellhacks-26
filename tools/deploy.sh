#!/bin/sh
set -e

GODOT_BIN="${GODOT_BIN:-godot}"
VERCEL_PROJECT="${VERCEL_PROJECT:-web}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/web"

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Godot not found. Set GODOT_BIN, e.g.:" >&2
	echo "  GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot $0" >&2
	exit 1
fi

mkdir -p "$BUILD_DIR"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Web" "$BUILD_DIR/index.html"

if [ ! -d "$BUILD_DIR/.vercel" ]; then
	npx --yes vercel link --yes --project "$VERCEL_PROJECT" --cwd "$BUILD_DIR"
fi

npx --yes vercel deploy --prod --yes "$BUILD_DIR"
