#!/usr/bin/env bash
# Capturing the screen: recordings with the computer's sound, the microphone and the camera, and marking up
# screenshots. Sourced by commands/screen/*, not run; runs on bash 3.2 (the tests use fake tools on macOS).
# See docs/capture.md.
#
# A recording is known by $XDG_RUNTIME_DIR/takumi-recording, "<pid> <started, epoch seconds> <file>", which the
# Core reads for its red mark. What it took in is beside it in takumi-recording.parts, one "<key> <value>" per
# line: sound, camera, and each module it loaded into the sound server. The last choice made in the Core is in
# ~/.config/takumi/capture.toml.

capture_run="${XDG_RUNTIME_DIR:-$HOME/.local/state/takumi}"
capture_marker="$capture_run/takumi-recording"
capture_parts="$capture_run/takumi-recording.parts"
capture_log="$capture_run/takumi-recording.log"
capture_config="$HOME/.config/takumi/capture.toml"
capture_mix_sink=takumi-recording
capture_pid=""

# capture_notice <takumi notice arguments...>: a notice in the Core; silent when the shell is not there.
capture_notice() { takumi notice "$@" >/dev/null 2>&1 || true; }

# True while a recording runs.
capture_running() {
  local pid=""
  [[ -r "$capture_marker" ]] && read -r pid _ < "$capture_marker" && [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# Where recordings go (Videos/Recordings) and where niri saves screenshots (screenshot-path in
# config/niri/takumi/defaults.kdl: ~/Pictures/Screenshots).
capture_videos() {
  local dir
  dir=$(xdg-user-dir VIDEOS 2>/dev/null || true)
  [[ -n "$dir" && "$dir" != "$HOME" ]] || dir="$HOME/Videos"
  printf '%s/Recordings\n' "$dir"
}
capture_shots() { printf '%s/Pictures/Screenshots\n' "$HOME"; }

# capture_saved <sound|camera>: the last choice made in the Core. Sound is none, computer, mic or both; the
# camera yes or no. Before any choice: none and no.
capture_saved() {
  local v=""
  [[ -f "$capture_config" ]] && v=$(sed -n "s/^$1 *= *\"\{0,1\}\([a-z]*\).*/\1/p" "$capture_config" | head -n 1)
  case "$1:$v" in
    sound:none | sound:computer | sound:mic | sound:both) printf '%s\n' "$v" ;;
    sound:*) echo none ;;
    camera:true) echo yes ;;
    *) echo no ;;
  esac
}

# capture_save <sound> <yes|no>: the choice, written whole.
capture_save() {
  mkdir -p "${capture_config%/*}"
  {
    printf '# Screen recordings: what the last one took in, as chosen in the Core. See docs/capture.md.\n'
    printf 'sound = "%s"   # none | computer | mic | both\n' "$1"
    printf 'camera = %s\n' "$([[ $2 == yes ]] && echo true || echo false)"
  } > "$capture_config.tmp"
  mv "$capture_config.tmp" "$capture_config"
}

# capture_words <sound> <yes|no>: the choice, as the Core says it.
capture_words() {
  case "$1:$2" in
    none:no) echo "No sound" ;;
    computer:no) echo "Computer sound" ;;
    mic:no) echo "Your microphone" ;;
    both:no) echo "Computer sound and microphone" ;;
    none:yes) echo "Your camera, no sound" ;;
    computer:yes) echo "Computer sound and your camera" ;;
    mic:yes) echo "Your microphone and camera" ;;
    *) echo "Sound, microphone and camera" ;;
  esac
}

# The output in use, by its sound-server name (its monitor is "<name>.monitor"), and the microphone in use.
# With no microphone the sound server offers an output's monitor in its place: that is no microphone.
capture_sink() { LC_ALL=C pactl get-default-sink 2>/dev/null || true; }
capture_mic() {
  local s
  s=$(LC_ALL=C pactl get-default-source 2>/dev/null || true)
  case "$s" in "" | *.monitor | auto_null*) return 0 ;; esac
  printf '%s\n' "$s"
}

# capture_mix <output> <microphone>: a private output that the computer's sound and the microphone both play
# into, so wf-recorder, which records one sound source, takes them together and in step with the picture.
# Prints the modules it loaded, one per line, in the order to unload them.
capture_mix() {
  local null a="" b=""
  null=$(LC_ALL=C pactl load-module module-null-sink "sink_name=$capture_mix_sink" sink_properties=device.description=Recording \
         rate=48000 channels=2 2>/dev/null) || return 1
  if a=$(LC_ALL=C pactl load-module module-loopback "source=$1.monitor" "sink=$capture_mix_sink" latency_msec=30 \
           source_dont_move=true sink_dont_move=true 2>/dev/null) &&
     b=$(LC_ALL=C pactl load-module module-loopback "source=$2" "sink=$capture_mix_sink" latency_msec=30 \
           source_dont_move=true sink_dont_move=true 2>/dev/null); then
    printf '%s\n%s\n%s\n' "$b" "$a" "$null"
    return 0
  fi
  capture_unload "$a" "$null"
  return 1
}

# capture_unload <module...>: takes them out of the sound server.
capture_unload() {
  local m
  for m in "$@"; do [[ -n "$m" ]] && LC_ALL=C pactl unload-module "$m" >/dev/null 2>&1; done
  return 0
}

# Modules a recording that ended badly left behind (anything naming the private output), newest first.
capture_unmix_stale() {
  local ids
  ids=$(LC_ALL=C pactl list short modules 2>/dev/null | awk -F '\t' -v s="$capture_mix_sink" 'index($3, s) { print $1 }' | sort -rn) || true
  [[ -z "$ids" ]] && return 0
  # shellcheck disable=SC2086 # one module id per word
  capture_unload $ids
}

# True when a camera is here: a video device that captures, as udev's v4l_id says (a laptop also lists
# metadata devices that are no camera).
capture_camera() {
  local d caps
  for d in "${TAKUMI_DEV:-/dev}"/video*; do
    [[ -e "$d" ]] || continue
    caps=$(udevadm info --query=property --name="$d" 2>/dev/null | sed -n 's/^ID_V4L_CAPABILITIES=//p') || true
    [[ "$caps" == *:capture:* ]] && return 0
  done
  return 1
}

# capture_camera_show <x> <y> <width> <height>: the camera bubble in a corner of that area, in the layout's
# coordinates (shell/Core/CameraBubble.qml, through the shell's "camera" IPC target). False when the shell cannot
# show it: no shell, or a shell without Qt Multimedia, which answers "false". capture_camera_hide: gone.
capture_camera_show() {
  local said
  said=$(qs -c takumi ipc --any-display call camera show "$@" 2>/dev/null) || return 1
  [[ "$said" != *false* ]]
}
capture_camera_hide() { qs -c takumi ipc --any-display call camera hide >/dev/null 2>&1 || true; }

# capture_numbers <"x,y WxH">: the four numbers of slurp's geometry, "x y w h".
capture_numbers() {
  local re='^(-?[0-9]+),(-?[0-9]+) ([0-9]+)x([0-9]+)$'
  [[ "$1" =~ $re ]] || return 1
  printf '%s %s %s %s\n' "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}" "${BASH_REMATCH[4]}"
}

# The screen in front: its name, a tab, and where it is in the layout as "x,y WxH".
capture_focused_output() {
  niri msg -j focused-output 2>/dev/null |
    jq -r 'select(.name != null and .logical != null)
           | [.name, "\(.logical.x),\(.logical.y) \(.logical.width)x\(.logical.height)"] | @tsv' 2>/dev/null || true
}

# capture_spawn <log> <command...>: starts it on its own, out of this terminal's or the Core's reach; its pid in
# capture_pid. A background job of a script leads no process group, so setsid runs it in place: the pid is its own.
capture_spawn() {
  local log=$1; shift
  if command -v setsid >/dev/null; then setsid "$@" </dev/null >"$log" 2>&1 &
  else "$@" </dev/null >"$log" 2>&1 & fi
  capture_pid=$!
}

# capture_detach <seconds> <command...>: runs it that much later, on its own and not as a conversation, so a
# command the Core started can finish (and the Core close) before the work begins.
capture_detach() {
  local wait=$1; shift
  if command -v setsid >/dev/null; then
    TAKUMI_CORE="" setsid sh -c 'sleep "$1"; shift; exec "$@"' sh "$wait" "$@" </dev/null >/dev/null 2>&1 &
  else
    TAKUMI_CORE="" sh -c 'sleep "$1"; shift; exec "$@"' sh "$wait" "$@" </dev/null >/dev/null 2>&1 &
  fi
}

# capture_loudness <file>: the recording's sound brought to an even loudness, in place: EBU R128 at -16 LUFS,
# the level podcasts and video sites play at. It is measured first and then moved as one straight gain, so quiet
# and loud moments keep their difference. The picture is copied untouched. Leaves the file alone on any failure,
# and when there is nothing to measure (silence).
capture_loudness() {
  local f=$1 m i tp lra th off v tmp num='^-?[0-9]+(\.[0-9]+)?$'
  command -v ffmpeg >/dev/null || return 1
  m=$(ffmpeg -hide_banner -nostdin -i "$f" -map 0:a:0 -af loudnorm=I=-16:TP=-1.5:LRA=11:print_format=json -f null - 2>&1 |
      sed -n '/^{/,/^}/p') || return 1
  read -r i tp lra th off <<< "$(jq -r '[.input_i, .input_tp, .input_lra, .input_thresh, .target_offset] | map(tostring) | join(" ")' <<< "$m" 2>/dev/null)"
  for v in "$i" "$tp" "$lra" "$th" "$off"; do [[ "$v" =~ $num ]] || return 1; done
  tmp="${f%/*}/.${f##*/}.even.mp4"
  if ffmpeg -hide_banner -nostdin -loglevel error -y -i "$f" -map 0 -c copy -c:a aac -b:a 192k -ar 48000 \
       -af "loudnorm=I=-16:TP=-1.5:LRA=11:measured_I=$i:measured_TP=$tp:measured_LRA=$lra:measured_thresh=$th:offset=$off:linear=true" \
       -movflags +faststart "$tmp" </dev/null && [[ -s "$tmp" ]]; then
    mv -f "$tmp" "$f"
    return 0
  fi
  rm -f "$tmp"
  return 1
}

# The newest screenshot niri saved, leaving out marked-up copies; nothing when there is none.
capture_newest_shot() {
  local f newest=""
  for f in "$(capture_shots)"/*.png; do
    [[ -f "$f" && "$f" != *" marked.png" ]] || continue
    if [[ -z "$newest" || "$f" -nt "$newest" ]]; then newest=$f; fi
  done
  [[ -z "$newest" ]] || printf '%s\n' "$newest"
}

# capture_marked_name <picture>: where its marked-up copy goes: beside it, "<name> marked.png".
capture_marked_name() { printf '%s marked.png\n' "${1%.*}"; }

# capture_wait_shot <path or ""> <newest before> <seconds>: the screenshot niri is saving, once it is whole (the
# same size twice in a row). With a path, that file; without (a niri that takes no --path), any newer one.
capture_wait_shot() {
  local want=$1 before=$2 n=$(( $3 * 5 )) f size last=""
  while (( n > 0 )); do
    n=$((n - 1))
    if [[ -n "$want" ]]; then f=$want; else f=$(capture_newest_shot); [[ "$f" != "$before" ]] || f=""; fi
    if [[ -n "$f" && -s "$f" ]]; then
      size=$(wc -c < "$f" | tr -d ' ')
      [[ "$size" == "$last" ]] && { printf '%s\n' "$f"; return 0; }
      last=$size
    fi
    sleep 0.2
  done
  return 1
}

# capture_markup <picture>: opens it in satty to mark up. Enter or Esc keeps the work: the marked-up copy is
# saved beside the picture and copied, as are the toolbar's copy and save; closing the window leaves nothing.
# Prints the copy's path when one was saved; returns 1 when nothing was.
capture_markup() {
  local in=$1 out before after
  out=$(capture_marked_name "$in")
  before=none; [[ -f "$out" ]] && before=$(cksum < "$out")
  # satty reads its output name as a date pattern: a % in a file name is written %%.
  satty --filename "$in" --output-filename "$(printf '%s' "$out" | sed 's/%/%%/g')" \
    --copy-command wl-copy --save-after-copy --early-exit all \
    --actions-on-enter save-to-clipboard,save-to-file,exit \
    --actions-on-escape save-to-clipboard,save-to-file,exit \
    --initial-tool arrow --disable-notifications </dev/null >/dev/null 2>&1 || true
  [[ -s "$out" ]] || return 1
  after=$(cksum < "$out")
  [[ "$after" != "$before" ]] || return 1
  printf '%s\n' "$out"
}
