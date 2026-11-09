#!/usr/bin/env python3
"""Run commands on the archboot live system's serial console and print their output. Stdlib only.
Usage: console.py <host:port> <log path> <command> [command ...]
Each command's output is printed between its own markers; the exit code follows as `exit=N`."""
import re, socket, sys, time

addr, log_path, commands = sys.argv[1], sys.argv[2], sys.argv[3:]
host, port = addr.rsplit(":", 1)
ANSI = re.compile(rb"\x1b\[[0-9;?]*[ -/]*[@-~]|\x1b\][^\x07\x1b]*(?:\x07|\x1b\\)|\x1b[PX^_][^\x1b]*\x1b\\|\x1b[@-Z\\-_]|\r")
deadline = time.time() + 900

def connect():
    while time.time() < deadline:
        try:
            s = socket.create_connection((host, int(port)), timeout=5); s.setblocking(False); return s
        except OSError: time.sleep(1)
    sys.exit("serial port never opened")

s = connect(); log = open(log_path, "ab", buffering=0); raw = b""; buf = ""
def read_some():
    global raw, buf
    try:
        d = s.recv(65536)
        if d:
            log.write(d); raw += d
            cut = raw.rfind(b"\x1b")
            done, raw = (raw, b"") if cut < 0 or len(raw) - cut > 64 else (raw[:cut], raw[cut:])
            buf += ANSI.sub(b"", done).decode("utf-8", "replace")
    except BlockingIOError: pass
def wait_for(pattern, timeout):
    global buf
    end = time.time() + timeout; rx = re.compile(pattern, re.S)
    while time.time() < end:
        read_some(); m = rx.search(buf)
        if m: buf = buf[m.end():]; return m
        time.sleep(0.2)
    sys.exit(f"timed out waiting for {pattern!r}")

wait_for(r"Hit ENTER for login routine or CTRL-C", 600)
s.sendall(b"\x03"); time.sleep(2); s.sendall(b"stty cols 250 rows 50 -echo; export TERM=dumb PAGER=cat SYSTEMD_PAGER=cat\n"); time.sleep(1)
for i, c in enumerate(commands):
    # Markers are computed in the shell so the command's own text can never match them.
    s.sendall(f"echo BEGIN_$((7000+{i})); {c}; echo END_$((7000+{i}))_$?\n".encode())
    m = wait_for(rf"BEGIN_{7000+i}\n(.*?)END_{7000+i}_(\d+)", 600)
    print(f"$ {c}\n{m.group(1).rstrip()}\nexit={m.group(2)}\n", flush=True)
