# Dictation

Speak instead of typing, in any app, with nothing leaving the computer. Press
`Super+H`, speak, and press it again: what you said is typed where you were.

## What you see

While it listens, the Core says "Listening…" with a level that moves as you
speak, and the microphone's mark shows in the Core. The second press turns it
into "Writing it down…", then the words appear in the window you were in and
the Core says "Typed what you said" with their first words.

"Dictate" in the Palette starts and stops it too. `Super+H` is the key Windows
uses for typing by voice.

When nothing was said, or only a quiet room was heard, nothing is typed and
the Core says "Nothing heard". A dictation left running stops by itself after
five minutes and is typed.

## The first time

The first press opens the Core on "Set up dictation". Enter asks one question,
with the size: "Download the speech model, 574 MB? It stays on this
computer, and so does your voice." Enter again downloads it, the row counting
the percent, and the Core says "Dictation is ready". If the download stops
(the computer slept, the network went), the next try carries on from where it
stopped.

When the computer lacks whisper-cpp, the program that turns speech into text,
the same row asks to install it first and asks for your password in the Core.

The model depends on the computer's memory:

| Memory | Model | Size |
|---|---|---|
| under 6 GB | `base` | 149 MB |
| 6 to 12 GB | `small` | 489 MB |
| 12 GB and more | `large-v3-turbo-q5_0` | 574 MB |

The turbo model writes down nearly as well as whisper's largest, at a fifth of
its size. `takumi voice setup small` (or `base`) chooses another; the one in
use is the one `~/.config/takumi/voice.toml` names:

```toml
model = "small"
language = "auto"   # or a code such as en, de, es, fr, ja
```

The language spoken is found by the model from the first words. A language
code there makes short dictation more reliable when you always speak the same
one.

## Nothing leaves the computer

The microphone is recorded into memory (`$XDG_RUNTIME_DIR`), written down by
the model on this computer, and deleted as soon as it has been written down.
No text is kept. The words reach the app through `wtype`'s standard input,
never on a command line where other users could read them. The one thing
downloaded is the model, once, from whisper.cpp's own models
(`huggingface.co/ggerganov/whisper.cpp`), and it is checked against the SHA-1
whisper.cpp publishes for it before it is used.

## Commands

```
takumi voice [start|stop|cancel]   start listening, or stop and type; cancel types nothing
takumi voice setup [model]          whisper-cpp and the speech model, asked for in the Core
```

| Command | Exit |
|---|---|
| `voice` | 0 listening, or written down and typed · 1 it could not listen or write it down · 2 usage · 3 not set up (the Core opens on "Set up dictation") · 4 nothing heard |
| `voice setup` | 0 ready · 1 it could not be set up · 2 not a model · 3 an answer was needed and none came, or it was no |

## How it works

1. `pw-record` records the microphone in use at 16 kHz, one channel, the
   rate the model listens at, named "Dictation" so the sound rows say who has
   the microphone. Three times a second the level of the last tenth of a
   second becomes the notice's meter (-55 dB of full scale is empty, -10 dB
   full), and the loudest moment is kept.
2. The second press notes the window in front, stops the recorder and reads
   the recording. Under half a second, or never louder than about -46 dB, is
   nothing heard: a model given silence makes words up.
3. `whisper-cli -m <model> -f <recording> -l auto -t <threads> -nt -np -sns`
   writes it down, on up to eight of the processor's threads, with its marks
   for silence and noise ("[BLANK_AUDIO]") left out.
4. The window you were in comes back to the front if another took its place,
   and `wtype` types the words in a UTF-8 locale, so accents and other
   scripts come out whole. Without `wtype`, they are copied instead ("Copied
   what you said · paste it with Super+V").

While it listens, `$XDG_RUNTIME_DIR/takumi-voice` holds the recorder, the
meter, the start and the recording. The models live in
`~/.local/share/takumi/voice/`.

## Not yet

- Holding the key down to talk: niri runs a key's action when it goes down,
  not when it comes up, so the key is pressed twice.
- Words appearing while you speak: they come when you stop.
- Spoken punctuation and commands ("new line", "delete that").
- Choosing the language in the Core: it is set in `voice.toml`.
- An ARM computer: Arch Linux ARM does not package whisper-cpp, so setup
  says so and stops there.

## Testing

`test/voice` runs on any machine with fake tools: the recorder, the model,
the keyboard, the sound server, the shell, niri, curl, pacman and sudo. It
checks the model chosen by memory, setup asking with the size and checking the
sum (declined, damaged, cut short and carried on, already whole), installing
whisper-cpp with the password asked in the Core, the level while listening,
the words typed through standard input where you were, a quiet room and a
short press typed as nothing, the model failing, copying when typing fails,
cancelling, and a dictation that stops itself.

The code: `lib/voice.sh`, `commands/voice/main`, `commands/voice/setup`.
