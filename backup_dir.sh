#!/usr/bin/env bash
# backup_dir.sh
# Purpose : Create a timestamped compressed backup (tar.gz) of a directory.
# Author  : TanZ (example)
# Date    : 2025-11-18
#
# Usage   : ./backup_dir.sh /path/to/source /path/to/backup_dir
# Example : ./backup_dir.sh /home/user/project /mnt/backups
#
# Notes   : - Keeps backups named like project_YYYYMMDD_HHMMSS.tar.gz
#           - Exits on errors, prints helpful messages.

set -euo pipefail

# --- Input arguments ---
SOURCE_DIR="${1:-}"         # Directory to back up (first argument)
BACKUP_BASE_DIR="${2:-}"    # Directory where backups will be stored (second argument)

# --- Validate args ---
if [[ -z "$SOURCE_DIR" || -z "$BACKUP_BASE_DIR" ]]; then
  echo "Usage: $0 /path/to/source /path/to/backup_dir"
  exit 2
fi

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "Error: Source directory '$SOURCE_DIR' does not exist or is not a directory."
  exit 3
fi

# --- Prepare names ---
TIMESTAMP="$(date +'%Y%m%d_%H%M%S')"                       # ISO-like compact timestamp
SOURCE_BASENAME="$(basename "$SOURCE_DIR")"                # Name used in archive filename
ARCHIVE_NAME="${SOURCE_BASENAME}_${TIMESTAMP}.tar.gz"      # final archive filename
DEST_DIR="$BACKUP_BASE_DIR/$(date +'%Y-%m-%d')"            # optional subdir per-day
DEST_PATH="${DEST_DIR}/${ARCHIVE_NAME}"                   # full path to archive

# --- Ensure destination exists ---
mkdir -p "$DEST_DIR"

# --- Create the compressed tar archive ---
echo "Backing up '$SOURCE_DIR' -> '$DEST_PATH'..."
# -C to change directory avoids storing absolute paths in the tarball
tar -czf "$DEST_PATH" -C "$(dirname "$SOURCE_DIR")" "$SOURCE_BASENAME"

# --- Verify archive created and report size ---
if [[ -f "$DEST_PATH" ]]; then
  ARCHIVE_SIZE_BYTES=$(stat -c%s "$DEST_PATH" 2>/dev/null || stat -f%z "$DEST_PATH")
  echo "Backup created successfully: $DEST_PATH (${ARCHIVE_SIZE_BYTES} bytes)"
  exit 0
else
  echo "Error: backup failed — archive not found at '$DEST_PATH'."
  exit 4
fi
