# Languages

Your apps can speak your language. Type "language" in the Core and the
Palette shows the language in use, the way dates and numbers are written,
and the languages most people choose. A language's name finds it, in English
or in its own words: "german", "deutsch", "日本語".

Takumi's own words stay English for now: the Core, the Lock, the setup
screens and what the commands say. The language row says so, and the last
part of this page says how that changes.

Keyboards and typing Japanese, Korean or Chinese are in
[harmony-keys.md](harmony-keys.md), "Layouts and input methods".

## What you see

| Row | Says | Enter |
|---|---|---|
| Language: English (US) | Enter to change · Takumi's own words stay English for now | asks "Which language?" in the Core |
| Formats: United States | 12/31/2026 · 1,234.56 · Letter paper · Enter to change | asks "Formats of which place?" |
| English (UK), Portuguese (Brazil), … | its own name, "português (Brasil)", or "In use" | uses it from your next login |
| Formats like the language, English (US) | only while the formats are set apart | puts them back with the language |

"language" alone lists twenty-one languages: English (US and UK), Spanish
(Spain and Mexico), Portuguese (Brazil and Portugal), French, German,
Italian, Dutch, Polish, Swedish, Turkish, Russian, Ukrainian, Arabic, Hindi,
Japanese, Korean and Chinese (China and Taiwan). Any other is a name away:
every language glibc can make is there. "formats" with a country finds that
country's formats: "formats germany" shows "Formats: Germany".

## Changing the language

Enter on a language runs `takumi language set` as a conversation in the
Core. A name that fits several asks again with them: "Several match:
Portuguese (Brazil), Portuguese (Portugal). Type more, like a country".
Then it asks for your password once, in the Core, and:

1. makes the language ready when this computer has never used it: its line
   in `/etc/locale.gen` is turned on and `locale-gen` runs;
2. hands it to systemd-localed, which writes `/etc/locale.conf`;
3. gets Firefox's and LibreOffice's language packs when they are installed
   (`firefox-i18n-pt-br`, `libreoffice-fresh-pt-br`; the language's own
   pack when its country has none, `firefox-i18n-de`).

The Core says "Your apps speak Portuguese (Brazil) from your next login.
Takumi's own words stay in English for now." Apps read the language when
they start, so the open ones keep theirs until you log out. Without the
internet the packs cannot come: the language changes all the same, and the
Core says Firefox and LibreOffice follow once it runs again online.

The language is the computer's, so the login screen and every account on
it follow.

Setup asks the language first; the setup disc writes `/etc/locale.conf`
for it ([setup.md](setup.md)).


## Formats

Dates, times, numbers, money, paper and units (`LC_TIME`, `LC_NUMERIC`,
`LC_MONETARY`, `LC_PAPER`, `LC_MEASUREMENT`) change together, apart from the
language: English menus with dates written as in Germany. The formats row
shows how they write the last day of 2026, a number and the paper size.
Choosing a new language keeps formats you set apart; choosing the language's
own formats puts them back with it. Apps that write a month's name write it
in the formats' language, since glibc keeps the names with the date formats.

## Commands

```
takumi language                     the language and the formats in use
takumi language set [<code>]        the language from your next login; asks which without a code
takumi language formats [<code>]    dates, numbers, money and paper apart from the language
takumi language list [<words>]      every language this computer can speak, by name
```

A code is glibc's (`de_DE.UTF-8`, `hi_IN`) or the way people write it
(`de-DE`, `de`). `takumi language set` and `formats` are conversations
(`lib/core.sh`); their exit status says what happened and their last line
says it in words:

| Exit | Means |
|---|---|
| 0 | done, or already so |
| 2 | not a usage they know |
| 3 | an answer or the password was needed and none came; nothing changed |
| 5 | not a language this computer knows |
| 1 | anything else; nothing changed |

## How it works

The names come from glibc itself. `/usr/share/i18n/SUPPORTED` lists every
locale it can make, and each one's source in `/usr/share/i18n/locales/`
names it in English (`LC_IDENTIFICATION`) and in its own words
(`LC_ADDRESS`). They are read once into
`~/.cache/takumi/languages-1.tsv`, and again when glibc's list changes.

When the language is made and nothing is to be installed, `localectl
set-locale` asks polkit, and the Core asks for the password ("Changing the
language needs your password", [approvals.md](approvals.md)). When there is
more to do, one password through `sudo` covers it all: `/etc/locale.gen`
(written whole through `tee`), `locale-gen`, `localectl` and `pacman`. What
they print goes to `~/.local/state/takumi/language.log`.

`localectl set-locale` replaces every variable at once, so the command hands
it the whole set: the new `LANG`, the formats set apart, and anything else
already there. A new language drops `LANGUAGE` and `LC_MESSAGES`, which
would speak over it.

At every login `takumi-session` reads `/etc/locale.conf` and gives it to the
session's service manager, before the shell starts. The shell, and every app
it opens, take the language from there, even when a login follows a change
so quickly that the last session's manager is still running.

## Takumi's own words

They stay English for now. This is how a language for them plugs in later,
without changing how any command or screen is built:

1. **One catalog per language**, `words/<code>.po`, in GNU gettext's format
   ([the manual](https://www.gnu.org/software/gettext/manual/gettext.html)).
   Each `msgid` is a sentence exactly as the code writes it ("Connected to
   %s"), each `msgctxt` the file it comes from.
2. **Built at install.** An install step compiles each catalog with `msgfmt`
   to `/usr/share/locale/<code>/LC_MESSAGES/takumi.mo` for the commands, and
   to `/usr/share/takumi/words/<code>.json` for the shell.
3. **Commands.** `lib/words.sh` gives one function, `words "Connected to %s"
   "$name"`: `gettext -d takumi` finds the sentence, `printf` fills it in.
   `core_note`, `core_wrong`, `core_done` and the rows the providers print
   pass every sentence through it. The router passes each ABOUT block's
   `title`, `summary` and `words` through it with "group name" as the
   context, so the Palette and Intent's manifest read in the language.
4. **The shell.** `shell/Look/Words.qml`, a singleton, loads the JSON for
   `Qt.locale().name` and answers `Words.t("Search")`; every `text:` passes
   through it. A sentence with no translation stays English. Arabic and
   Hebrew turn the shell's layouts around with Qt's `LayoutMirroring`.
5. **Which language.** `LANG`, the same as the apps, which the session
   already hands the shell.
6. **The setup disc** asks for the language first, before the keyboard, uses
   the same catalogs on its screens, and writes `LANG` into the new
   computer's `/etc/locale.conf`.
7. **Checks.** A test fails when a `msgid` no longer appears in the code, or
   when a translation's `%s` placeholders differ from the English ones.

## Not yet

- Takumi's own words in any language but English (above).
- A language for one account only: the language is the computer's.
- Spelling dictionaries for LibreOffice and Firefox (`hunspell-*`).
- Apps from Flathub keep the languages they were installed with until
  Flatpak's own list of languages includes the new one.
- The setup disc asks for no language: a new computer starts in US English.

## Testing

`test/language` runs on any machine against a fake glibc, systemd-localed,
`sudo` and `pacman`: names in English and in their own words (escaped ones
too), a language picked from what is typed, codes in every usual spelling,
the locale made first when it must be, with one password, the language
packs, the formats kept apart, every exit code, the conversation's lines,
and the rows. Changing the language for real is checked in the VM: the
password in the Core, `locale -a`, `/etc/locale.conf`, and an app in the new
language after logging out and in.
