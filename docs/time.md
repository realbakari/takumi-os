# Time

The clock, the time zone, clocks for other cities, reminders, timers and the
weather live in the Core. Type "time", "clock" or "zone", a city's name,
"remind", "timer" or "weather", or press the clock in the resting Core to open
Today.

## What you see

### In the Palette

The rows come from `commands/palette/time`. A row that sets something says
what it will do before Enter.

| You type | Row | Enter |
|---|---|---|
| "time", "clock", "zone" | Time zone: Lisbon · 14:05 · Portugal · Enter to change | asks "Which city?" in the Core |
| | Set the time zone by location · Off · on each new network, asks ipinfo.io which time zone your internet address is in | turns it on (asks first) |
| | Use the 12-hour clock · 2:05 PM in the Core, the lock and Today | switches the format |
| | Tokyo 23:05 · +9 h · in Today · Enter to take it out | takes that clock out of Today |
| | Add a clock to Today · Another city's time beside the month | asks "Which city?" |
| a city or a country: "tokyo", "japan" | Tokyo 23:05 · Japan · +9 h · Enter to add to Today | adds the clock |
| with "zone" or "travel": "zone tokyo" | Set the time zone to Tokyo · Japan · the clock would say 23:05 | moves the clock (asks first) |
| "remind me in 10 min to stretch" | Remind me in 10 min: stretch · Enter to set it | sets it |
| "remind me to call the bank" | Remind me to call the bank · Enter, then say when | asks when |
| "remind", "reminders" | Set a reminder; then each one: call Ana · Reminder at 15:00 · Enter to cancel | asks, or cancels (asks first) |
| "timer 10 tea", "25 min timer" | Start a 10 min timer: tea · Counts down in Today · rings at 14:15 | starts it |
| "timer" | Start a timer; then each running one: tea: 4 min left · Rings at 14:15 · Enter to stop | asks how long, or stops it |
| "weather", when it is off | Show the weather in Today · Asks Open-Meteo for Lisbon's weather, at most every 30 minutes | turns it on (asks first) |
| | Weather in Lisbon now · Asks Open-Meteo once | says the weather once |
| "weather", when it is on | Lisbon 19° · light rain · 24° later · Open-Meteo, 12 min ago · Enter for another place | asks which place |
| | Hide the weather in Today | turns it off |
| "weather tokyo" | Weather in Tokyo · Asks Open-Meteo once | says Tokyo's weather once |

A country with several time zones ("brazil") shows no city rows; a city of it
does. Under three letters the rows stay quiet, as every provider's do.

### In Today

Today keeps the month and the day as they were, and adds what is around them:

- **The weather**, when it is on, at the right of the day's name: "Lisbon 19°
  · light rain · 24° later". A press opens the Palette on "weather".
- **Clocks for other cities**, three at most, under the date: the city, its
  time, "+1" when it is already tomorrow there, and how far ahead or behind
  it is ("+9 h", "−5 h", "+5 h 30 min"). A press opens the Palette on "clock".
- **Coming up**, under the month: running timers counting down by the second,
  with a line that shortens as they run, then reminders with their moment
  ("15:00", "Tomorrow 09:00", "Fri 18:00"). Three at most; a press opens the
  Palette on them.
- **Earlier**: what your apps said, as before, in the room that is left. The
  Core's surface is `Style.coreSurface` tall, so with clocks and three things
  coming up the earlier messages make way; they never push Today past it.

Times follow the clock's format. Today reads `takumi clock today` (one JSON
line) when it opens and every half minute while it is open, and keeps the last
answer, so it opens at once. Offsets are seconds east of UTC, so Today works out
the time anywhere from the computer's own clock.

## The time zone

`takumi clock zone <place>` takes a city ("Lisbon", "São Paulo", accents and
case aside), a country with one time zone ("Japan"), or a zone's own name
("Europe/Lisbon", "UTC"). The places are the ones the setup disc offers
(`takumi setup zones`). A town the table does not name ("San Francisco") is
looked up on Open-Meteo's place search, which answers with its time zone. A
country with several time zones is asked again: "Brazil has several time zones:
try Manaus or Sao Paulo".

The change goes through timedated (`timedatectl set-timezone`). systemd's
polkit rule lets the person at the computer change the time zone without a
password; when it would want one (someone logged in from elsewhere), the
password is asked in the Core and `sudo timedatectl` makes the change. The
Core says "Time zone: Tokyo · 23:05".

## The time zone by location

Off until you turn it on. When it is on, each time a network comes up or the
internet appears, the computer sends one HTTPS request to `https://ipinfo.io/json`.
ipinfo.io sees your internet address, as every website does, and answers with
the city and time zone it belongs to. Nothing else is sent, nothing is sent
while a VPN is on (the answer would be the VPN's), and nothing at all more than
once every five minutes. When the zone changed, it is set and said: "You're in
Lisbon · clock set to 14:05".

How it is wired: NetworkManager runs
`default/networkmanager/dispatcher.d/90-takumi-clock` as root on network events.
For each person with an active session who turned it on (`auto = true` in their
`clock.toml`), it starts `takumi clock auto check --network` in that person's
own systemd (`systemd-run --machine=<user>@.host --user`), so the lookup, the
change through timedated and the notice are theirs. Nobody else is looked up.

## The clock's format

`takumi clock format 12h|24h` keeps the choice as `format` in
`~/.config/takumi/clock.toml`. Without it, the clock follows your language
(en_US reads the 12-hour clock). Today watches the file and changes at once.

## Reminders and timers

`takumi remind` takes the moment and the words in either order: "in 10 min
stretch", "call Ana at 3", "tomorrow 9:00 dentist", "water the plants on
friday", "in 1 h 30 tea". It understands "in <length>" (min, h, s, days, "an
hour", "half an hour"), "at <time>" ("15:00", "3pm", "8.30am", "15h30",
"noon"), "today", "tonight", "tomorrow" and the days of the week. A bare hour
after "at" is the next time the clock shows it: at 10:00, "at 3" is 15:00; at
16:00 it is 3:00 tomorrow. After a day, a bare hour from 1 to 7 is the
afternoon: "tomorrow at 3" is 15:00. A time that has passed today is tomorrow's.
What is missing is asked for in the Core; words that are not a time are asked
for again.

`takumi timer <length> [name]` counts down: a number on its own is minutes.

Each one is a line in `~/.local/state/takumi/reminders.tsv` and a timer in your
own systemd, `takumi-remind-<n>` or `takumi-timer-<n>`, made with
`systemd-run --user --on-calendar="<moment> UTC" --timer-property=AccuracySec=1s`.
A calendar moment, not `--on-active`: that clock stops while the computer sleeps
(systemd.timer(5)), so a reminder set before closing the lid would come late.
In UTC, so it keeps its moment when the time zone changes. To the second, not
systemd's usual minute.

When it rings, `takumi remind fire <n>` sends the message to the shell's
notification server, so the Core says it, through do not disturb (you asked for
it), and Today keeps it under Earlier. A reminder's message carries one action:
pressing it within the minute sets the same reminder again ten minutes on
("Again at 15:20"). A timer rings too, with the freedesktop sound theme's
alarm, when that theme is installed.

The timers in systemd stop when you log out or the computer turns off; the list
does not. `takumi remind restore`, at login, puts back the timers still to come,
rings the ones missed in the last 12 hours ("Reminder for 09:30") and drops
older ones.

## The weather

Off until you turn it on ("Show the weather in Today", `takumi weather on`).
Then Today asks Open-Meteo (https://open-meteo.com, no account, no key) for the
weather where the clock is, or in the place you chose
(`takumi weather place Porto`), at most every 30 minutes and only while Today
or the Palette is open. Two addresses are asked, both over HTTPS: the place
search (a name to where it is) and the forecast (where to the weather now and
over the next six hours). The answer is kept in `~/.cache/takumi/weather.json`;
older than three hours, it is not shown.

The line is the place, the temperature, what the sky is doing, and what comes
later: "rain later" when it is dry now and rain is 60% likely within six hours,
else the warmest or coolest of the next six hours when it is 2 or 3 degrees
away ("24° later"). Degrees are Celsius, or Fahrenheit where the language says
so (the United States and a few others) or `units = "fahrenheit"` asks.

`takumi weather tokyo` asks about another place once and keeps nothing.

## Commands

```
takumi clock [place]                         the time here and in your cities; or in a place
takumi clock zone [place]                    set the time zone (asks which city without one)
takumi clock auto on|off|check               the time zone by location
takumi clock format 12h|24h                  the clock's format
takumi clock add [city] | remove <city>      clocks for other cities in Today
takumi remind <when> <what>                  a reminder, either order; asks for what is missing
takumi remind list [--json] | cancel <n>     what is coming; cancel one
takumi timer <length> [name] | stop [n]      a timer; stop one, or all
takumi weather [place] [--json]              the weather here, or once in a place
takumi weather on [place] | off | place [p]  the weather in Today
```

Hidden: `takumi clock today` (Today's JSON line), `takumi remind fire <n>`
(run by its timer), `takumi remind restore` (at login),
`takumi clock auto check --network` (run by the dispatcher) and
`takumi weather --refresh` (in the background, for Today and the Palette).

The conversations end with a line that says it in words, and an exit status:

| Exit | `clock zone`, `clock add` | `remind`, `timer` | `weather`, `weather place` |
|---|---|---|---|
| 0 | set, added, or already so | set or started | said |
| 1 | it could not be changed | systemd would not keep the timer | Open-Meteo did not answer |
| 3 | an answer was needed and none came | an answer was needed and none came | an answer was needed and none came |
| 4 | no such place, or one with several time zones | not a time, or not a length (a day at most) | no such place |

## Files

```
~/.config/takumi/clock.toml       format = "24h" | "12h" | ""   auto = true | false   cities = ["Tokyo|Asia/Tokyo"]
~/.config/takumi/weather.toml     show = true | false   place = "Porto, Portugal" | ""   units = "celsius" | "fahrenheit" | ""
~/.local/state/takumi/reminders.tsv   id, remind or timer, moment, made, words (tab-separated)
~/.cache/takumi/weather.json      the last forecast for Today's place
```

Both settings files are written whole by the commands, like `power.toml`.

## Not yet

- **The resting Core and the Lock** still show `HH:mm`: they do not read the
  format yet. Today does.
- **Shell rows**: the Palette runs `commands/palette/time` only once it is
  registered in `shell/Core/Providers.qml`.
- **At login**, nothing runs `takumi remind restore` yet, so reminders outlive
  a restart in the list but ring only once restored.
- **The dispatcher script** is not installed by an install step yet.
- A city name only finds the places in tzdata's table or Open-Meteo's search;
  a street address does not.
- A VPN that sends everything through another country turns the lookup off
  rather than guessing.
- Reminders that repeat ("every Monday").

## Testing

`test/time` runs on any machine with fake timedated, systemd-run, systemctl,
curl, NetworkManager and notify-send, and a small zone table: words to moments
either way round, timer lengths, places by city, country and zone name, the
time zone set without and then with a password, a town found on Open-Meteo, the
conversations' lines in the Core, the format, clocks for other cities, the time
zone by location (once per network, never within five minutes, never with a
VPN, never when off), the dispatcher asking only the person who turned it on,
reminders and timers with their systemd timers, "Again in 10 min", restoring at
login, the weather line from canned Open-Meteo answers, the kept forecast, and
every row the Palette shows.

The code: `lib/clock.sh`, `lib/weather.sh`, `commands/clock/*`,
`commands/remind/*`, `commands/timer/*`, `commands/weather/*`,
`commands/palette/time`, `default/networkmanager/dispatcher.d/90-takumi-clock`
and `shell/Core/Today.qml`.
