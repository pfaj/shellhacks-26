#!/bin/sh
set -e

GODOT_BIN="${GODOT_BIN:-godot}"
PAGES_DOMAIN="${PAGES_DOMAIN:-clankerclash.ink}"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/build/web"
PAGES_DIR="$(mktemp -d "${TMPDIR:-/tmp}/sockem-pages.XXXXXX")"
REMOTE="$(git -C "$PROJECT_DIR" remote get-url origin)"

cleanup() {
	rm -rf "$PAGES_DIR"
}
trap cleanup EXIT

if ! command -v "$GODOT_BIN" >/dev/null 2>&1; then
	echo "Godot not found. Set GODOT_BIN, e.g.:" >&2
	echo "  GODOT_BIN=/Applications/Godot.app/Contents/MacOS/Godot $0" >&2
	exit 1
fi

mkdir -p "$BUILD_DIR"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Web" "$BUILD_DIR/index.html"

cp -R "$BUILD_DIR/." "$PAGES_DIR/"
rm -rf "$PAGES_DIR/.vercel" "$PAGES_DIR/.env.local" "$PAGES_DIR/.gitignore"
find "$PAGES_DIR" -name '*.import' -delete
touch "$PAGES_DIR/.nojekyll"
echo "$PAGES_DOMAIN" > "$PAGES_DIR/CNAME"

cd "$PAGES_DIR"
git init -q -b gh-pages
git add -A
git -c user.name="sockem-deploy" -c user.email="deploy@sockem.local" commit -qm "deploy $(date -u +%Y-%m-%dT%H:%M:%SZ)"
git push -f "$REMOTE" gh-pages
echo "Published gh-pages (Pages: https://$PAGES_DOMAIN/)"
