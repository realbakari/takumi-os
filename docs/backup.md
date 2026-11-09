# Backups

Every hour your home folder is copied to a USB disk or a cloud, encrypted on
this computer before it leaves, and kept the way a time machine keeps it: every
hour of the last day, every day of the last month, every week before that.
Backups are for your files. Updates are undone by rooms, which never touch your
home folder ([atomic-rooms.md](atomic-rooms.md)).

## Setting up

Type "backup" (or "restore", "time machine", "file history"). Before backups
are set up, the Palette offers each place they can go:

| Row | Enter |
|---|---|
| Set up backups | asks where, in the Core (`takumi backup setup`) |
| Back up to T7 · Samsung PSSD T7 · 1 TB · Enter sets it up | one row per USB disk that can hold backups (`takumi backup setup disk:<id>`) |
| Mac Backup cannot hold backups | a disk this computer cannot write to, and why |
| Back up to Google Drive, Dropbox, OneDrive, pCloud, Box | signs in through your browser (`takumi backup setup google-drive`) |
| Back up to nas | a place you set up yourself with `rclone config` (`takumi backup setup remote:nas`) |

Setup is a conversation in the Core:

1. **A disk** is opened through udisks2, with no password for a USB disk. A
   disk formatted for a Mac, or locked with BitLocker, is refused with the
   reason. exFAT, FAT, NTFS, ext4, Btrfs and XFS all work.
2. **A cloud** signs in the way rclone always does: rclone serves its sign-in
   page on this computer and the browser opens it. The Core says "Sign in to
   Google Drive in your browser, then allow rclone", and shows the page's
   address if no browser came up. Google Drive is asked only for the files
   rclone makes, never the rest of your drive. The same sign-in
   (`backup_signin` in `lib/backup.sh`) puts a cloud in your home as a
   folder, under its own remote and with the whole drive: see
   [drives.md](drives.md).
3. The backups go in a folder of their own, `Takumi Backups/<this computer>`.
4. It ends on a card: **your backup key**, 32 digits in eight groups of four,
   hidden until you press Enter, beside a code a phone camera keeps. The card
   says it plainly: it is your only copy if the computer is lost, because
   nobody can open the backups without it. Write it down or take a photo, and
   keep it away from the computer.
5. The first backup starts at once.

Setting up again with a key already in the keyring needs no new card: new
backups use the same key.

## A new computer, or a new install

Choose the same disk or cloud. When it already holds backups the keyring
cannot open, the Core says whose they are ("T7 holds the backups of
old-laptop. Go on with them here?") and asks for their backup key, again after
a wrong one, three times. The backups then carry on where they were, and
"Restore files from a backup" shows everything the old computer kept. Saying
no starts new backups beside them.

## Every hour

`takumi-backup.timer` starts a backup on the hour. It runs only on the
charger and at most once an hour, so a laptop on battery waits. Plugging the
backup disk in starts one too. A USB disk is waited for: nothing is said
while it is away, and after seven days the Core says "Backup disk not seen for
7 days · Plug in T7 to back up", once a week.

"Back up now" does not wait for anything. It says when it starts and when it
is done ("Backed up to T7 · 41 GB of your home folder"). The backups open the
disk when they need it and close it again, so it can be unplugged between
them.

A backup that fails says why, in words: "T7 is full", "The key in your
keyring does not open the backups on T7", "Google Drive could not be reached".
The same trouble is said once a day, and the backup row keeps saying it until
a backup works.

## What is kept

Your whole home folder, except the folders in
`~/.config/takumi/backup.toml`, under `[skip]`: what apps rebuild or download
again, such as caches, the Trash, Steam games (your saves are kept), apps from
Flathub (their settings are kept), code projects' downloads. "Choose what is
backed up" opens the file. One folder per line, from your home folder; `*`
stands for any name. A folder with an empty file named `.nobackup` in it is
left out too, and so is any folder marked as a cache by its app (a
`CACHEDIR.TAG` file).

## Restoring

"Restore files from a backup" opens your backups in Files: one folder per
backup, named by its date and time ("2026-11-09 14.00"), each holding your
home folder as it was. Copy back what you need. They are read-only, so nothing
in a backup can be changed by accident. "Close your backups" closes them, and
they close by themselves after four hours or at logout. While they are open,
backups go on but nothing old is let go.

## Commands

```
takumi backup setup [disk:UUID | google-drive | dropbox | onedrive | pcloud | box | remote:NAME]
takumi backup now                   back up now; from a script it runs in takumi-backup.service
takumi backup status [--json]       "Backed up 3 min ago · 41 GB" and where
takumi backup restore [--close]     your backups by date, in Files
takumi backup key                   a new key on a card; the old one stops opening the backups
takumi backup off                   no more backups; those made stay where they are
```

`setup` exits 0 set up · 2 not a place Takumi knows · 3 an answer was needed
and none came · 4 the key did not open the backups · 5 the disk is not here or
cannot hold backups · 6 signing in to the cloud did not finish · 1 anything
else. `now` exits 0 backed up or nothing to do yet · 1 failed · 2 not set up ·
3 the disk is not plugged in.

## How it works

The backups are a [restic](https://restic.readthedocs.io/) repository. A disk
is opened with `udisksctl` and the repository is a folder on it; a cloud is
reached through restic's rclone backend, with the rclone remote
`takumi-backup`. The key lives in the login keyring (`secret-tool`, service
`takumi-backup`), and restic asks for it with `--password-command`, so it is
never on a command line, in the environment or in a file. A key typed in the
Core reaches restic on a pipe. Retention is `restic forget --keep-within-hourly
1d --keep-within-daily 1m --keep-weekly unlimited` after every backup, and
`restic prune`, which gives the space back, once a week on the charger.
Backups use `--skip-if-unchanged`, so an hour without changes leaves no new
snapshot.

`takumi-backup.service` runs `takumi backup now --auto` with low priority, for
the timer, for the disk, and for "Back up now", which leaves a note in
`$XDG_RUNTIME_DIR/takumi/backup-asked` so the run knows a person is waiting.
Plugging in the disk starts it through a link setup makes:
`~/.config/systemd/user/dev-disk-by\x2duuid-<id>.device.wants/takumi-backup.service`.
A device unit has no file, so `systemctl add-wants` cannot make that link.

`takumi backup restore` runs `restic mount` in its own unit,
`takumi-backup-restore`, with `--path-template %T` and `--time-template
"2006-01-02 15.04"`, so the dates are the folders, and `RuntimeMaxSec=4h`.
`restic mount` needs `fusermount` from fuse2.

What Takumi keeps:

```
~/.config/takumi/backup.toml          where ([place]) and what is skipped ([skip])
~/.local/state/takumi/backup/         last.json (when, how much), problem, seen, reminded, pruned,
                                      last-run.log, setup.log
$XDG_RUNTIME_DIR/takumi/              backup.json (a backup running, and how far), backup.lock
```

Setup installs what is missing from Arch's packages after asking: restic,
libsecret, fuse2, udisks2 for a disk, rclone for a cloud.

## Not done

- **Making a disk ready.** A disk formatted for a Mac, or a new one with
  nothing on it, has to be formatted elsewhere first.
- **A full disk.** Takumi says the disk is full; it does not yet let the
  oldest weeks go to make room.
- **Clouds that sign in with a key or a password** (Backblaze B2, S3, a NAS
  over SFTP or SMB): set them up with `rclone config` and they show as rows.
  iCloud Drive is not offered.
- **rclone's own sign-in** stays in `~/.config/rclone/rclone.conf`, which only
  you can read, not in the keyring.
- **The keyring after a one-password start.** After an encrypted disk was
  opened at boot, the login keyring is still locked
  ([encryption.md](encryption.md)), so the first backup after a start makes
  the keyring ask for your password once.
- **One place at a time**, and backing up on battery only when you ask.

## Testing

`test/backup` runs on any machine with fake restic, rclone, udisksctl, lsblk,
secret-tool and systemd: the disks and clouds offered and refused, the setup
conversation and its card, going on with another computer's backups, the
hourly rules (the charger, once an hour, a week without the disk), failures in
words, restore by date, a new key, turning backups off, and that the key never
reaches an argument, a log or any file but the keyring. In the VM, a USB disk
added to QEMU is a real disk for udisks2.
