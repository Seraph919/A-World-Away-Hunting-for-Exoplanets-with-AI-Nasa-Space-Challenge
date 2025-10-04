#!/usr/bin/env bash
set -euo pipefail

# Cleanup / reset script for the Exoplanet Detector project.
# Safely removes generated artifacts so you can retrain with fresh data.
#
# Targets:
#  --models  : Delete trained_models/*.pkl and BEST.txt
#  --db      : Delete db.sqlite3 (+ journal) and re-run migrations (if --migrate given)
#  --data    : Delete downloaded raw data file (data/raw_kepler_koi.csv)
#  --all     : Shortcut for --models --db --data
#  --keep-sample : When using --data, keep sample dataset in data/sample/
#  --dry-run : Show what would be removed without deleting
#  --force   : Skip confirmation prompt
#  --migrate : After DB deletion, run migrations to create a fresh empty DB
#
# Examples:
#   Dry run full cleanup:
#       ./reset_environment.sh --all --dry-run
#   Full cleanup with confirmation:
#       ./reset_environment.sh --all
#   Only retrain models (remove old ones):
#       ./reset_environment.sh --models
#   Reset DB only and recreate schema:
#       ./reset_environment.sh --db --migrate

GREEN="\033[0;32m"; YELLOW="\033[1;33m"; RED="\033[0;31m"; NC="\033[0m"
msg() { echo -e "${GREEN}==>${NC} $*"; }
warn() { echo -e "${YELLOW}==>${NC} $*"; }
err() { echo -e "${RED}==>${NC} $*"; }

BASE_DIR=$(cd "$(dirname "$0")" && pwd)
cd "$BASE_DIR"

DO_MODELS=0
DO_DB=0
DO_DATA=0
DRY_RUN=0
FORCE=0
KEEP_SAMPLE=0
RUN_MIGRATIONS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --models) DO_MODELS=1 ;;
    --db) DO_DB=1 ;;
    --data) DO_DATA=1 ;;
    --all) DO_MODELS=1; DO_DB=1; DO_DATA=1 ;;
    --dry-run) DRY_RUN=1 ;;
    --force) FORCE=1 ;;
    --keep-sample) KEEP_SAMPLE=1 ;;
    --migrate) RUN_MIGRATIONS=1 ;;
    -h|--help)
      sed -n '1,70p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) err "Unknown argument: $1"; exit 1 ;;
  esac
  shift
done

if [[ $DO_MODELS -eq 0 && $DO_DB -eq 0 && $DO_DATA -eq 0 ]]; then
  warn "No targets specified. Nothing to do. Use --all or one of --models/--db/--data."
  exit 0
fi

msg "Planned actions:" 
[[ $DO_MODELS -eq 1 ]] && echo "  * Remove trained models (trained_models/*.pkl, BEST.txt)"
[[ $DO_DB -eq 1 ]] && echo "  * Remove SQLite database (db.sqlite3)"
[[ $DO_DATA -eq 1 ]] && echo "  * Remove downloaded raw data file (data/raw_kepler_koi.csv)" && [[ $KEEP_SAMPLE -eq 1 ]] && echo "    - Keeping sample data directory"
[[ $RUN_MIGRATIONS -eq 1 && $DO_DB -eq 1 ]] && echo "  * Recreate empty database via migrations"
[[ $DRY_RUN -eq 1 ]] && warn "Dry-run: no files will actually be deleted" || true

if [[ $FORCE -ne 1 ]]; then
  read -rp "Proceed? (y/N): " CONF
  if [[ ! $CONF =~ ^[Yy]$ ]]; then
    warn "Aborted by user"
    exit 1
  fi
fi

remove_file() {
  local f="$1"
  if [[ -e "$f" ]]; then
    if [[ $DRY_RUN -eq 1 ]]; then
      echo "(dry-run) rm $f"
    else
      rm -f "$f"
      echo "Removed $f"
    fi
  fi
}

remove_glob() {
  local pattern="$1"
  shopt -s nullglob
  for f in $pattern; do
    remove_file "$f"
  done
  shopt -u nullglob
}

# Models
if [[ $DO_MODELS -eq 1 ]]; then
  if [[ -d trained_models ]]; then
    msg "Cleaning trained models"
    remove_glob "trained_models/*.pkl"
    remove_file "trained_models/BEST.txt"
  else
    warn "trained_models directory not found"
  fi
fi

# Database
if [[ $DO_DB -eq 1 ]]; then
  msg "Removing SQLite database"
  remove_file "db.sqlite3"
  remove_file "db.sqlite3-journal"
  if [[ $RUN_MIGRATIONS -eq 1 && $DRY_RUN -eq 0 ]]; then
    msg "Running migrations to create fresh schema"
    if [[ -d .venv ]]; then
      source .venv/bin/activate || warn "Could not activate venv; ensure dependencies are installed"
    fi
    python manage.py migrate --noinput || err "Migrations failed"
  fi
fi

# Data
if [[ $DO_DATA -eq 1 ]]; then
  RAW_FILE="data/raw_kepler_koi.csv"
  if [[ -f "$RAW_FILE" ]]; then
    msg "Removing raw downloaded dataset"
    remove_file "$RAW_FILE"
  else
    warn "Raw data file not present ($RAW_FILE)"
  fi
  if [[ $KEEP_SAMPLE -eq 0 ]]; then
    # Do not delete sample because it's needed as offline fallback for setup, but allow if user wants a fully clean environment
    SAMPLE_DIR="data/sample"
    if [[ -d "$SAMPLE_DIR" ]]; then
      warn "Sample data retained by default. Use manual removal if you need to regenerate it via setup.sh."
    fi
  fi
fi

msg "Cleanup complete." 
[[ $DRY_RUN -eq 1 ]] && msg "(Dry run: no files were deleted)" || true
