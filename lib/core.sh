#!/usr/bin/env bash
# How a command talks to the person using it. Sourced by commands; runs on bash 3.2.
#
# Run by the Core (TAKUMI_CORE=1, stdin and stdout are pipes to it), a command speaks one line at a
# time and the Core draws it (docs/shell.md, "Conversations"):
#   ask <prompt>       the Core asks for a line and writes the answer to our stdin
#   secret <prompt>    the same, typed as dots
#   confirm <prompt>   Enter writes "yes", Esc writes "no"
#   note <text>        shown under the row while we work
#   wrong <text>       the last answer was wrong: the field shakes and turns red, and we ask again
#   done <text>        we are finished: the Core closes and says the text (then we exit 0)
#   card <json>        we are finished: the Core shows a card in place of the rows (a code to keep)
# Any other line is shown as a note. Exiting non-zero without "done" shows our last line in red.
#
# At a terminal (stdin is a tty) the same calls prompt there, on stderr, and hide secrets. Fed by a
# pipe (a script, a test) they read answers one line at a time and return 1 when the lines run out.

core_in_core() { [[ "${TAKUMI_CORE:-}" == 1 ]]; }
core_at_tty() { [[ -t 0 ]]; }

# core_ask <variable> <prompt>: a line of text. Returns 1 when no answer comes.
core_ask() {
  local __var=$1 __prompt=$2 __answer
  if core_in_core; then printf 'ask %s\n' "$__prompt"; IFS= read -r __answer || return 1
  elif core_at_tty; then IFS= read -r -p "$__prompt: " __answer || return 1
  else IFS= read -r __answer || return 1; fi
  printf -v "$__var" '%s' "$__answer"
}

# core_secret <variable> <prompt>: a password. Never echoed at a terminal.
core_secret() {
  local __var=$1 __prompt=$2 __answer
  if core_in_core; then printf 'secret %s\n' "$__prompt"; IFS= read -r __answer || return 1
  elif core_at_tty; then IFS= read -rs -p "$__prompt: " __answer || { echo; return 1; }; echo
  else IFS= read -r __answer || return 1; fi
  printf -v "$__var" '%s' "$__answer"
}

# core_confirm <prompt>: true for yes.
core_confirm() {
  local __answer
  if core_in_core; then printf 'confirm %s\n' "$1"; IFS= read -r __answer || return 1
  elif core_at_tty; then IFS= read -r -p "$1 [Y/n] " __answer || return 1; [[ -z "$__answer" ]] && __answer=yes
  else IFS= read -r __answer || return 1; fi
  case "$__answer" in y|Y|yes|Yes|YES) return 0 ;; *) return 1 ;; esac
}

core_note()  { if core_in_core; then printf 'note %s\n' "$*"; else printf '%s\n' "$*"; fi; }
core_wrong() { if core_in_core; then printf 'wrong %s\n' "$*"; else printf '%s\n' "$*"; fi; }
# core_done <text>: the last word. The caller exits 0 after it.
core_done()  { if core_in_core; then printf 'done %s\n' "$*"; else printf '%s\n' "$*"; fi; }
# core_card <json>: the last word is a card, {kicker, title, detail, secretLabel, secret, qr}: the Core
# shows it (the secret only when asked); at a terminal, its title, detail and secret.
core_card()  { if core_in_core; then printf 'card %s\n' "$1"; else jq -r '.title, .detail, .secret' <<< "$1"; fi; }
# core_fail <code> <text>: say why, in words, and exit.
core_fail()  { local __code=$1; shift; printf '%s\n' "$*"; exit "$__code"; }

# core_confirm_within <seconds> <prompt>: like core_confirm, but silence is an answer. Returns 0 for
# yes, 1 for no, 2 when the time ran out (a changed screen goes back by itself). Whole seconds only:
# bash 3.2 rejects fractions. The Core draws the countdown and stops taking the answer at the deadline.
core_confirm_within() {
  local __answer
  if core_in_core; then printf 'confirm %s %s\n' "$1" "$2"; IFS= read -r -t "$1" __answer || return 2
  elif core_at_tty; then IFS= read -r -t "$1" -p "$2 It goes back in $1 seconds. [Y/n] " __answer || { echo; return 2; }; [[ -z "$__answer" ]] && __answer=yes
  else IFS= read -r __answer || return 2; fi
  case "$__answer" in y|Y|yes|Yes|YES) return 0 ;; *) return 1 ;; esac
}

# core_sudo <why> <command...>: sudo that asks for the password where the person is looking. In the Core it
# runs `sudo -A`, and takumi approve askpass shows <why> ("Updating Takumi needs your password") with one field;
# at a terminal it is plain sudo.
core_sudo() {
  local __why=$1; shift
  if core_in_core; then TAKUMI_SUDO_WHY=$__why SUDO_ASKPASS=${SUDO_ASKPASS:-/usr/lib/takumi/commands/approve/askpass} sudo -A "$@"
  else sudo "$@"; fi
}
