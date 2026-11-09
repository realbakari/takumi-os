#!/usr/bin/env bash
# The installer's shared functions: what it says on the screen and in its log, and installing the packages
# a list names. Sourced by install/run.sh and its steps, not run.
banner()   { printf '\n\033[1m%s\033[0m\n\n' "$*"; }
log_step() { printf '\033[36m::\033[0m %s\n' "$*"; printf '\n=== %s (%s)\n' "$*" "$(date -Is)" >>"${TAKUMI_LOG:-/dev/null}"; }
ok()       { printf '\033[32m::\033[0m %s\n' "$*"; }
fail()     { printf '\033[31m!!\033[0m %s\n' "$*" >&2; exit 1; }
# TAKUMI_PACMAN_CONF: another pacman.conf, such as the setup disc's own packages (commands/setup/install).
pkg_conf=()
[[ -n "${TAKUMI_PACMAN_CONF:-}" ]] && pkg_conf=(--config "$TAKUMI_PACMAN_CONF")
# Install every package named in a list file, skipping comments, blanks and what the repositories lack.
pkg_install_list() {
  local list=$1
  local -a pkgs=() missing=()
  local p
  while read -r p; do
    [[ -n "$p" ]] || continue
    if pacman ${pkg_conf[@]+"${pkg_conf[@]}"} -Si "$p" >/dev/null 2>&1; then pkgs+=("$p"); else missing+=("$p"); fi
  done < <(sed 's/#.*//; /^[[:space:]]*$/d' "$list")
  (( ${#missing[@]} )) && echo "skipping packages this repo does not carry: ${missing[*]}" >&2
  sudo pacman ${pkg_conf[@]+"${pkg_conf[@]}"} -S --needed --noconfirm "${pkgs[@]}"   # pacman
}
