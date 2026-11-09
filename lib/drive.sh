#!/usr/bin/env bash
# USB drives and memory cards, through udisks2. Sourced by commands/drive/* and the Palette's drive rows;
# runs on bash 3.2 (the tests use a fake udisksctl on macOS). See docs/drives.md.
#
# udisksctl dump describes every disk udisks knows. One awk pass turns it into one line per volume, fields
# split by the unit separator ($drive_sep) so an empty one keeps its place:
#    1 device    /dev/sdb1                 9 drive      udisks' object for the drive
#    2 usage     filesystem, crypto, none  10 whole     /dev/sdb, the drive as a whole
#    3 type      vfat, exfat, ext4, ...    11 size      the volume, in bytes
#    4 label     what it is called         12 removable yes for a USB drive or a card (udisks' HintAuto)
#    5 mount     where it is open          13 poweroff  yes when udisks can power the drive off
#    6 state     open, closed, locked,     14 other     an encrypted part's open contents, or the
#                unlocked, blank                        encrypted part that open contents belong to
#    7 name      "SanDisk 64 GB"           15 dname     the drive's own name, "SanDisk 64 GB"
#    8 short     "SanDisk", "the SD card"  16 wsize     the drive's size, in bytes
# A drive with several parts names each "<label> on SanDisk 64 GB". A drive with nothing to open (blank, or
# in a format udisks does not know) has one line, state blank, for the whole drive, so it can be erased.

drive_sep=$'\037'
drive_run="${XDG_RUNTIME_DIR:-$HOME/.local/state/takumi}"
drive_open_list="$drive_run/takumi-drives-open"   # "<device><sep><name>" per volume the watch saw open

drive_volumes() { { LC_ALL=C udisksctl dump 2>/dev/null || true; } | drive_parse; }

drive_parse() {
  awk -v S="$drive_sep" -v Q="'" '
    function flush() {
      if (obj == "") return
      if ("Block.Device" in p) {
        nb++; bp[nb] = obj; dev[obj] = p["Block.Device"]; use[obj] = p["Block.IdUsage"]; typ[obj] = p["Block.IdType"]
        lab[obj] = p["Block.IdLabel"]; auto[obj] = p["Block.HintAuto"]; sys[obj] = p["Block.HintSystem"]
        ign[obj] = p["Block.HintIgnore"]; drv[obj] = p["Block.Drive"]; size[obj] = p["Block.Size"]
        back[obj] = p["Block.CryptoBackingDevice"]; mnt[obj] = p["Filesystem.MountPoints"]
        table[obj] = p["Partition.Table"]; part[obj] = p["Partition.Number"]; clear[obj] = p["Encrypted.CleartextDevice"]
      }
      if ("Drive.Size" in p) {
        vendor[obj] = p["Drive.Vendor"]; model[obj] = p["Drive.Model"]; media[obj] = p["Drive.Media"]
        bus[obj] = p["Drive.ConnectionBus"]; off[obj] = p["Drive.CanPowerOff"]; dsize[obj] = p["Drive.Size"]
      }
      split("", p); obj = ""
    }
    function set(path) { return path != "" && path != "/" }
    # The drive a block belongs to: its own, or for the open contents of an encrypted part, the drive of the part.
    function drive_of(b) { if (set(drv[b])) return drv[b]; if (set(back[b]) && set(drv[back[b]])) return drv[back[b]]; return "" }
    function hint_of(b) { return set(back[b]) ? back[b] : b }
    function whole_of(b) { b = hint_of(b); return set(table[b]) ? dev[table[b]] : dev[b] }
    # A brand worth showing, or nothing for the words cheap drives and card readers give ("Generic",
    # "Mass", "STORAGE DEVICE", "Flash Disk", a bare number).
    function pretty(v,   l) {
      gsub(/^[ \t]+|[ \t]+$/, "", v); l = tolower(v)
      if (v == "" || l ~ /^(usb|mass|general|multiple|flash|disk|unknown|vendor|ut[0-9]+)$/) return ""
      if (l ~ /(generic|storage|flash disk|flash drive|card ?reader|sd\/mmc|multi-?card)/) return ""
      if (v ~ /^[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]$/) return ""
      if (v ~ /^[A-Z][A-Z0-9]+$/ && length(v) > 3) v = substr(v, 1, 1) tolower(substr(v, 2))
      return v
    }
    function kind(d) {
      if (media[d] ~ /^flash_(sd|sdhc|sdxc|mmc)/ || bus[d] == "sdio") return "SD card"
      if (media[d] ~ /^flash/) return "memory card"
      if (media[d] == "thumb" || bus[d] == "usb") return "USB drive"
      return "drive"
    }
    function dec(x) { return (x < 10) ? sprintf("%.1f", x) : sprintf("%d", x + 0.5) }
    # The size printed on the drive: a 64 GB stick holds 61.5 billion bytes. Else decimal, as a Mac says it.
    function nominal(b,   n, i, s, g, t) {
      n = split("1 2 4 8 16 32 64 120 128 240 250 256 320 480 500 512 640 750 960", g, " ")
      for (i = 1; i <= n; i++) { s = g[i] * 1000000000; if (b <= s * 1.01 && b >= s * 0.9) return g[i] " GB" }
      n = split("1 1.5 2 3 4 5 6 8 10 12 14 16 18 20 22 24", t, " ")
      for (i = 1; i <= n; i++) { s = t[i] * 1000000000000; if (b <= s * 1.01 && b >= s * 0.9) return t[i] " TB" }
      if (b >= 1000000000000) return dec(b / 1000000000000) " TB"
      if (b >= 1000000000) return dec(b / 1000000000) " GB"
      return dec(b / 1000000) " MB"
    }
    function line(b, d, u, st, name, other, h) {
      h = hint_of(b)
      print dev[b] S u S typ[b] S lab[b] S mnt[b] S st S name S dshort[d] S d S whole_of(b) S size[b] S \
        ((auto[h] == "true" && sys[h] != "true" && ign[h] != "true") ? "yes" : "no") S (off[d] == "true" ? "yes" : "no") S \
        other S dname[d] S dsize[d]
    }
    /^\/org\/freedesktop\/UDisks2\// { flush(); obj = $0; sub(/:[ \t]*$/, "", obj); iface = ""; next }
    /^  org\.freedesktop\.UDisks2\.[A-Za-z.]+:[ \t]*$/ { iface = $1; sub(/^org\.freedesktop\.UDisks2\./, "", iface); sub(/:$/, "", iface); next }
    /^    [A-Za-z0-9]+:/ {
      key = $1; sub(/:$/, "", key); v = $0; sub(/^    [A-Za-z0-9]+:[ \t]*/, "", v); sub(/[ \t]+$/, "", v)
      if (length(v) >= 2 && substr(v, 1, 1) == Q && substr(v, length(v), 1) == Q) v = substr(v, 2, length(v) - 2)   # an object path
      if (iface != "") p[iface "." key] = v
      next }
    END {
      flush()
      for (d in dsize) {
        vd = pretty(vendor[d]); if (vd == "") { vd = pretty(model[d]); sub(/ *[0-9.]+ ?[GT]B$/, "", vd) }
        dname[d] = (vd != "" ? vd : kind(d)) " " nominal(dsize[d] + 0)
        dshort[d] = (vd != "" ? vd : "the " kind(d))
      }
      for (i = 1; i <= nb; i++) {
        b = bp[i]; u = use[b]
        if (u != "filesystem" && u != "crypto") continue
        d = drive_of(b); if (d == "") continue
        if (u == "crypto" && set(clear[b])) continue   # its open contents are the volume
        count[d]++
      }
      for (i = 1; i <= nb; i++) {
        b = bp[i]; u = use[b]; d = drive_of(b)
        if (d == "") continue
        if (u == "filesystem" || u == "crypto") {
          if (u == "crypto") { st = set(clear[b]) ? "unlocked" : "locked"; other = set(clear[b]) ? dev[clear[b]] : "" }
          else { st = (mnt[b] != "") ? "open" : "closed"; other = set(back[b]) ? dev[back[b]] : "" }
          name = dname[d]
          if (count[d] > 1) name = (lab[b] != "" ? lab[b] : "Part " part[hint_of(b)]) " on " dname[d]
          line(b, d, u, st, name, other)
        } else if (!set(table[b]) && count[d] == 0 && size[b] + 0 > 0 && !(d in blank)) {   # a card reader with no card: nothing
          blank[d] = 1; line(b, d, "none", "blank", dname[d], "")
        }
      }
    }' | LC_ALL=C sort
}

# drive_read <line>: sets d_dev d_usage d_type d_label d_mount d_state d_name d_short d_drive d_whole d_size
# d_removable d_poweroff d_other d_dname d_wsize from one of drive_volumes' lines.
drive_read() {
  IFS="$drive_sep" read -r d_dev d_usage d_type d_label d_mount d_state d_name d_short d_drive d_whole d_size \
    d_removable d_poweroff d_other d_dname d_wsize <<< "$1"
}

# drive_find <name>: the lines of the removable volumes a person means: a device (/dev/sdb1 or sdb1), the
# drive's device (sdb), a label, a name ("SanDisk 64 GB") or the brand ("SanDisk"), in any case.
drive_find() {
  local want; want=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  drive_volumes | awk -F "$drive_sep" -v w="$want" '
    $12 != "yes" { next }
    { dev = tolower($1); whole = tolower($10); short = tolower($8); sub(/^the /, "", short) }
    dev == w || dev == "/dev/" w || whole == w || whole == "/dev/" w || tolower($4) == w || tolower($7) == w || tolower($15) == w || short == w || tolower($8) == w'
}

# drive_human <bytes>: "41 GB", "7.3 GB", "800 MB", decimal, as a Mac says it.
drive_human() {
  awk -v b="${1:-0}" 'function dec(x) { return (x < 10) ? sprintf("%.1f", x) : sprintf("%d", x + 0.5) }
    BEGIN { if (b >= 1e12) print dec(b / 1e12) " TB"; else if (b >= 1e9) print dec(b / 1e9) " GB"; else if (b >= 1e6) print dec(b / 1e6) " MB"; else print dec(b / 1e3) " kB" }'
}

# drive_free <mount point>: bytes free there, or nothing.
drive_free() { { df -Pk "$1" 2>/dev/null || true; } | awk 'NR == 2 { printf "%.0f\n", $4 * 1024 }'; }

# drive_mount <device> [--quiet]: opens it as you (udisks mounts it at /run/media/<you>/<label>) and prints
# where. --quiet never asks for a password (the watch); otherwise polkit may, in the Core. On failure it
# prints udisks' words. Opened already, by Files or by the watch, is fine.
drive_mount() {
  local out rc=0 args=(mount -b "$1")
  [[ "${2:-}" == --quiet ]] && args+=(--no-user-interaction)
  out=$(LC_ALL=C udisksctl "${args[@]}" 2>&1) || rc=$?
  if (( rc != 0 )); then
    case "$out" in *AlreadyMounted*|*"already mounted"*) ;; *) printf '%s\n' "$out"; return 1 ;; esac
  fi
  drive_volumes | awk -F "$drive_sep" -v d="$1" '$1 == d && $5 != "" { print $5; exit }'
}

# drive_why <udisks words> <type>: why a drive did not open, for a sentence.
drive_why() {
  case "$2" in
    apfs) echo "it is formatted for a Mac (APFS), which Takumi cannot read"; return ;;
    hfsplus) echo "it is formatted for an older Mac (HFS+), which Takumi cannot open" ; return ;;
  esac
  case "$1" in
    *NotAuthorized*|*"ot authorized"*) echo "it needs your password: open it from the Core" ;;
    *"unknown filesystem"*|*"wrong fs type"*|*"bad superblock"*|*"ot supported"*) echo "Takumi cannot read the way it is formatted" ;;
    *"ead-only"*) echo "it is locked against writing" ;;
    *) echo "udisks said: $(printf '%s\n' "$1" | sed '/^[[:space:]]*$/d' | tail -n 1 | sed 's/^Error [a-z]* [^:]*: //')" ;;
  esac
}

# drive_forget <device>: off the watch's list of open volumes, so taking it out says nothing.
drive_forget() {
  [[ -f "$drive_open_list" ]] || return 0
  awk -F "$drive_sep" -v d="$1" '$1 != d' "$drive_open_list" > "$drive_open_list.tmp" && mv -f "$drive_open_list.tmp" "$drive_open_list"
}

# drive_devname <udisks object name>: the device it stands for: block_devices/dm_2d0 is /dev/dm-0.
drive_devname() { printf '/dev/%b' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/_\([0-9a-f][0-9a-f]\)/\\x\1/g')"; }

# drive_release <whole drive>: closes every open part of it and locks its unlocked encrypted parts, so nothing
# writes to it but us. Prints why in words and fails when something still uses it.
drive_release() {
  local all v out
  all=$(drive_volumes | awk -F "$drive_sep" -v w="$1" '$10 == w')
  while IFS= read -r -u 3 v; do
    [[ -n "$v" ]] || continue
    drive_read "$v"
    [[ $d_state == open ]] || continue
    if ! out=$(LC_ALL=C udisksctl unmount -b "$d_dev" 2>&1); then
      case "$out" in
        *[Bb]usy*) echo "Something is still using $d_dname. Close what is open from it, then try again"; return 1 ;;
        *NotMounted*|*"not mounted"*) ;;
        *) echo "$d_dname could not be closed: $(drive_why "$out" "$d_type")"; return 1 ;;
      esac
    fi
    drive_forget "$d_dev"
  done 3<<< "$all"
  while IFS= read -r -u 3 v; do
    [[ -n "$v" ]] || continue
    drive_read "$v"
    [[ $d_state == unlocked ]] || continue
    LC_ALL=C udisksctl lock -b "$d_dev" >/dev/null 2>&1 || { echo "$d_dname could not be locked"; return 1; }
  done 3<<< "$all"
  return 0
}

# drive_removables: one line per USB drive or memory card plugged in, the whole drive: device <TAB> name
# ("SanDisk 64 GB") <TAB> short ("SanDisk", "the SD card") <TAB> size in bytes. A drive is listed only when every
# part of it is removable and none is open where the system lives, the rule takumi drive format keeps too.
drive_removables() {
  drive_volumes | awk -F "$drive_sep" '
    { w = $10; if (!(w in seen)) { seen[w] = 1; order[++n] = w; name[w] = $15; short[w] = $8; size[w] = $16 }
      if ($12 != "yes" || $5 ~ /^\/(boot|boot\/efi|efi|home|usr|var|srv|opt)?$/) bad[w] = 1 }
    END { for (i = 1; i <= n; i++) if (!(order[i] in bad)) print order[i] "\t" name[order[i]] "\t" short[order[i]] "\t" size[order[i]] }'
}

# drive_system_disks: the whole disks this computer runs from (what holds /, /boot, /efi and /home), one device
# per line, from lsblk's view upwards through encryption and partitions. Nothing writes an image to these.
drive_system_disks() {
  command -v lsblk >/dev/null && command -v findmnt >/dev/null || return 0
  local m src
  for m in / /boot /efi /boot/efi /home; do
    src=$(findmnt -nvo SOURCE "$m" 2>/dev/null | head -n 1) || continue
    [[ "$src" == /dev/* ]] || continue
    lsblk -nsro NAME,TYPE "$src" 2>/dev/null | awk '$2 == "disk" { print "/dev/" $1 }'
  done | LC_ALL=C sort -u
}

# --- Disk images, for takumi drive write ---

drive_image_re='\.(img|iso|raw)(\.(xz|zst|gz))?$'
drive_is_image() { local l; l=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]'); [[ "$l" =~ $drive_image_re ]]; }
# drive_image_size <file>: the bytes it writes, uncompressed; nothing when the file does not say (gzip over 4 GB).
drive_image_size() {
  local l; l=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$l" in
    *.xz) xz --robot --list "$1" 2>/dev/null | awk -F '\t' '$1 == "totals" { print $5; exit }' ;;
    *.zst) zstd -lv "$1" 2>/dev/null | sed -n 's/.*Decompressed Size:.*(\([0-9]*\) B).*/\1/p' | head -n 1 ;;
    *.gz) ;;
    *) wc -c < "$1" 2>/dev/null | tr -d ' ' ;;
  esac
  return 0
}
# drive_image_cat <file>: the image's bytes on stdout, decompressed as they go.
drive_image_cat() {
  local l; l=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
  case "$l" in
    *.xz) xz -dc -- "$1" ;;
    *.zst) zstd -dcq -- "$1" ;;
    *.gz) gzip -dc -- "$1" ;;
    *) cat -- "$1" ;;
  esac
}

# --- Health, through smartctl (smartmontools) ---

# drive_health_words: smartctl -j -a's objects on stdin, one line each out: device <TAB> name <TAB> verdict
# (healthy, worn, failing, unknown) <TAB> the line people read ("Samsung SSD 980 1TB · Healthy · 2% worn · 1,200 hours").
# Failing: SMART's own verdict, an NVMe critical warning, or sectors the disk had to move or cannot read. Worn: 90% of
# its rated writes used, or spare blocks under the maker's line. Worn is NVMe's percentage_used, else ATA's endurance
# indicator, else one of the SSD wear attributes (177, 231, 233); a spinning disk has none.
drive_health_words() {
  jq -r '
    def commas: if . >= 1000 then ((. / 1000 | floor) | commas) + "," + ("00" + ((. % 1000) | tostring))[-3:] else tostring end;
    . as $d
    | def attr($i): [($d.ata_smart_attributes.table // [])[] | select(.id == $i)][0];
    ($d.device.name // "") as $dev
    | ([$d.model_name, $d.model_family, $dev] | map(select(. != null and . != "")) | first // "A disk") as $name
    | ($d.nvme_smart_health_information_log // null) as $nv
    | (if $nv != null then $nv.percentage_used
       else ([($d.ata_device_statistics.pages // [])[] | (.table // [])[] | select(.name == "Percentage Used Endurance Indicator") | .value][0]
             // (if ($d.rotation_rate // 1) == 0 then ([attr(177), attr(231), attr(233)] | map(select(. != null)) | first | if . then 100 - .value else null end) else null end))
       end) as $worn
    | ($d.power_on_time.hours // null) as $hours
    | (if ($d.smart_status.passed // null) == null and $nv == null then "unknown"
       elif ($d.smart_status.passed // true) == false then "failing"
       elif $nv != null and (($nv.critical_warning // 0) > 0 or ($nv.media_errors // 0) > 0) then "failing"
       elif ([5, 197, 198] | map(attr(.) | .raw.value // 0) | add) > 0 then "failing"
       elif ($worn // 0) >= 90 then "worn"
       elif $nv != null and ($nv.available_spare // 100) < ($nv.available_spare_threshold // 0) then "worn"
       else "healthy" end) as $v
    | [$dev, $name, $v,
       ([$name,
         ({"healthy": "Healthy", "worn": "Wearing out: replace it soon", "failing": "Failing: copy what matters off it now",
           "unknown": "Does not report its health"}[$v]),
         (if $worn != null and $v != "unknown" then ($worn | tostring) + "% worn" else empty end),
         (if $hours != null and $v != "unknown" then ($hours | commas) + " hours" else empty end)] | join(" · "))]
    | @tsv'
}

# --- Clouds as folders, through rclone mount ---

# The clouds Takumi puts in the home folder: id|rclone type|name|settings. Google Drive gets the whole drive
# (scope=drive), unlike a backup, which sees only its own files. The remote is takumi-<id>, the folder ~/<name>.
drive_clouds() { printf '%s\n' "onedrive|onedrive|OneDrive|" "google|drive|Google Drive|scope=drive" "dropbox|dropbox|Dropbox|"; }
# drive_cloud <word>: the cloud a person means ("google", "Google Drive", "gdrive", "one drive"), as its line.
drive_cloud() {
  local w; w=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]' | tr -d ' _-')
  case "$w" in googledrive|gdrive) w=google ;; ms*onedrive|microsoftonedrive) w=onedrive ;; esac
  drive_clouds | awk -F'|' -v w="$w" '$1 == w { print; f = 1 } END { exit !f }'
}
drive_cloud_folder() { printf '%s/%s' "$HOME" "$1"; }                        # <name>
drive_cloud_cache() { printf '%s/takumi/cloud/%s' "${XDG_CACHE_HOME:-$HOME/.cache}" "$1"; }   # <id>
drive_cloud_unit() { printf 'takumi-cloud@%s.service' "$1"; }               # <id>
drive_bookmarks="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0/bookmarks"       # Files' sidebar
# drive_mounted <folder>: true when something is mounted there (/proc/self/mountinfo; findmnt when it is there).
drive_mounted() {
  if command -v mountpoint >/dev/null; then mountpoint -q "$1" 2>/dev/null; return; fi
  awk -v p="$1" '$5 == p { f = 1 } END { exit !f }' /proc/self/mountinfo 2>/dev/null
}
# drive_url <path>: a file:// address, spaces and other bytes Files would escape written as %XX.
drive_url() {
  printf 'file://'
  LC_ALL=C awk -v s="$1" 'BEGIN { for (i = 0; i < 256; i++) ord[sprintf("%c", i)] = i
    for (i = 1; i <= length(s); i++) { c = substr(s, i, 1)
      if (c ~ /[A-Za-z0-9\/._~-]/) printf "%s", c; else printf "%%%02X", ord[c] } }'
}
drive_bookmark_add() {  # <folder> <label>
  local u; u=$(drive_url "$1")
  mkdir -p "$(dirname "$drive_bookmarks")"; touch "$drive_bookmarks"
  awk -v u="$u" '$1 == u { f = 1 } END { exit !f }' "$drive_bookmarks" || printf '%s %s\n' "$u" "$2" >> "$drive_bookmarks"
}
drive_bookmark_remove() {  # <folder>
  local u; u=$(drive_url "$1")
  [[ -f "$drive_bookmarks" ]] || return 0
  awk -v u="$u" '$1 != u' "$drive_bookmarks" > "$drive_bookmarks.tmp" && mv -f "$drive_bookmarks.tmp" "$drive_bookmarks"
}
