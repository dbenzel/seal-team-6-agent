#!/bin/sh
# Generate checksums.sha256 for release integrity verification.
# Usage: ./scripts/generate-checksums.sh
set -e
cd "$(dirname "$0")/.."

if command -v shasum > /dev/null 2>&1; then
  HASH_CMD="shasum -a 256"
elif command -v sha256sum > /dev/null 2>&1; then
  HASH_CMD="sha256sum"
else
  echo "Error: need shasum or sha256sum" >&2
  exit 1
fi

# shellcheck disable=SC1091
. ./manifest.conf

OUT="checksums.sha256"
: > "$OUT"

# Expand paths: files as-is, directories recursively
tmp_list=$(mktemp)
trap 'rm -f "$tmp_list"' EXIT

for path in $CHECKSUM_PATHS; do
  if [ -f "$path" ]; then
    echo "$path" >> "$tmp_list"
  elif [ -d "$path" ]; then
    find "$path" -type f ! -name '.DS_Store' | sort >> "$tmp_list"
  else
    echo "Warning: missing path for checksums: $path" >&2
  fi
done

sort -u "$tmp_list" | while IFS= read -r f; do
  # Portable: hash then rewrite path (shasum prints "hash  path")
  $HASH_CMD "$f" >> "$OUT"
done

echo "Wrote $OUT ($(wc -l < "$OUT" | tr -d ' ') files)"
