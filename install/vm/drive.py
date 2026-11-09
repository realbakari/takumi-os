#!/usr/bin/env python3
"""Drive the archboot live system over QEMU's serial socket: wait for its prompt, mount the
repo share, run provision.sh, report. Stdlib only. Usage: drive.py <unix socket path> <log path>"""
import socket, sys, time, re, os

addr, log_path = sys.argv[1], sys.argv[2]
http_port = sys.argv[3] if len(sys.argv) > 3 else "4556"
host, port = addr.rsplit(":", 1)
deadline = time.time() + float(os.environ.get("TAKUMI_VM_DRIVE_TIMEOUT", "3600"))

def connect():
    while time.time() < deadline:
        try:
            s = socket.create_connection((host, int(port)), timeout=5); s.setblocking(False); return s
        except OSError: time.sleep(1)
    sys.exit("serial port never opened")

s = connect()
log = open(log_path, "ab", buffering=0)
# The live system decorates its console with CSI colours, OSC and DCS sequences; match on plain text.
ANSI = re.compile(rb"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[PX^_][^\x1b]*\x1b\\|\x1b[@-Z\\-_]|\r")
raw = b""
buf = ""
def read_some():
    global raw, buf
    try:
        d = s.recv(65536)
        if d:
            log.write(d); raw += d
            # Keep a possibly unfinished escape sequence for the next read.
            cut = raw.rfind(b"\x1b")
            done, raw = (raw, b"") if cut < 0 or len(raw) - cut > 64 else (raw[:cut], raw[cut:])
            buf += ANSI.sub(b"", done).decode("utf-8", "replace")
    except BlockingIOError: pass
def wait_for(pattern, timeout, pre=""):
    global buf
    end = time.time() + timeout; rx = re.compile(pattern)
    while time.time() < end:
        read_some()
        m = rx.search(buf)
        if m: buf = buf[m.end():]; return m
        time.sleep(0.2)
    sys.exit(f"timed out waiting for {pattern!r} {pre}")
def send(text):
    s.sendall(text.encode()); time.sleep(0.3)

print("drive: waiting for the archboot prompt")
wait_for(r"Hit ENTER for login routine or CTRL-C", 600)
send("\x03"); time.sleep(2); send("\n")
wait_for(r"#", 30)
send("stty cols 200 rows 50; export TERM=dumb\n"); wait_for(r"#", 10)
# The repo: the 9p share when the live kernel has it, otherwise the tarball the host serves at 10.0.2.2.
# Markers are computed ($((40+2))) so the terminal's echo of the command can never match them.
send("mkdir -p /share; { modprobe -a 9pnet_virtio 9p 2>/dev/null; mount -t 9p -o trans=virtio,version=9p2000.L takumi /share 2>/dev/null; } "
     f"|| curl -fsS http://10.0.2.2:{http_port}/takumi.tgz | tar xz -C /share; "
     "test -f /share/install/vm/provision.sh && echo SHARE_$((40+2))_OK || echo SHARE_$((40+2))_MISSING\n")
m = wait_for(r"SHARE_42_(OK|MISSING)", 120, "(repo share)")
if m.group(1) != "OK": sys.exit("the repo did not reach the VM: no 9p in the live kernel and no tarball over HTTP")
print("drive: share mounted, provisioning (this takes a while)")
send("TAKUMI_VM_SHARE=/share bash /share/install/vm/provision.sh 2>&1 | tee /tmp/provision.log; echo PROVISION_EXIT=${PIPESTATUS[0]}\n")
wait_for(r"PROVISION_EXIT=\d+", deadline - time.time() - 5)
done = b"TAKUMI PROVISION DONE" in open(log_path, "rb").read()
print("drive: provision", "succeeded" if done else "FAILED")
send("systemctl poweroff\n"); time.sleep(5)
sys.exit(0 if done else 1)
