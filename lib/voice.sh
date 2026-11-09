#!/usr/bin/env bash
# Dictation on this computer: the microphone through pw-record, the words through whisper.cpp's whisper-cli, typed
# where you were with wtype. Nothing leaves the computer. Sourced by commands/voice/*, not run; runs on bash 3.2
# (the tests use fake tools on macOS). See docs/dictation.md.
#
# While it listens, $XDG_RUNTIME_DIR/takumi-voice holds "<recorder pid> <meter pid> <started> <recording>"; the
# recording lies beside it, in memory, and is deleted as soon as it has been written down. The speech models live
# in ~/.local/share/takumi/voice/; ~/.config/takumi/voice.toml names the one in use and the language spoken.

voice_run="${XDG_RUNTIME_DIR:-$HOME/.local/state/takumi}"
voice_marker="$voice_run/takumi-voice"
voice_dir="$HOME/.local/share/takumi/voice"
voice_config="$HOME/.config/takumi/voice.toml"
voice_url="${TAKUMI_VOICE_URL:-https://huggingface.co/ggerganov/whisper.cpp/resolve/main}"
voice_hint="Super+H again to stop"
voice_limit=300   # seconds: a dictation left running stops by itself and is typed
voice_quiet=20    # the loudest moment under this level (about -46 dB) was no speech
voice_pid=""

# The models dictation can use, smallest first: name, size on disk in MiB, SHA-1, as whisper.cpp lists them
# (models/README.md in its repository). The tests give their own with TAKUMI_VOICE_MODELS.
voice_models() {
  if [[ -n "${TAKUMI_VOICE_MODELS:-}" ]]; then cat "$TAKUMI_VOICE_MODELS"; return 0; fi
  printf 'base\t142\t465707469ff3a37a2b9b8d8f89f2f99de7299dac\n'
  printf 'small\t466\t55356645c2b361a969dfd0ef2c5a50d530afd8d5\n'
  printf 'large-v3-turbo-q5_0\t547\te050f7970618a659205450ad97eb95a18d69c9ee\n'
}
# voice_field <model> <column>: 1 its name, 2 its MiB, 3 its SHA-1; nothing for a model not in the list.
voice_field() { voice_models | awk -F '\t' -v n="$1" -v c="$2" '$1 == n { print $c; exit }'; }
# voice_mb <model>: its size as a file manager shows it, in MB.
voice_mb() { local mib; mib=$(voice_field "$1" 2); echo $(( (${mib:-0} * 1048576 + 500000) / 1000000 )); }

# The model for this computer, by its memory: the largest under 6 GiB of memory is base, under 12 GiB small,
# else large-v3-turbo (quantised: as accurate as the large model at a fraction of its size and time).
voice_pick() {
  local kb
  kb=$(awk '/^MemTotal:/ { print $2; exit }' "${TAKUMI_MEMINFO:-/proc/meminfo}" 2>/dev/null || true)
  kb=${kb:-0}
  if (( kb >= 12 * 1048576 )); then echo large-v3-turbo-q5_0
  elif (( kb >= 6 * 1048576 )); then echo small
  else echo base; fi
}

# voice_get <key> <default>: from voice.toml.
voice_get() {
  local v=""
  [[ -f "$voice_config" ]] && v=$(sed -n "s/^$1 *= *\"\([A-Za-z0-9._-]*\)\".*/\1/p" "$voice_config" | head -n 1)
  printf '%s\n' "${v:-$2}"
}
# voice_save <model>: voice.toml written whole, keeping the language.
voice_save() {
  local lang
  lang=$(voice_get language auto)
  mkdir -p "${voice_config%/*}"
  {
    printf '# Dictation: the speech model in ~/.local/share/takumi/voice, and the language you speak. See docs/dictation.md.\n'
    printf 'model = "%s"\n' "$1"
    printf 'language = "%s"   # auto, or a code such as en, de, es, fr, ja\n' "$lang"
  } > "$voice_config.tmp"
  mv "$voice_config.tmp" "$voice_config"
}

# The model file in use: the one voice.toml names, else the largest here; nothing before setup.
voice_model() {
  local want name file=""
  want=$(voice_get model "")
  if [[ -n "$want" && -s "$voice_dir/ggml-$want.bin" ]]; then printf '%s\n' "$voice_dir/ggml-$want.bin"; return 0; fi
  while IFS="$(printf '\t')" read -r name _; do
    if [[ -n "$name" && -s "$voice_dir/ggml-$name.bin" ]]; then file="$voice_dir/ggml-$name.bin"; fi
  done <<< "$(voice_models)"
  [[ -z "$file" ]] || printf '%s\n' "$file"
}
voice_language() { voice_get language auto; }
voice_threads() {
  local n
  n=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)
  if (( n > 8 )); then n=8; elif (( n < 1 )); then n=1; fi
  echo "$n"
}

# voice_sha1 <file>
voice_sha1() {
  if command -v sha1sum >/dev/null; then sha1sum "$1" | cut -d ' ' -f 1; else shasum -a 1 "$1" | cut -d ' ' -f 1; fi
}

# True while dictation listens.
voice_listening() {
  local pid=""
  [[ -r "$voice_marker" ]] && read -r pid _ < "$voice_marker" && [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# The microphone in use, by its sound-server name; nothing when there is none (an output's monitor stands in).
voice_mic() {
  local s
  s=$(LC_ALL=C pactl get-default-source 2>/dev/null || true)
  case "$s" in "" | *.monitor | auto_null*) return 0 ;; esac
  printf '%s\n' "$s"
}

# voice_spawn <command...>: started on its own; its pid in voice_pid.
voice_spawn() {
  if command -v setsid >/dev/null; then setsid "$@" </dev/null >/dev/null 2>&1 &
  else "$@" </dev/null >/dev/null 2>&1 & fi
  voice_pid=$!
}

# voice_level <recording>: how loud its last tenth of a second was, 0 to 100: -55 dB of full scale is 0, -10 dB
# is 100. The recording is 16-bit samples at 16 kHz after a 44-byte header, growing as it records.
voice_level() {
  local size skip
  [[ -f "$1" ]] || { echo 0; return 0; }
  size=$(wc -c < "$1" | tr -d ' ')
  (( size > 44 + 3200 )) || { echo 0; return 0; }
  skip=$(( size - 3200 )); skip=$(( skip - (skip - 44) % 2 ))
  od -An -v -t d2 -j "$skip" -N 3200 "$1" 2>/dev/null | awk '
    { for (i = 1; i <= NF; i++) { s += $i * $i; n++ } }
    END {
      if (n == 0 || s == 0) { print 0; exit }
      db = 20 * log(sqrt(s / n) / 32768) / log(10); v = (db + 55) * 100 / 45
      if (v < 0) v = 0; if (v > 100) v = 100; printf "%d\n", v
    }'
}

# voice_meter <recorder pid> <recording> <started>: says "Listening…" with the level three times a second, keeps
# the loudest moment for the end, and stops a dictation left running too long. Run in the background.
voice_meter() {
  local lvl max=-1
  while kill -0 "$1" 2>/dev/null; do
    lvl=$(voice_level "$2")
    if (( lvl > max )); then max=$lvl; printf '%s\n' "$max" > "$voice_marker.loudest"; fi
    takumi notice mic "Listening…" "$voice_hint" "$lvl" >/dev/null 2>&1 || true
    if (( $(date +%s) - $3 >= voice_limit )); then takumi voice stop >/dev/null 2>&1 & return 0; fi
    sleep 0.3
  done
}

# What whisper-cli wrote, on stdin, as one line: without its marks for silence and noise ("[BLANK_AUDIO]").
voice_clean() { tr '\n' ' ' | sed -e 's/\[[^]]*\]//g' -e 's/[[:space:]][[:space:]]*/ /g' -e 's/^ //' -e 's/ $//'; }

# voice_transcribe <recording>: what was said, as one line, from the model on this computer.
voice_transcribe() {
  local model out
  model=$(voice_model)
  [[ -n "$model" ]] || return 1
  out=$(whisper-cli -m "$model" -f "$1" -l "$(voice_language)" -t "$(voice_threads)" -nt -np -sns 2>/dev/null) || return 1
  printf '%s\n' "$out" | voice_clean
}

# voice_type <text>: typed into the window in front, through stdin (never on a command line). Returns 2 when it
# was copied instead, for want of wtype, and 1 when neither worked.
voice_type() {
  if command -v wtype >/dev/null; then
    printf '%s' "$1" | LC_ALL=C.UTF-8 wtype - && return 0
  fi
  printf '%s' "$1" | wl-copy >/dev/null 2>&1 && return 2
  return 1
}

# The window in front (niri's id), and putting it back in front: typing goes where you were.
voice_window() { niri msg -j focused-window 2>/dev/null | jq -r '.id // empty' 2>/dev/null || true; }
voice_focus() {
  [[ -n "$1" && "$(voice_window)" != "$1" ]] || return 0
  niri msg action focus-window --id "$1" >/dev/null 2>&1 || true
}

# voice_short <text>: its first words, for a notice.
voice_short() { if (( ${#1} > 60 )); then printf '%s…\n' "${1:0:60}"; else printf '%s\n' "$1"; fi; }
