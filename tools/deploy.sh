#!/bin/sh
set -e

GODOT_BIN="${GODOT_BIN:-godot}"
VERCEL_PROJECT="${VERCEL_PROJECT:-web}"
VERCEL_SCOPE="${VERCEL_SCOPE:-pfajs-projects}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/web"
UPLOAD_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sockem-deploy.XXXXXX")"

cleanup() {
	rm -rf "$UPLOAD_DIR"
}
trap cleanup EXIT

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Godot not found. Set GODOT_BIN, e.g.:" >&2
	echo "  GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot $0" >&2
	exit 1
fi

mkdir -p "$BUILD_DIR"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Web" "$BUILD_DIR/index.html"

cp -R "$BUILD_DIR/." "$UPLOAD_DIR/"
rm -rf "$UPLOAD_DIR/.vercel" "$UPLOAD_DIR/.env.local" "$UPLOAD_DIR/.gitignore"
find "$UPLOAD_DIR" -name '*.import' -delete

cd "$UPLOAD_DIR"
npx --yes vercel deploy --prod --yes . --project "$VERCEL_PROJECT" --scope "$VERCEL_SCOPE"
