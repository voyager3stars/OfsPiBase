#!/bin/bash
# =================================================================
# Project:      OFSPiBase (OrionFieldStack Pi Base)
# Component:    Common Utility Functions
# Author:       voyager3.stars
# Web:          https://voyager3.stars.ne.jp
# License:      MIT
# Description:  Shared helper functions for the setup system.
#               Sourced by setup.sh and individual modules.
# =================================================================

# ── Logging ──────────────────────────────────────────────────────

info()  { echo "[INFO]  $*"; }
warn()  { echo "[WARN]  $*" >&2; }
error() { echo "[ERROR] $*" >&2; }

# ── Section Banner ───────────────────────────────────────────────

print_section() {
  local num="$1"
  local title="$2"
  echo ""
  echo "=========================================="
  echo " ${num}. ${title}"
  echo "=========================================="
}

# ── User Prompts ─────────────────────────────────────────────────

# ask_yes_no <prompt_text> [default: Y]
#   Returns 0 (true) if user answers Yes, 1 (false) otherwise.
ask_yes_no() {
  local prompt="$1"
  local default="${2:-Y}"
  local answer

  read -r -p "${prompt} (Y/n): " answer
  answer="${answer:-$default}"
  [[ "$answer" =~ ^[Yy]$ ]]
}

# prompt_with_default <prompt_text> <default_value>
#   Echoes the user's input (or the default if empty).
prompt_with_default() {
  local prompt="$1"
  local default="$2"
  local input

  read -r -p "${prompt} [${default}]: " input
  echo "${input:-$default}"
}

# ── Root Check ───────────────────────────────────────────────────

require_root() {
  if [ "$EUID" -ne 0 ]; then
    error "sudo を付けて実行してください (例: sudo $0)"
    exit 1
  fi
}

# ── Resolve Target User ─────────────────────────────────────────

resolve_target_user() {
  TARGET_USER="${SUDO_USER:-$USER}"
  USER_HOME=$(getent passwd "$TARGET_USER" | cut -d: -f6)
}
