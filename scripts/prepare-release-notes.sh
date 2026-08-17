#!/usr/bin/env bash

set -euo pipefail

TAG_NAME="${1:?A release tag is required}"
OUTPUT_DIRECTORY="${2:?An output directory is required}"
NOTES_PATH="release-notes/${TAG_NAME}.md"
OUTPUT_PATH="${OUTPUT_DIRECTORY}/FocusLite.html"
VERSIONED_OUTPUT_PATH="${OUTPUT_DIRECTORY}/releases/${TAG_NAME}/FocusLite.html"

if [[ ! "$TAG_NAME" =~ ^v[0-9A-Za-z._-]+$ ]]; then
  echo "Invalid release tag: $TAG_NAME" >&2
  exit 1
fi

if [[ ! -f "$NOTES_PATH" ]]; then
  echo "Release notes not found: $NOTES_PATH" >&2
  exit 1
fi

mkdir -p "$OUTPUT_DIRECTORY"
ruby scripts/render-release-notes.rb "$NOTES_PATH" "$OUTPUT_PATH"
mkdir -p "$(dirname "$VERSIONED_OUTPUT_PATH")"
cp "$OUTPUT_PATH" "$VERSIONED_OUTPUT_PATH"

if [[ ! -s "$OUTPUT_PATH" ]]; then
  echo "Rendered release notes are empty" >&2
  exit 1
fi

echo "Prepared Sparkle release notes: $OUTPUT_PATH"
echo "Prepared versioned release notes: $VERSIONED_OUTPUT_PATH"
