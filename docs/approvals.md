# Approvals

When an app or a command needs your password to change the system, the Core
asks for it, in the Lock's field, above everything else. Nothing opens a
terminal or a separate dialog, and the password never travels as an argument.

## Two ways in

- **Apps, through polkit.** The shell is the session's polkit agent
  (`shell/Sources/Approvals.qml`, `PolkitAgent` at `/org/takumi/PolkitAgent`).
  An app that asks polkit (Files opening a disk, the network, the printer,
  fwupd, the power mode) gets the Core, titled by what is being done:
  "Opening a disk needs your password", "Updating firmware needs your
  password". An unknown action says "Your password is needed" with polkit's
  own message under it, cleaned of its jargon.
- **Commands, through `sudo -A`.** The session sets `SUDO_ASKPASS` to
  `takumi approve askpass`. A command that calls `core_sudo "<why>" <command>`
  (`lib/core.sh`) runs `sudo -A` with `TAKUMI_SUDO_WHY` set, and the Core is
  titled with the why: "Updating Takumi needs your password". At a terminal,
  `core_sudo` is plain `sudo`.

## The answer's path

`takumi approve askpass` makes a FIFO only you can open (`mkfifo -m 600` in
`$XDG_RUNTIME_DIR`), hands its path and the why to the shell over IPC
(`qs ipc call approvals ask <fifo> <why>`), and waits on it. The shell writes
the answer into the FIFO through `cat`'s standard input, never as an
argument, so no other process sees it in `ps`, and nothing logs it. Enter
sends it; Esc sends an empty line, which makes `sudo` give up. A second ask
within twenty seconds means the first password was wrong: the field shakes and
starts empty. With no shell answering, `takumi approve askpass` asks at the terminal
when there is one, and otherwise fails, so `sudo` fails rather than hangs.

## Checked by

`test/approvals` runs `takumi approve askpass` against a fake shell: the answer comes
back on standard output, Esc refuses, the why reaches the Core, the FIFO is
private and gone afterwards, and with no shell and no terminal it fails
instead of waiting.
