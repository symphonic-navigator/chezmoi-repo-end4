#! /bin/bash
# Common functions for userscripts
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# --- Configuration ---
export USERSCRIPTS_LOG_DIR="${USERSCRIPTS_LOG_DIR:-$HOME/.local/state/userscripts}"
export USERSCRIPTS_LOCK_DIR="${USERSCRIPTS_LOCK_DIR:-/tmp/userscripts-locks}"
export USERSCRIPTS_VERBOSE="${USERSCRIPTS_VERBOSE:-0}"
export USERSCRIPTS_DRY_RUN="${USERSCRIPTS_DRY_RUN:-0}"

# --- Initialization ---
_lib_init() {
  mkdir -p "$USERSCRIPTS_LOG_DIR"
  mkdir -p "$USERSCRIPTS_LOCK_DIR"
}
_lib_init

# --- Logging ---
_log_file=""

log_init() {
  local script_name="$1"
  _log_file="$USERSCRIPTS_LOG_DIR/${script_name}-$(date +%Y%m%d-%H%M%S).log"
  echo "Log started: $(date)" >>"$_log_file"
}

log() {
  local msg="$1"
  if [[ -n "$_log_file" ]]; then
    echo "[$(date +%H:%M:%S)] $msg" >>"$_log_file"
  fi
  if [[ "$USERSCRIPTS_VERBOSE" == "1" ]]; then
    echo "[DEBUG] $msg" >&2
  fi
}

log_cmd() {
  local cmd="$*"
  log "Executing: $cmd"
  if [[ "$USERSCRIPTS_DRY_RUN" == "1" ]]; then
    echo "[DRY-RUN] $cmd"
    return 0
  fi
  "$@"
}

# Variant for sudo commands in dry-run mode
sudo_cmd() {
  if [[ "$USERSCRIPTS_DRY_RUN" == "1" ]]; then
    echo "[DRY-RUN] sudo $*"
    return 0
  fi
  sudo "$@"
}

# --- Error handling ---
_cleanup_functions=()

cleanup_register() {
  _cleanup_functions+=("$1")
}

_run_cleanup() {
  local exit_code=$?
  for fn in "${_cleanup_functions[@]}"; do
    $fn || true
  done
  exit $exit_code
}

error_handler_init() {
  trap _run_cleanup EXIT
  trap 'echo "Aborted by user"; exit 130' INT TERM
}

die() {
  echo "❌ $1" >&2
  log "ERROR: $1"
  exit "${2:-1}"
}

warn() {
  echo "⚠️ $1" >&2
  log "WARNING: $1"
}

info() {
  echo "$1"
  log "INFO: $1"
}

# --- Lock mechanism (flock-based) ---
_lock_fd=""
_lock_file=""

lock_acquire() {
  local script_name="$1"
  _lock_file="$USERSCRIPTS_LOCK_DIR/${script_name}.lock"

  exec 9>"$_lock_file"
  _lock_fd=9

  if ! flock -n 9; then
    die "Script '$script_name' is already running (Lock: $_lock_file)"
  fi

  echo "$$" >&9
  log "Lock acquired: $_lock_file (PID $$)"

  cleanup_register lock_release
}

lock_release() {
  if [[ -n "$_lock_fd" ]]; then
    flock -u "$_lock_fd" 2>/dev/null || true
    exec 9>&- 2>/dev/null || true
    rm -f "$_lock_file" 2>/dev/null || true
    log "Lock released: $_lock_file"
    _lock_fd=""
    _lock_file=""
  fi
}

# --- Root check ---
require_no_root() {
  if [[ $EUID -eq 0 ]]; then
    die "Do not run this script as root or with sudo"
  fi
}

# --- sudo refresh ---
_sudo_refresh_pid=""

sudo_keepalive_start() {
  if [[ "$USERSCRIPTS_DRY_RUN" == "1" ]]; then
    log "sudo keepalive skipped (dry-run)"
    return 0
  fi

  sudo -v || die "sudo authentication failed"

  (
    while true; do
      sudo -n true 2>/dev/null
      sleep 50
    done
  ) &
  _sudo_refresh_pid=$!

  cleanup_register sudo_keepalive_stop
  log "sudo keepalive started (PID $_sudo_refresh_pid)"
}

sudo_keepalive_stop() {
  if [[ -n "$_sudo_refresh_pid" ]]; then
    kill "$_sudo_refresh_pid" 2>/dev/null || true
    wait "$_sudo_refresh_pid" 2>/dev/null || true
    log "sudo keepalive stopped"
    _sudo_refresh_pid=""
  fi
}

# --- Interactive functions ---
ask() {
  local prompt="$1"
  local default="${2:-N}"
  local answer

  if [[ "$default" == "Y" ]]; then
    read -r -p "$prompt [Y/n]: " answer
    if [[ "$answer" =~ ^[Nn]$ ]]; then
      echo "0"
    else
      echo "1"
    fi
  else
    read -r -p "$prompt [y/N]: " answer
    if [[ "$answer" =~ ^[YyZz]$ ]]; then
      echo "1"
    else
      echo "0"
    fi
  fi
}

ask_confirm() {
  local prompt="$1"
  local answer
  read -r -p "$prompt [y/N]: " answer
  [[ "$answer" =~ ^[Yy]$ ]]
}

# --- Atomic File Write ---
atomic_write() {
  local file="$1"
  local content="$2"
  local use_sudo="${3:-0}"

  if [[ -f "$file" ]]; then
    local current
    current="$(cat "$file" 2>/dev/null || true)"
    if [[ "$current" == "$content" ]]; then
      log "File unchanged: $file"
      return 1
    fi
  fi

  if [[ "$USERSCRIPTS_DRY_RUN" == "1" ]]; then
    echo "[DRY-RUN] Would write: $file"
    return 0
  fi

  if [[ "$use_sudo" == "1" ]]; then
    echo "$content" | sudo tee "$file" >/dev/null
  else
    echo "$content" >"$file"
  fi

  log "File written: $file"
  return 0
}

# --- Network retry ---
retry() {
  local max_attempts="${1:-3}"
  local delay="${2:-5}"
  shift 2
  local cmd=("$@")

  local attempt=1
  while [[ $attempt -le $max_attempts ]]; do
    log "Attempt $attempt/$max_attempts: ${cmd[*]}"
    if "${cmd[@]}"; then
      return 0
    fi

    if [[ $attempt -lt $max_attempts ]]; then
      warn "Failed, retrying in ${delay}s..."
      sleep "$delay"
    fi
    ((attempt++))
  done

  warn "All $max_attempts attempts failed: ${cmd[*]}"
  return 1
}

# --- Package installation ---
extract_packages() {
  grep -v -E '^[[:space:]]*#|^[[:space:]]*$' "$1"
}

# --- Notification ---
notify_done() {
  local title="$1"
  local message="${2:-Done!}"

  if command -v notify-send >/dev/null; then
    notify-send "$title" "$message" 2>/dev/null || true
  fi
  log "Notification: $title - $message"
}

# --- Argument parsing helpers ---
parse_common_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --verbose | -v)
      USERSCRIPTS_VERBOSE="1"
      shift
      ;;
    --dry-run)
      USERSCRIPTS_DRY_RUN="1"
      shift
      ;;
    --log)
      shift
      ;;
    *)
      echo "$1"
      shift
      ;;
    esac
  done
}
