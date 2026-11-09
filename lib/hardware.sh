#!/usr/bin/env bash
# This computer's hardware: what is in it, the fixes Takumi has for it (default/hardware/*.toml), and what was
# set up in each room (/var/lib/takumi/hardware.json). Sourced by commands/hardware/*, the Palette's hardware
# rows and takumi doctor; runs on bash 3.2 with jq. See docs/hardware.md.
#
# Every place it reads can be pointed elsewhere, which is how the tests fake a computer:
#   TAKUMI_HW_DATA        the fixes (default /usr/share/takumi/default/hardware, then the checkout's)
#   TAKUMI_HW_LSPCI       a file of `lspci -vmm -nn -k` output, read instead of running lspci
#   TAKUMI_HW_LSUSB       a file of `lsusb` output, read instead of running lsusb
#   TAKUMI_HW_SYS         sysfs (default /sys): DMI, Bluetooth, cameras, and PCI and USB when lspci or lsusb is missing
#   TAKUMI_HW_CPUINFO     /proc/cpuinfo            TAKUMI_HW_MEMINFO   /proc/meminfo
#   TAKUMI_HW_DT          /proc/device-tree/compatible
#   TAKUMI_HW_ASOUND      /proc/asound             TAKUMI_HW_ARCH      uname -m
#   TAKUMI_HW_KERNEL_LOG  a file of this start's kernel messages (default: journalctl -k, then dmesg)
#   TAKUMI_HW_FIRMWARE    /usr/lib/firmware        TAKUMI_HW_RECORD    /var/lib/takumi/hardware.json
#   TAKUMI_HW_ROOM        the room this system is (default: read from findmnt)

hw_lib_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
hw_tab=$(printf '\t')

# hw_data_dir [dir]: the folder of fixes. A folder named on the command line is the only one looked at.
hw_data_dir() {
  if [[ -n "${1:-}" ]]; then [[ -d "$1" ]] && { (cd "$1" && pwd); return 0; }; return 1; fi
  local d
  for d in "${TAKUMI_HW_DATA:-}" /usr/share/takumi/default/hardware "$hw_lib_dir/../default/hardware"; do
    [[ -n "$d" && -d "$d" ]] && { (cd "$d" && pwd); return 0; }
  done
  return 1
}

# The fixes are a small part of TOML: comments, `key = value` (a "string", a 'literal string', true, false, a
# whole number, or [an, array] over as many lines as it likes) and [tables]. One jq program reads them.
read -r -d '' hw_jq_toml <<'JQ' || true
def hw_value($t):
  if $t.k == "bs" then ($t.v | fromjson)
  elif $t.k == "ls" then $t.v[1:-1]
  elif $t.v == "true" then true
  elif $t.v == "false" then false
  elif ($t.v | test("^-?[0-9]+$")) then ($t.v | tonumber)
  else error("\($t.v) is not a value") end;
def hw_put($v): if .table == null then .out[.key] = $v else .out[.table][.key] = $v end;
def toml:
  [match("(?<ws>[ \\t\\r\\n]+)|(?<comment>#[^\\n]*)|(?<bs>\\x22(?:[^\\x22\\x5c\\n]|\\x5c.)*\\x22)|(?<ls>\\x27[^\\x27\\n]*\\x27)|(?<lb>\\[)|(?<rb>\\])|(?<comma>,)|(?<eq>=)|(?<word>[A-Za-z0-9_.+-]+)|(?<bad>.)"; "g")
   | first(.captures[] | select(.string != null)) | {k: .name, v: .string} | select(.k != "ws" and .k != "comment")]
  | reduce .[] as $t ({out: {}, table: null, key: null, arr: null, want: "key"};
      if .want == "key" then
        if $t.k == "lb" then .want = "table"
        elif $t.k == "word" then .key = $t.v | .want = "eq"
        else error("unexpected \($t.v)") end
      elif .want == "table" then
        if $t.k == "word" then .table = $t.v | .want = "close" else error("a table needs a name") end
      elif .want == "close" then
        if $t.k == "rb" then .want = "key" else error("no ] after [\(.table)") end
      elif .want == "eq" then
        if $t.k == "eq" then .want = "value" else error("no = after \(.key)") end
      elif .want == "value" then
        if $t.k == "lb" then .arr = [] | .want = "item"
        else hw_value($t) as $v | hw_put($v) | .want = "key" end
      elif $t.k == "rb" then .arr as $a | hw_put($a) | .arr = null | .want = "key"
      elif $t.k == "comma" then .
      else .arr += [hw_value($t)] end)
  | if .want != "key" then error("\(.key) has no value") else .out end;
JQ

# hw_fixes <dir>: every fix, one JSON object per line, by name: {id, file, title, part, works, says, driver, keep,
# match, apply, extra (top-level keys Takumi does not know)}, or {id, file, error} for a file it cannot read. All
# the files go through one jq, each behind an ASCII record separator.
hw_fixes() {
  local f
  for f in "$1"/*.toml; do
    [[ -f "$f" ]] || continue
    printf '\036%s\n' "$f"; cat "$f"; printf '\n'
  done | jq -Rsc "$hw_jq_toml"'
    [split("\u001e") | .[1:][] | index("\n") as $i | .[:$i] as $file | .[$i + 1:] as $text
    | ($file | sub(".*/"; "") | sub("[.]toml$"; "")) as $id
    | (try ($text | toml) catch {"_error": .}) as $t
    | if ($t | has("_error")) then {id: $id, file: $file, error: $t._error}
      else {id: $id, file: $file, title: ($t.title // $id), part: ($t.part // "other"), works: ($t.works // "yes"),
            says: ($t.says // ""), driver: ($t.driver // ""), keep: ($t.keep // false), match: ($t.match // {}),
            apply: ($t.apply // {}), extra: ($t | del(.title, .part, .works, .says, .driver, .keep, .match, .apply) | keys)} end]
    | sort_by(.id)[]'
}

# hw_pci: one JSON object per PCI device: {slot, class, vendor, device, svendor, sdevice, vname, dname, sname, driver}.
# From lspci, which knows the names; from sysfs, with ids only, when lspci is not installed.
hw_pci() {
  local out sys=${TAKUMI_HW_SYS:-/sys} d c drv
  if [[ -n "${TAKUMI_HW_LSPCI:-}" ]]; then out=$(cat "$TAKUMI_HW_LSPCI" 2>/dev/null || true)
  elif command -v lspci >/dev/null; then out=$(LC_ALL=C lspci -vmm -nn -k 2>/dev/null || true)
  else
    for d in "$sys"/bus/pci/devices/*; do
      [[ -r "$d/vendor" && -r "$d/class" ]] || continue
      c=$(cat "$d/class"); drv=""
      [[ -e "$d/driver" ]] && drv=$(basename "$(readlink "$d/driver")")
      printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "${d##*/}" "$c" "$(cat "$d/vendor")" "$(cat "$d/device")" \
        "$(cat "$d/subsystem_vendor" 2>/dev/null || echo 0x0000)" "$(cat "$d/subsystem_device" 2>/dev/null || echo 0x0000)" "$drv"
    done | jq -Rc 'split("\t") | map(ltrimstr("0x")) | {slot: (.[0] | sub("^0000:"; "")), class: .[1][0:4], vendor: .[2], device: .[3],
      svendor: .[4], sdevice: .[5], vname: "", dname: "", sname: "", driver: .[6]}'
    return 0
  fi
  printf '%s\n' "$out" | jq -Rsc '
    def id($s): ($s | capture(" \\[(?<i>[0-9a-fA-F]{4})\\]$").i // "") | ascii_downcase;
    def nm($s): $s | sub(" \\[[0-9a-fA-F]{4}\\]$"; "") | if test("^Device$|^Device [0-9a-f]{4}$") then "" else . end;
    split("\n\n")[] | select(test("(^|\n)Slot:\t"))
    | [split("\n")[] | select(test("^[A-Za-z]+:\t")) | capture("^(?<k>[A-Za-z]+):\t(?<v>.*)$")] as $kv
    | def get($k): (first($kv[] | select(.k == $k) | .v) // "");
      {slot: get("Slot"), class: id(get("Class")), vendor: id(get("Vendor")), device: id(get("Device")), svendor: id(get("SVendor")),
       sdevice: id(get("SDevice")), vname: nm(get("Vendor")), dname: nm(get("Device")), sname: nm(get("SDevice")), driver: get("Driver")}'
}

# hw_usb: one JSON object per USB device: {id, name}. From lsusb, else from sysfs.
hw_usb() {
  local out sys=${TAKUMI_HW_SYS:-/sys} d
  if [[ -n "${TAKUMI_HW_LSUSB:-}" ]]; then out=$(cat "$TAKUMI_HW_LSUSB" 2>/dev/null || true)
  elif command -v lsusb >/dev/null; then out=$(LC_ALL=C lsusb 2>/dev/null || true)
  else
    for d in "$sys"/bus/usb/devices/*; do
      [[ -r "$d/idVendor" && -r "$d/idProduct" ]] || continue
      printf 'Bus 000 Device 000: ID %s:%s %s %s\n' "$(cat "$d/idVendor")" "$(cat "$d/idProduct")" \
        "$(cat "$d/manufacturer" 2>/dev/null || true)" "$(cat "$d/product" 2>/dev/null || true)"
    done | hw_usb_parse
    return 0
  fi
  printf '%s\n' "$out" | hw_usb_parse
}
hw_usb_parse() { jq -Rc 'capture("ID (?<id>[0-9a-fA-F]{4}:[0-9a-fA-F]{4}) ?(?<name>.*)$") | {id: (.id | ascii_downcase), name: (.name | sub(" +$"; ""))}'; }

# hw_kernel_log: this start's kernel messages, without timestamps.
hw_kernel_log() {
  if [[ -n "${TAKUMI_HW_KERNEL_LOG:-}" ]]; then cat "$TAKUMI_HW_KERNEL_LOG" 2>/dev/null || true; return 0; fi
  local out=""
  if command -v journalctl >/dev/null; then out=$(LC_ALL=C journalctl -k -b -o cat --no-pager -q 2>/dev/null || true); fi
  if [[ -z "$out" ]] && command -v dmesg >/dev/null; then out=$(LC_ALL=C dmesg 2>/dev/null | sed 's/^\[[^]]*\] *//' || true); fi
  printf '%s\n' "$out"
}

# hw_facts [log]: what this computer is, as one JSON object: arch, laptop, virtual, dmi, cpu, memory_kb, pci,
# usb, dt (device-tree names), bluetooth, cameras, codecs; and with "log", the kernel's messages.
hw_facts() {
  local sys=${TAKUMI_HW_SYS:-/sys} k p dmi cpu mem dt bt cams codecs pci usb arch name card
  dmi=$(for k in sys_vendor product_name product_family product_version board_vendor board_name chassis_type bios_vendor bios_version; do
          printf '%s\t%s\n' "$k" "$(head -n 1 "$sys/class/dmi/id/$k" 2>/dev/null || true)"; done |
        jq -Rsc 'split("\n") | map(select(length > 0) | split("\t") | {(.[0]): (.[1] // "" | sub(" +$"; ""))}) | add // {}')
  cpu='{}'
  if [[ -r "${TAKUMI_HW_CPUINFO:-/proc/cpuinfo}" ]]; then
    cpu=$(awk -F': *' '
      /^vendor_id/ && v == "" { v = $2 } /^cpu family/ && fam == "" { fam = $2 } /^model[ \t]*:/ && mod == "" { mod = $2 }
      /^model name/ && nm == "" { nm = $2 } /^flags/ && fl == "" { fl = $2 } /^processor/ { n++ } /^cpu cores/ && co == "" { co = $2 }
      END { printf "%s\t%s\t%s\t%s\t%d\t%s\t%s\n", v, fam, mod, nm, n, co, (fl ~ /(^| )hypervisor( |$)/) ? "yes" : "no" }' "${TAKUMI_HW_CPUINFO:-/proc/cpuinfo}" |
      jq -Rc 'split("\t") | {vendor: .[0], family: (.[1] | tonumber? // null), model: (.[2] | tonumber? // null), name: .[3],
        threads: (.[4] | tonumber? // 0), cores: (.[5] | tonumber? // 0), hypervisor: (.[6] == "yes")}')
  fi
  mem=$(awk '/^MemTotal:/ { print $2; exit }' "${TAKUMI_HW_MEMINFO:-/proc/meminfo}" 2>/dev/null || true)
  dt='[]'
  [[ -r "${TAKUMI_HW_DT:-/proc/device-tree/compatible}" ]] && dt=$(tr '\0' '\n' < "${TAKUMI_HW_DT:-/proc/device-tree/compatible}" | jq -Rsc 'split("\n") | map(select(length > 0))')
  # Bluetooth adapters and USB cameras, named by the USB device they belong to.
  bt=$(for p in "$sys"/class/bluetooth/hci*; do
         [[ -e "$p" ]] || continue
         k=$(readlink -f "$p/device" 2>/dev/null || true); name="" vid=""
         if [[ -n "$k" ]]; then
           name=$(cat "$(dirname "$k")/product" 2>/dev/null || cat "$k/product" 2>/dev/null || true)
           vid=$(cat "$(dirname "$k")/idVendor" 2>/dev/null || true)
         fi
         printf '%s\t%s\t%s\n' "${p##*/}" "$name" "$vid"
       done | jq -Rsc 'split("\n") | map(select(length > 0) | split("\t") | {hci: .[0], name: (.[1] // ""), vendor: (.[2] // "")})')
  cams=$(for p in "$sys"/class/video4linux/video*; do
           [[ -e "$p" ]] || continue
           k=$(readlink -f "$p/device" 2>/dev/null || true); k=$(dirname "${k:-/}")
           [[ -r "$k/idVendor" ]] || continue
           printf '%s:%s\t%s\n' "$(cat "$k/idVendor")" "$(cat "$k/idProduct" 2>/dev/null || true)" "$(cat "$k/product" 2>/dev/null || true)"
         done | sort -u | jq -Rsc 'split("\n") | map(select(length > 0) | split("\t") | {id: .[0], name: (.[1] // "")})')
  # The sound chip's own name (Realtek ALC287) beats the controller's; HDMI codecs are the screens' sound.
  codecs=$(for card in "${TAKUMI_HW_ASOUND:-/proc/asound}"/card*; do
             for p in "$card"/codec#*; do [[ -r "$p" ]] && sed -n '1s/^Codec: //p' "$p"; done
           done 2>/dev/null | { grep -viE 'hdmi|display' || true; } | jq -Rsc 'split("\n") | map(select(length > 0))')
  pci=$(hw_pci | jq -sc .); usb=$(hw_usb | jq -sc .)
  arch=${TAKUMI_HW_ARCH:-$(uname -m)}
  { if [[ "${1:-}" == log ]]; then hw_kernel_log; fi; } | jq -Rsc --argjson dmi "$dmi" --argjson cpu "$cpu" --arg mem "${mem:-0}" --argjson dt "$dt" \
    --argjson bt "$bt" --argjson cams "$cams" --argjson codecs "$codecs" --argjson pci "$pci" --argjson usb "$usb" --arg arch "$arch" --arg log "${1:-}" '
    {arch: $arch, dmi: $dmi, cpu: $cpu, memory_kb: ($mem | tonumber? // 0), pci: $pci, usb: $usb, dt: $dt, bluetooth: $bt, cameras: $cams, codecs: $codecs,
     laptop: (($dmi.chassis_type // "") | IN("8", "9", "10", "11", "14", "30", "31", "32")),
     virtual: (($cpu.hypervisor // false) or ((($dmi.sys_vendor // "") + " " + ($dmi.product_name // "")) | test("QEMU|VMware|VirtualBox|innotek|Xen|Parallels|Bochs|KVM|Virtual Machine"; "i")))}
    + (if $log == "log" then {log: (split("\n") | map(select(length > 0)))} else {} end)'
}

# Which fixes apply to a computer: every key of a fix's [match] must hold (pci and pci_class together, about one
# device), and within a key any one value is enough.
read -r -d '' hw_jq_match <<'JQ' || true
def hw_glob: "^" + (ascii_downcase | gsub("[*]"; ".*") | gsub("[?]"; ".")) + "$";
def hw_list: if type == "array" then . elif . == null then [] else [.] end;
def hw_dmi_file: {dmi_vendor: "sys_vendor", dmi_product: "product_name", dmi_family: "product_family", dmi_version: "product_version",
  dmi_board: "board_name", dmi_board_vendor: "board_vendor", dmi_chassis: "chassis_type", dmi_bios_vendor: "bios_vendor",
  dmi_bios_version: "bios_version"}[.] // ltrimstr("dmi_");
def hw_pci_id($g): if ($g | split(":") | length) >= 4 then "\(.vendor):\(.device):\(.svendor):\(.sdevice)" else "\(.vendor):\(.device)" end;
def hw_cond($F; $m; $k):
  if $k == "pci" or ($k == "pci_class" and $m.pci == null) then
    [$F.pci[] | . as $d
      | select(($m.pci | hw_list | length) == 0 or any($m.pci | hw_list | .[]; . as $g | $d | hw_pci_id($g) | test($g | hw_glob)))
      | select(($m.pci_class | hw_list | length) == 0 or any($m.pci_class | hw_list | .[]; . as $c | $d.class | test($c | hw_glob)))] as $hits
    | {ok: ($hits | length > 0), why: [$hits[] | "pci \(.vendor):\(.device)"], devices: [$hits[] | "pci:\(.slot)"]}
  elif $k == "pci_class" then empty
  elif $k == "usb" then
    [$F.usb[] | . as $d | select(any($m.usb | hw_list | .[]; . as $g | $d.id | test($g | hw_glob)))] as $hits
    | {ok: ($hits | length > 0), why: [$hits[] | "usb \(.id)"], devices: [$hits[] | "usb:\(.id)"]}
  elif ($k | startswith("dmi_")) then
    ($F.dmi[$k | hw_dmi_file] // "") as $v
    | {ok: any($m[$k] | hw_list | .[]; . as $re | $v | test($re; "i")), why: ["\($k | hw_dmi_file) \($v)"], devices: []}
  elif $k == "arch" then {ok: any($m.arch | hw_list | .[]; . == $F.arch), why: [], devices: []}
  elif $k == "laptop" then {ok: ($m.laptop == $F.laptop), why: (if $F.laptop then ["a laptop"] else [] end), devices: []}
  elif $k == "virtual" then {ok: ($m.virtual == $F.virtual), why: [], devices: []}
  elif $k == "cpu_vendor" then {ok: any($m.cpu_vendor | hw_list | .[]; . == $F.cpu.vendor), why: ["cpu \($F.cpu.vendor)"], devices: []}
  elif $k == "cpu_family" then {ok: any($m.cpu_family | hw_list | .[]; . == $F.cpu.family), why: [], devices: []}
  elif $k == "cpu_model" then {ok: any($m.cpu_model | hw_list | .[]; . == $F.cpu.model), why: ["cpu model \($F.cpu.model)"], devices: []}
  elif $k == "dt_compatible" then
    [$F.dt[] | . as $c | select(any($m.dt_compatible | hw_list | .[]; . as $g | $c | ascii_downcase | test($g | hw_glob)))] as $hits
    | {ok: ($hits | length > 0), why: [$hits[] | "device tree \(.)"], devices: []}
  elif $k == "kernel_log" then
    [$m.kernel_log | hw_list | .[] | . as $re | select(any($F.log[]?; test($re)))] as $hits
    | {ok: ($hits | length > 0), why: ["a kernel message"], devices: []}
  else {ok: false, why: ["unknown match key \($k)"], devices: []} end;
def hw_match($F):
  (.match // {}) as $m
  | [($m | keys[]) as $k | hw_cond($F; $m; $k)] as $c
  | if ($c | length) > 0 and all($c[]; .ok) then del(.match) + {why: [$c[].why[]], devices: ([$c[].devices[]] | unique)} else empty end;
JQ

# What apply and the rows share: whether a fix sets anything up, and the fixes that apply to a system: those
# that match it, and those marked keep that were set up in it before (what they matched goes away once they work).
read -r -d '' hw_jq_common <<'JQ' || true
def hw_acts: (.apply // {}) | [(.packages // []), (.cmdline // []), (.modprobe // []), (.initramfs_modules // []), (.udev // []), (.services // [])] | add | length > 0;
def hw_with_kept($M; $X; $R):
  $M + [$X[] | select(.error == null and .keep == true) | . as $f
        | select(any($M[]; .id == $f.id) | not)
        | select(any(($R.fixes // [])[]; .id == $f.id and .status == "applied"))
        | del(.match) + {why: ["kept"], devices: []}];
JQ

# hw_needs_log <fixes>: true when a fix reads the kernel's messages (so the log is read only then).
hw_needs_log() { [[ "$1" == *'"kernel_log"'* ]]; }

# hw_match <facts> <fixes>: the fixes that apply, one JSON object per line, each with why and devices.
hw_match() {
  { printf '%s\n' "$1"; printf '%s\n' "$2"; } | jq -nc "$hw_jq_match"' input as $F | inputs | select(.error == null) | hw_match($F)'
}

# hw_room_of <root>: the room a system root is, or nothing. A room being built is named by its folder, the
# setup disc's target by its fstab, the running system by findmnt.
hw_room_of() {
  local r=${1%/} o=""
  case "$r" in */@rooms/*) printf '%s' "${r##*/}"; return 0 ;; esac
  if [[ -z "$r" ]]; then
    if [[ -n "${TAKUMI_HW_ROOM+set}" ]]; then printf '%s' "$TAKUMI_HW_ROOM"; return 0; fi
    o=$(findmnt -no OPTIONS / 2>/dev/null || true)
  else
    o=$(awk '$2 == "/" { print $4; exit }' "$r/etc/fstab" 2>/dev/null || true)
  fi
  printf '%s\n' "$o" | sed -n 's/.*subvol=\/\{0,1\}@rooms\/\([^,]*\).*/\1/p' | head -n 1
}
# hw_room: the name this system's entry has in the record ("system" on a computer without rooms).
hw_room() { local r; r=$(hw_room_of /); printf '%s' "${r:-system}"; }

# hw_record_for <root>: where an apply into <root> keeps its record: the shared /var/lib/takumi of the computer
# that will start it. A room being built shares the running system's; the setup disc's target has its own,
# already mounted.
hw_record_for() {
  if [[ -n "${TAKUMI_HW_RECORD:-}" ]]; then printf '%s' "$TAKUMI_HW_RECORD"; return 0; fi
  case "${1%/}" in ""|*/@rooms/*) printf '/var/lib/takumi/hardware.json' ;; *) printf '%s/var/lib/takumi/hardware.json' "${1%/}" ;; esac
}
hw_record() { printf '%s' "${TAKUMI_HW_RECORD:-/var/lib/takumi/hardware.json}"; }
# hw_entry [room]: what was set up in a room, as JSON ({} when nothing was).
hw_entry() { jq -c --arg r "${1:-$(hw_room)}" '.rooms[$r] // {}' "$(hw_record)" 2>/dev/null || echo '{}'; }

# hw_fprint_state: works, none (fprintd sees no reader it can drive) or missing (fprintd is not installed).
hw_fprint_state() {
  command -v fprintd-list >/dev/null || { echo missing; return 0; }
  local out; out=$(fprintd-list "$(id -un)" 2>&1 || true)
  case "$out" in *"No devices available"*) echo none ;; *"found "*" devices"*|*"Using device"*) echo works ;; *) echo unknown ;; esac
}

# The rows of "This computer", one JSON object each: {id, part, title, subtitle, glyph, keywords, score, detail,
# pending, run}. A part found in the computer, the fixes that belong to it and what was set up decide what its
# row says.
read -r -d '' hw_jq_rows <<'JQ' || true
def hw_vendor: {"10de": "NVIDIA", "8086": "Intel", "8087": "Intel", "1002": "AMD", "1022": "AMD", "14e4": "Broadcom",
  "10ec": "Realtek", "14c3": "MediaTek", "168c": "Qualcomm Atheros", "17cb": "Qualcomm", "11ab": "Marvell", "106b": "Apple",
  "1af4": "Virtio", "15ad": "VMware", "80ee": "VirtualBox", "1b36": "QEMU", "1414": "Microsoft", "1d6a": "Aquantia",
  "0bda": "Realtek", "0e8d": "MediaTek", "0a5c": "Broadcom", "0cf3": "Qualcomm Atheros"}[.] // null;
def hw_part: if (.class | startswith("03")) then "graphics" elif .class == "0280" then "wifi" elif .class == "0200" then "wired"
  elif ((.class == "0401" or .class == "0403") and .vendor != "10de" and .vendor != "1002") then "sound" else null end;
def hw_label: {graphics: "Graphics", wifi: "Wi-Fi", wired: "Wired network", sound: "Sound", bluetooth: "Bluetooth",
  camera: "Camera", fingerprint: "Fingerprint reader", touchpad: "Touchpad", processor: "Processor"}[.] // null;
def hw_glyph: {graphics: "display", wifi: "wifi", wired: "wired", sound: "vol", bluetooth: "bt", camera: "video",
  fingerprint: "finger", touchpad: "touchpad"}[.] // "chip";
def hw_words: {graphics: "graphics gpu video card driver", wifi: "wireless card adapter chip driver", wired: "ethernet wired cable card",
  sound: "sound audio speakers microphone", bluetooth: "bluetooth adapter", camera: "camera webcam",
  fingerprint: "fingerprint finger reader unlock", touchpad: "touchpad trackpad", processor: "processor cpu chip cooling",
  computer: "laptop desktop model"}[.] // "";
def hw_uniq: reduce .[] as $s ([]; if any(.[]; . == $s) then . else . + [$s] end);
def hw_devname:
  (.vendor | hw_vendor) as $v
  | (if .class == "0280" and .sname != "" then .sname
     elif (.dname | test("\\[[^\\]]+\\]$")) then (.dname | capture("\\[(?<n>[^\\]]+)\\]$").n)
     else .dname end | sub(" [0-9]+MHz$"; "")) as $n
  | if $n == "" then ($v // "Unknown") + " " + ({graphics: "graphics", wifi: "Wi-Fi", wired: "network", sound: "audio"}[hw_part // "other"] // "device")
    elif $v != null and (($n | ascii_downcase | startswith($v | ascii_downcase)) | not) then "\($v) \($n)" else $n end;
def hw_maker: (. // "") | if test("^LENOVO$"; "i") then "Lenovo" elif test("^Dell"; "i") then "Dell" elif test("^(HP|Hewlett)"; "i") then "HP"
  elif test("^ASUS"; "i") then "ASUS" elif test("^Micro-Star"; "i") then "MSI" elif test("^Apple"; "i") then "Apple"
  elif test("^Microsoft"; "i") then "Microsoft" elif test("^Acer"; "i") then "Acer" elif test("^SAMSUNG"; "i") then "Samsung"
  elif test("^Gigabyte"; "i") then "Gigabyte" elif test("^innotek"; "i") then "VirtualBox" elif test("^VMware"; "i") then "VMware"
  elif test("^(To be filled|System manufacturer|Default string|O\\.E\\.M)"; "i") then "" else . end;
def hw_computer($F):
  ($F.dmi.sys_vendor | hw_maker) as $mk
  | (if (($F.dmi.sys_vendor // "") | test("^LENOVO$"; "i")) and ($F.dmi.product_version // "") != "" then $F.dmi.product_version
     else $F.dmi.product_name // "" end) as $p
  | ($p | if test("^(To be filled|System Product Name|Default string|O\\.E\\.M|Not Applicable)"; "i") then "" else . end) as $p
  | (if $p == "" then (($F.dmi.board_vendor | hw_maker) + " " + ($F.dmi.board_name // "")) else $p end | gsub("^ +| +$"; "")) as $p
  | if $p == "" then (if $F.laptop then "a laptop" else "a computer" end)
    elif $mk != "" and (($p | ascii_downcase | startswith($mk | ascii_downcase)) | not) then "\($mk) \($p)" else $p end;
def hw_cpuname: (. // "") | gsub("\\((R|TM|r|tm)\\)"; "") | sub(" @ .*$"; "") | sub(" w/ .*$"; "") | sub(" with .*Graphics$"; "")
  | gsub(" CPU"; "") | gsub("  +"; " ") | gsub("^ +| +$"; "");
def hw_memory($kb): ($kb / 1048576) as $g | if $kb <= 0 then "" else
  "\(first([2, 4, 6, 8, 12, 16, 18, 24, 32, 36, 48, 64, 96, 128, 192, 256, 384, 512, 768, 1024][] | select(. >= $g)) // ($g | round)) GB" end;
def hw_status($R): if hw_acts then (.id as $id | first(($R.fixes // [])[] | select(.id == $id) | .status) // "pending") else "info" end;
def hw_pending: . == "pending" or . == "waiting" or . == "failed";
def hw_driver_words($part):
  if .driver == "" then "no driver"
  elif $part == "graphics" and .driver == "nvidia" then "NVIDIA's own driver"
  elif $part == "graphics" and .driver == "nouveau" then "open nouveau driver"
  elif .driver == "vfio-pci" then "lent to a virtual machine"
  else "works" end;
# What a row says, from its fixes ($fx) and its device ($d, or null).
def hw_state($fx; $d; $part; $FP):
  ([$fx[] | select(.works == "no")] | .[0]) as $no
  | if $no != null then ($no.says | if . == "" then "not supported yet" else . end)
    elif any($fx[]; .status | hw_pending) then "set up at the next update"
    elif $part == "fingerprint" then ({works: "works", none: "not supported yet", missing: "found; fprintd is not installed"}[$FP] // "found")
    elif any($fx[]; .status == "unavailable") then "what it needs is not in this computer's repositories"
    elif $d != null and any($fx[]; .driver != "" and .status == "applied" and .driver != $d.driver) then "set up; in use after a restart"
    else ([$fx[] | .says | select(. != "")] | hw_uniq | join(" · ")) as $s
      | if $s != "" then $s elif $d != null then ($d | hw_driver_words($part)) elif ($fx | length) > 0 then "in use" else "works" end end;
def hw_detail($fx; $d; $part):
  ([$fx[] | .apply.note // empty | select(. != "")] | hw_uniq | join(" ")) as $notes
  | ([$fx[] | .apply.aur // [] | .[]] | hw_uniq) as $aur
  | [ (if $notes != "" then $notes else empty end),
      (if any($fx[]; .status | hw_pending) then "Takumi sets this up at the next update, in a new system you can go back from." else empty end),
      (if any($fx[]; .status == "unavailable") then "What it needs is not in this computer's package repositories." else empty end),
      (if ($aur | length) > 0 and (($aur | map(. as $a | $notes | contains($a)) | all) | not) then "From the AUR, which Takumi never installs by itself: \($aur | join(", "))." else empty end),
      (if ($fx | length) == 0 and $d != null then
         (if $d.driver == "" then "No driver is in use for it, and Takumi knows no fix for it yet." else "It works with the driver that comes with Linux (\($d.driver))." end)
       else empty end) ] | join(" ");
def hw_rows($F; $M; $X; $R; $FP):
  hw_with_kept($M; $X; $R) as $all
  | [$all[] | . + {status: hw_status($R)}] | sort_by([(.driver == ""), .id]) | . as $fx
  | [$F.pci[] | . + {part: hw_part} | select(.part != null)] as $devs
  | ($devs | map(select(.part != "sound")) + ([$devs[] | select(.part == "sound")] | .[0:1])) as $devs
  | [ ($devs[] | . as $d | {id: ("hw:pci:" + .slot), part: .part, device: $d,
        name: (if .part == "sound" and ($F.codecs | length) > 0 then $F.codecs[0] else hw_devname end),
        fixes: [$fx[] | select(.devices | index(["pci:" + $d.slot]))]}),
      ($F.bluetooth | to_entries[] | {id: ("hw:bt:" + .value.hci), part: "bluetooth", device: {driver: "btusb"},
        name: ((.value.vendor | hw_vendor) as $v | .value.name
               | if . == "" then ($v // "built in") elif $v != null and ((ascii_downcase | startswith($v | ascii_downcase)) | not) then "\($v) \(.)" else . end),
        fixes: [$fx[] | select(.part == "bluetooth")]}),
      ($F.cameras[] | {id: ("hw:cam:" + .id), part: "camera", device: {driver: "uvcvideo"}, name: (if .name != "" then .name else "USB camera" end), fixes: []}),
      ($fx[] | select(.part == "fingerprint") | . as $f
        | {id: ("hw:fix:" + .id), part: "fingerprint", device: null, fixes: [$f],
           name: (first($F.usb[] | . as $u | select($f.devices | index(["usb:" + $u.id])) | .id[0:4]
                    | {"27c6": "Goodix", "06cb": "Synaptics", "04f3": "Elan", "138a": "Validity", "1c7a": "Egis", "10a5": "FPC",
                       "2808": "FocalTech", "08ff": "AuthenTec", "147e": "UPEK", "298d": "Next Biometrics"}[.] // empty) // "built in")}),
      (($F.cpu.name | hw_cpuname) as $cpu | [$fx[] | select(.part == "processor")] as $pf
       | if $cpu != "" or ($pf | length) > 0 then {id: "hw:cpu", part: "processor", device: null, name: (if $cpu != "" then $cpu else "processor" end), fixes: $pf}
         else empty end)
    ] as $base
  | ([$base[].fixes[].id]) as $shown
  | ($base + [$fx[] | select(.id as $i | $shown | index([$i]) | not) | . as $f
       | {id: ("hw:fix:" + .id), part: .part, device: null, fixes: [$f],
          name: (if (.part | hw_label) != null and (.part == "camera" or .part == "touchpad" or .part == "bluetooth" or .part == "wifi" or .part == "graphics" or .part == "sound")
                 then (.title | sub(" (camera|touchpad|Wi-Fi|Bluetooth|graphics)$"; "")) else .title end)}]) as $rows
  | [$fx[] | select(.status | hw_pending)] as $todo
  | [$fx[] | select(.status == "applied")] as $inuse
  | ([$rows | to_entries[] | .key as $i | .value
      | (.part | hw_label) as $label
      | {id, part, glyph: (.part | hw_glyph), fixes: [.fixes[].id],
         title: (if $label != null then "\($label): \(.name)" else .name end),
         subtitle: hw_state(.fixes; .device; .part; $FP),
         detail: hw_detail(.fixes; .device; .part),
         pending: any(.fixes[]; .status | hw_pending),
         keywords: ((.part | hw_words) + " hardware this computer parts drivers"),
         score: (({graphics: 0.9, wifi: 0.89, bluetooth: 0.885, camera: 0.88, sound: 0.875, fingerprint: 0.87, touchpad: 0.865,
                   wired: 0.86, processor: 0.855}[.part] // 0.85) - $i * 0.0001)}]) as $parts
  | [ {id: "hw:computer", part: "computer", glyph: "chip", fixes: [$inuse[].id], title: "This computer: \(hw_computer($F))",
       subtitle: ([($F.cpu.name | hw_cpuname | select(. != "")), (hw_memory($F.memory_kb) | select(. != "") | . + " memory"),
                   (if ($inuse | length) == 1 then "1 fix in use" elif ($inuse | length) > 1 then "\($inuse | length) fixes in use" else empty end)] | join(" · ")),
       detail: ("\(hw_computer($F))" + (if ($inuse | length) > 0 then ". Takumi's fixes in use here: \([$inuse[].title] | join(", "))." else ". Nothing in it needed one of Takumi's fixes." end)
                + (if $F.virtual then " It is a virtual machine." else "" end)),
       pending: false, keywords: ("hardware this computer parts drivers " + ("computer" | hw_words)), score: 0.95},
      $parts[],
      (if ($todo | length) > 0 then
        {id: "hw:pending", part: "computer", glyph: "restart", fixes: [$todo[].id], packages: ([$todo[].apply.packages // [] | .[]] | hw_uniq),
         title: "Set up what this computer needs",
         subtitle: (([$todo[].title] | hw_uniq) as $t | (if ($t | length) > 3 then ($t[0:2] | join(", ")) + " and \($t | length - 2) more" else $t | join(", ") end)
                    + " · Enter updates Takumi, in a new system"),
         detail: "Takumi has fixes for this computer that are not in this system yet. An update puts them in a new system, which you can go back from.",
         pending: true, keywords: "hardware this computer drivers setup set up update fix", score: 0.96, run: ["takumi", "update"]}
       else empty end) ];
JQ

# hw_rows [data-dir]: the rows of "This computer" for this computer, one JSON object per line.
hw_rows() {
  local dir fixes facts matches entry fp=missing
  dir=$(hw_data_dir "${1:-}") || dir=""
  fixes=""; [[ -n "$dir" ]] && fixes=$(hw_fixes "$dir")
  if hw_needs_log "$fixes"; then facts=$(hw_facts log); else facts=$(hw_facts); fi
  matches=""; [[ -n "$fixes" ]] && matches=$(hw_match "$facts" "$fixes")
  entry=$(hw_entry)
  [[ "$matches" == *'"part":"fingerprint"'* ]] && fp=$(hw_fprint_state)
  { printf '%s\n' "$facts"; printf '%s\n' "$entry"; printf '%s\n' "${matches:-}" | jq -sc .; printf '%s\n' "${fixes:-}" | jq -sc .; } |
    jq -nc --arg fp "$fp" "$hw_jq_common$hw_jq_rows"' input as $F | input as $R | input as $M | input as $X | hw_rows($F; $M; $X; $R; $fp)[]'
}

# Firmware the kernel asked for and did not find, one line each: file <tab> package (or aur:name, or nothing)
# <tab> the part it is for. A newer firmware version a driver tried before an older one it then loaded, and a
# board-specific variant beside a general one, are not missing.
hw_firmware_missing() {
  local fw=${TAKUMI_HW_FIRMWARE:-/usr/lib/firmware} drv file stem pkg part
  hw_kernel_log | sed -e 's/^\[[^]]*\] *//' | sed -n \
    -e "s/^\([^ :]*\).*: Direct firmware load for \([^ ]*\) failed with error .*/\1${hw_tab}\2/p" \
    -e "s/^\([^ :]*\).*: firmware: failed to load \([^ ]*\).*/\1${hw_tab}\2/p" \
    -e "s/^\(Bluetooth\): .*Patch file not found, tried: '\([^']*\)'.*/\1${hw_tab}\2/p" \
    -e "s/^\(Bluetooth\): .*Failed to load Intel firmware file \([^ ]*\).*/\1${hw_tab}\2/p" \
    -e "s/^\(Bluetooth\): .*firmware file \([^ ]*\) not found.*/\1${hw_tab}\2/p" \
    -e "s/^\([^ :]*\).* firmware \([^ :]*\): fetch failed.*/\1${hw_tab}\2/p" |
  sort -u | while IFS="$hw_tab" read -r drv file; do
    [[ -n "$file" ]] || continue
    if [[ -e "$fw/$file" || -e "$fw/$file.zst" || -e "$fw/$file.xz" ]]; then continue; fi
    case "$file" in
      *.clm_blob|*.txcap_blob) continue ;;
      iwlwifi-*.ucode) stem=${file%-*}; compgen -G "$fw/$stem-*.ucode*" >/dev/null && continue ;;
      brcm/brcmfmac*.*.*) stem=${file%%.*}; compgen -G "$fw/$stem.*" >/dev/null && continue ;;
      */board-2.bin|*/board.bin) compgen -G "${fw}/$(dirname "$file")/board*.bin*" >/dev/null && continue ;;
      # Speaker amplifiers ask for their model's own tuning first ("-spkid0", "-l0") and fall back to a general one.
      cirrus/*) stem=${file%.*}; stem=${stem%%-spkid*}; stem=${stem%-[lr][0-9]}; compgen -G "$fw/$stem*" >/dev/null && continue ;;
    esac
    case "$file" in
      mrvl/*|libertas/*|mwl8k/*|mwlwifi/*) pkg=linux-firmware-marvell ;;
      qcom/*) pkg=linux-firmware-qcom ;;
      ql2*|qed/*) pkg=linux-firmware-qlogic ;;
      liquidio/*) pkg=linux-firmware-liquidio ;;
      mellanox/*) pkg=linux-firmware-mellanox ;;
      netronome/*) pkg=linux-firmware-nfp ;;
      regulatory.db*) pkg=wireless-regdb ;;
      brcm/BCM*.hcd) pkg=aur:broadcom-bt-firmware ;;
      facetimehd/*) pkg=aur:facetimehd-firmware ;;
      *) pkg="" ;;
    esac
    [[ "$file" == regulatory.db* ]] && drv=cfg80211
    case "$drv" in
      iwlwifi|mwifiex*|brcmfmac|ath1*|ath9k*|rtw88*|rtw89*|mt79*|mt76*|wl|cfg80211) part="The Wi-Fi" ;;
      Bluetooth|bluetooth|btusb|btbcm|btintel|btrtl|btmtk) part="Bluetooth" ;;
      i915|xe|amdgpu|radeon|nouveau) part="The graphics" ;;
      snd*|sof*) part="Sound" ;;
      cs35l*|cs42l*|tas2*) part="The speakers" ;;
      r8169|igc|e1000e|tg3|atlantic) part="The wired network" ;;
      *) part="A device" ;;
    esac
    printf '%s\t%s\t%s\n' "$file" "$pkg" "$part"
  done
}

# hw_doctor [data-dir]: what takumi doctor says about the hardware, one line each: "ok<tab>words" or
# "needs<tab>words". Fixes this computer needs that this system lacks come first, then missing firmware.
hw_doctor() {
  local rows todo pkgs file pkg part said=no
  rows=$(hw_rows "${1:-}" 2>/dev/null || true)
  todo=$(jq -r 'select(.id == "hw:pending") | .subtitle | sub(" · Enter.*$"; "")' <<< "$rows" 2>/dev/null || true)
  pkgs=$(jq -r 'select(.id == "hw:pending") | .packages[]?' <<< "$rows" 2>/dev/null || true)
  if [[ -n "$todo" ]]; then
    printf 'needs\t%s\n' "Takumi has fixes for this computer that are not in this system yet ($todo): \"update\" sets them up, in a new system"; said=yes
  fi
  while IFS="$hw_tab" read -r file pkg part; do
    [[ -n "$file" ]] || continue
    case "$pkg" in
      aur:*) printf 'needs\t%s\n' "$part is missing firmware ($file) that is only in the AUR (${pkg#aur:}); Takumi does not install it" ;;
      "") printf 'needs\t%s\n' "$part is missing firmware ($file) that no package Takumi knows of carries" ;;
      *) if grep -qx "$pkg" <<< "$pkgs"; then printf 'needs\t%s\n' "$part is missing firmware ($file, in $pkg): \"update\" adds it"
         else printf 'needs\t%s\n' "$part is missing firmware ($file), which is in $pkg"; fi ;;
    esac
    said=yes
  done < <(hw_firmware_missing)
  [[ $said == yes ]] || printf 'ok\t%s\n' "Takumi's fixes for this computer are in place, and no firmware is missing"
}
