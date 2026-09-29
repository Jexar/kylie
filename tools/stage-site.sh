#!/usr/bin/env bash
# Copies the publishable site into the folder given as $1, leaving out the
# full-size originals. Only the resized copies that build-photos.bat makes
# (photos/<game>/thumb, photos/<game>/web, images/web) go online.
#
# Used by netlify.toml and .github/workflows/pages.yml.

set -euo pipefail

dest="${1:?usage: stage-site.sh <output folder>}"
root="$(cd "$(dirname "$0")/.." && pwd)"

rm -rf "$dest"
mkdir -p "$dest"
dest="$(cd "$dest" && pwd)"

tar -C "$root" \
  --exclude=./.git --exclude=./.github --exclude=./.claude --exclude=./.netlify \
  --exclude=./tools --exclude=./build-photos.bat --exclude=./README.md \
  --exclude=./.gitignore --exclude=./netlify.toml --exclude="./$(basename "$dest")" \
  -cf - . | tar -C "$dest" -xf -

cd "$dest"
# Originals sit directly in each game folder; thumb/ and web/ are kept.
find photos -mindepth 2 -maxdepth 2 -type f -delete
# Originals of the home and about page images; images/web/ is kept.
find images -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' \) -delete

echo "Staged $(du -sh . | cut -f1) into $dest"
