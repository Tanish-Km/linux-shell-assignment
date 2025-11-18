#!/usr/bin/env bash
# auto_download.sh
# Purpose : Download a file from a URL into a predefined directory using curl or wget.
# Author  : TanZ (example)
# Date    : 2025-11-18
#
# Usage   : ./auto_download.sh URL /path/to/download_directory
# Example : ./auto_download.sh "https://example.com/file.zip" ~/Downloads
#
# Notes   : - Resumes partial downloads if supported by the tool.
#           - Detects curl or wget automatically.
#           - Exits non-zero on failure.

set -euo pipefail

# --- Inputs ---
DOWNLOAD_URL="${1:-}"           # URL to download (first arg)
DOWNLOAD_DIR="${2:-./downloads}" # destination directory (second arg, default ./downloads)

# --- Validate input URL ---
if [[ -z "$DOWNLOAD_URL" ]]; then
  echo "Usage: $0 URL /path/to/download_directory"
  exit 2
fi

# --- Ensure destination directory exists ---
mkdir -p "$DOWNLOAD_DIR"

# --- Helper to derive filename from URL or headers ---
infer_filename() {
  # If user provided a path-like URL, take basename
  local url="$1"
  local base
  base="$(basename "${url%%\?*}")"
  # If basename is empty or just '/', fallback to timestamped name
  if [[ -z "$base" || "$base" == "/" ]]; then
    base="download_$(date +'%Y%m%d_%H%M%S')"
  fi
  echo "$base"
}

FILENAME="$(infer_filename "$DOWNLOAD_URL")"
DEST_PATH="${DOWNLOAD_DIR%/}/$FILENAME"

# --- Choose downloader ---
if command -v curl >/dev/null 2>&1; then
  DOWNLOADER="curl"
elif command -v wget >/dev/null 2>&1; then
  DOWNLOADER="wget"
else
  echo "Error: Neither curl nor wget is installed. Please install one of them and retry."
  exit 3
fi

echo "Using downloader: $DOWNLOADER"
echo "Downloading: $DOWNLOAD_URL"
echo "Saving to: $DEST_PATH"

# --- Perform download with resume support ---
if [[ "$DOWNLOADER" == "curl" ]]; then
  # -L follow redirects, -f fail on HTTP errors, -C - resume, -o output file, --progress-bar show progress
  if curl -L -f -C - -o "$DEST_PATH" --progress-bar "$DOWNLOAD_URL"; then
    echo "Download completed: $DEST_PATH"
  else
    echo "Download failed (curl)."
    exit 4
  fi
else
  # wget: -c resume, -O output file, --show-progress
  if wget -c --show-progress -O "$DEST_PATH" "$DOWNLOAD_URL"; then
    echo "Download completed: $DEST_PATH"
  else
    echo "Download failed (wget)."
    exit 4
  fi
fi

# --- Optional: Print file info ---
if [[ -f "$DEST_PATH" ]]; then
  echo "File size: $(stat -c%s "$DEST_PATH" 2>/dev/null || stat -f%z "$DEST_PATH") bytes"
  exit 0
else
  echo "Unexpected error: expected file not found after download."
  exit 5
fi
