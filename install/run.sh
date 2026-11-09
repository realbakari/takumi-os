#!/usr/bin/env bash
# Runs every install/steps/NN-*.sh in order. Each step is idempotent. See docs/install-process.md.
set -euo pipefail
export TAKUMI_PATH=${TAKUMI_PATH:-$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)}
export TAKUMI_LOG=${TAKUMI_LOG:-$HOME/.local/state/takumi/install.log}
mkdir -p "$(dirname "$TAKUMI_LOG")"
# shellcheck source=../lib/install.sh
. "$TAKUMI_PATH/lib/install.sh"

banner "Takumi OS $(cat "$TAKUMI_PATH/version") installer"
export PATH="$TAKUMI_PATH/bin:$PATH"

for step in "$TAKUMI_PATH"/install/steps/[0-9][0-9]-*.sh; do
  name=$(basename "$step" .sh)
  if [[ -n "${TAKUMI_ONLY:-}" && "$name" != "$TAKUMI_ONLY" ]]; then continue; fi
  log_step "$name"
  if ! bash "$step" >>"$TAKUMI_LOG" 2>&1; then
    fail "step $name failed; see $TAKUMI_LOG"
  fi
done
# The summary goes to the screen, not only the log.
[[ -z "${TAKUMI_ONLY:-}" ]] && sed -n '/^=== 90-done/,$p' "$TAKUMI_LOG" | tail -n +2
ok "done"
