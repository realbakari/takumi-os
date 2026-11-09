# Notifications

What apps say comes to the Core, the way Takumi says everything else. There
is no notification centre and no stack of popups: the capsule widens with the
message and settles back.

## What you see

A message widens the Core with the app's icon (a bell when the icon theme
has no icon of that name), the message's title and its first line, for five
seconds, or eight when it carries buttons. The app's own
buttons sit at the right end, up to three: "Reply", "Mark as read", "See
why". A one-time code ("Your verification code is 482913") gets a **Copy
482913** button. The pointer resting on the notice keeps it.

| You see | It means |
|---|---|
| a number on the app's icon | several messages from that app, the newest on show |
| "3 more" at the right end | three other apps' messages wait behind this one; a press brings the next |
| the notice stays | it is urgent (a battery nearly empty, a call): it waits until you put it away |

Links in a message open in the browser: the words of a link the app sent
(`<a href="…">`, the body markup the
[notification spec](https://specifications.freedesktop.org/notification-spec/latest/markup.html)
allows) or an address written out show in the accent on the notice's line, and
a press on them opens the link and puts the notice away. A link further down
the message than its first line gets an **Open link** button. Only web and
mail links open (`http`, `https`, `mailto`, through `gio open`): a message
never opens a file or runs anything.

A press on the notice runs the app's default action, which usually brings
the app forward at that message. The right button puts the notice away. The
messages behind it come next, newest first; one that waited a minute behind
others is old news and goes.

Takumi's own notices (the volume, a theme, a screenshot, a command that ran)
show over messages for a moment, and the messages come back after them.
Nothing counts down while the Core is open or the pointer rests on it, so a
message never runs out unseen behind the Palette.

## The keys

| Keys | Does |
|---|---|
| `Super+Shift+Space` | Acts on the notice on show: copies its code if it has one, else does what a press does |
| `Super+Escape` | Puts every notice away, the ones do not disturb is counting included |
| `Super+Alt+Page Down` | The next waiting notice comes forward, as a press on "3 more" does; this one waits at the back |
| `Super+Alt+Page Up` | The one before comes back |

On a Mac keyboard Page Up and Page Down are `Fn+Up` and `Fn+Down`.
`Super+Shift+Up` and `Down` stay with moving windows up and down the strip
([the-strip.md](the-strip.md)).

Space is the Core's key (`Super+Space` opens it), so `Shift+Space` answers
what the Core is saying; Escape already means "go away" everywhere in the
Core. Neither key is one of Harmony's ([harmony-keys.md](harmony-keys.md)),
neither was bound in `config/niri/takumi/defaults.kdl`, and neither means
anything on a Mac or in Windows that a hand would reach for by habit.

## Do not disturb

`takumi switch dnd`, its switch in Quick settings, or "do not disturb" in the
Palette. While it is on, messages are counted instead of shown; urgent ones
still show. Turning it off says how many came in and from which apps: "3
messages came in · From Slack and Mail · press to see them". A press lists
them in the Palette. Every message, shown or not, is also in Today and in the
Palette's earlier rows (`~/.local/state/takumi/notices.jsonl`).

## When an app quits unexpectedly

When one of your apps crashes, the Core says "Files quit unexpectedly" with
two buttons, **See why** and **Copy details**. A press on the notice, or
`Super+Shift+Space`, is See why.

See why opens the Core on "Why an app quit", and Enter shows a card: what
quit and when ("Files quit today at 14:02"), what happened in words ("It
tried to use memory it does not have"), and where it stopped ("It stopped in
g_type_check_instance_cast in libgobject-2.0.so.0, called from
nautilus_files_view_update in nautilus"). Typing "crash" finds the same row
any time.

Copy details puts the whole report on the clipboard, ready for a bug report or
for someone helping: what quit, the package it came from, the signal, the
time, Takumi's and Linux's versions, the first sixteen frames of the crashing
thread, and the command that shows the full record.

The words for each signal:

| Signal | The card says |
|---|---|
| SEGV | It tried to use memory it does not have |
| ABRT | It found a problem it could not get past and stopped itself |
| BUS | It reached for memory that was not there |
| FPE | A calculation went wrong, such as a division by zero |
| ILL | It ran an instruction this processor does not know |
| TRAP | It stopped at a check its makers put in |

## Commands

```
takumi debug crash [pid|latest]    why an app quit: a card in the Core, the whole report at a terminal
takumi debug crash [pid] --copy    the report on the clipboard
takumi debug crash --follow        what takumi-crash.service runs: a notice for each crash of yours
takumi switch dnd                  hold messages, or show them again
```

`takumi debug crash` exits 0 when it showed a crash or found none to show, 2
for a word that is not a pid, 3 when there is no record for that pid, 4 when
this computer keeps no crash records (no `coredumpctl`), and 1 otherwise.

## How it works

The shell is the desktop's notification server: Quickshell's
`NotificationServer` in `shell/Sources/Notices.qml`, which takes bodies,
actions and pictures, writes each message to `notices.jsonl` and hands it to
`shell/Sources/CoreState.qml`. CoreState keeps two kinds of notice. A flash is
Takumi's own: the newest replaces the last and it leaves on a timer. Messages
wait in a queue of at most twelve entries, newest first, one entry per app;
an entry's time runs only while it is on show. The app hears how each message
ended: it ran out, it was put away, or the button you chose. `Core/Notice.qml`
draws whichever is on show, and a screen reader hears each new one (Qt's
accessibility announcements, Qt 6.8 and later).

A code is copied by `wl-copy` reading it from its own environment, which only
you can read, never from a command line. The keys reach the shell as
`qs -c takumi ipc call notices act`, `... notices clear`, `... notices next`
and `... notices previous` (`Sources/Notices.qml` turns the queue round).

The resting Core also marks what you started and is still going
([shell.md](shell.md)): dictation listening (the microphone in the accent,
breathing; a press stops it and types what you said), a running timer (what
is left of the next one; a press opens Today) and remote help (a person; red
while someone is connected; a press opens the Core on stopping it).
`Sources/Poll.qml` reads them every ten seconds from what the commands leave:
`$XDG_RUNTIME_DIR/takumi-voice`, `~/.local/state/takumi/reminders.tsv` and
`$XDG_RUNTIME_DIR/takumi-remote`.

Crash notices come from `takumi-crash.service`, which runs
`takumi debug crash --follow`: it follows systemd-coredump's records in the
journal (`journalctl -f -o json MESSAGE_ID=fc2e22bc6ee647b6b90729ab34a250b1`),
keeps the ones about your own processes, at most one a minute for the same
program, and sends each as a message with `notify-send`, whose buttons it
waits on. The app's name and icon come from its `.desktop` file, found by the
systemd unit it ran in (`app-gnome-org.gnome.Nautilus-4242.scope`) or by its
program in `Exec=`. The card reads `coredumpctl info -1 COREDUMP_UID=<you>`:
the stack is systemd-coredump's own, made with elfutils when the crash
happened, so no debugger is needed. Its sentence skips the C library's own
way of stopping a program (`raise`, `abort`) to name the code that asked for
it.

## Not yet

- The card has no Copy button: it carries the report (`copyLabel`, `copy`),
  but `Core/Card.qml` does not draw them yet. The notice's Copy details and
  `takumi debug crash --copy` copy it today.
- See why shows your latest crash, which is the one the notice was about
  unless another app crashed since.
- Answering inside a notice (an inline reply).
- Every message at once in one list: Today shows the last three, the
  Palette's earlier rows the rest.
- A one-time code copied from a notice goes into the clipboard history like
  any other copy.

## Testing

`test/notices` runs anywhere: the crash command against fake crash records,
journal, `notify-send` and clipboard (the card's words, the report, the
follower's notices and buttons, every exit code), the niri keys in
`config/niri/takumi/defaults.kdl` (each bound once, none of Harmony's, actions
niri 26.04 has, the picture-in-picture title rule) and their migration on a
home from before them, the names the shell uses, and, where node is
installed, the queue itself: CoreState's own functions run against fake
notifications, going back and forth through the queue, and the links found in
a message's body and drawn on its line.
