# Intent

Intent is Takumi's assistant. You type a sentence into the Core and it does
the work with Takumi's own commands, the ones the Palette and `takumi` run.
It has no shell, no files and no web. Anything above risk tier 0 waits until
you say yes, once, with every line it would run named.

Intent needs a model: Claude through Claude Code and your Claude account,
Claude through an Anthropic API key, or OpenAI's GPT through an OpenAI API
key. Nothing is sent anywhere until you choose one.

## What you see

A sentence with a space in it adds a row at the bottom of the Palette: the
sentence itself, "Ask Intent". After three words and a pause, a "Will run"
line above the field shows the exact lines Intent would run first
(`takumi intent --plan`). Each preview asks the model, so
`intent_preview = false` in `~/.config/takumi/shell.toml` turns it off.

Enter on "Ask Intent", or Enter when nothing matches, asks it as a
conversation in the Core:

1. The row says what is happening: "Thinking…", then each command as it
   starts, "takumi switch bluetooth…".
2. Risk 0 commands run at once, and the model reads what they print. One
   that asks something asks you right there, as it would from the Palette:
   "Keep this?" after the screen changes, or a Wi-Fi password, which the
   model never sees.
3. When the model is done and wants something riskier, one question names
   every line: "Run takumi install docker, then takumi power restart?"
   Enter runs them in that order; Esc runs none. A command that talks, like
   `takumi install`, talks in the same place: its questions in the field, its
   password through the approval ([approvals.md](approvals.md)). One that
   needs a terminal opens in one.
4. The Core closes and says what happened, in a sentence or two: "Bluetooth
   is off. Installed Docker; it works for you after you log out and back in."

When something goes wrong the row says it in words: the assistant is not set
up, the key was refused, there is no internet, the model declined.

## Setting it up

Type "assistant" in the Palette. Each row is a conversation in the Core, and
the one in use says "In use". In the first week, the empty Palette's "Set up
the assistant" row searches for them.

| Row | Runs |
|---|---|
| Use Claude for the assistant | `takumi intent setup claude` |
| Use an Anthropic API key for the assistant | `takumi intent setup anthropic` |
| Use OpenAI for the assistant | `takumi intent setup openai` |

**Claude** uses Claude Code signed in with your Claude account, so a Claude
subscription works without a key. When Claude Code is missing it asks
"Install it from Anthropic?" and runs Anthropic's own installer
([setup](https://code.claude.com/docs/en/setup)), which puts `claude` in
`~/.local/bin` and needs no password. Claude Code installed another way
(`takumi install agents`) is found in PATH. When it is not signed in, one
question offers the sign-in: a terminal opens `claude auth login` and your
browser does the rest.

**An Anthropic API key** is asked for as a secret, checked by listing the
models it can use (a request that costs nothing), and kept. The model is
`claude-opus-5-5`.

**OpenAI** does the same with an OpenAI key, and picks the newest general GPT
model the key can use: a `gpt-5.x` first, then `gpt-5`, then `gpt-4.1`, never
a mini or a dated copy.

A key that does not work makes the field shake, and it asks again.

Keys live in the keyring (GNOME Keyring, through `secret-tool`) under
`service takumi-intent engine <name>`. With no keyring, a key goes in
`~/.local/state/takumi/intent/keys/<name>`, which only you can read. A key
reaches `secret-tool` and `curl` on stdin: it is never on a command line, in
the transcript or in a log.

`~/.config/takumi/intent.toml` holds what was chosen:

```toml
engine = "openai"          # claude, anthropic or openai
model = "gpt-5.2"          # empty: the engine's own (claude-opus-5-5, or Claude Code's choice)
endpoint = "https://api.openai.com/v1"   # optional: any service that speaks OpenAI's API
```

## The commands

| Command | Does |
|---|---|
| `takumi intent ask <request>` | the conversation above; `takumi intent <request>` is the same |
| `takumi intent --plan <request>` | prints the lines the model would run first as one JSON array, `["takumi switch bluetooth"]`; runs and writes nothing |
| `takumi intent setup [claude\|anthropic\|openai]` | sets it up; with no word, the engine in use, else Claude |
| `takumi intent model [model\|default]` | shows the model, or chooses another: `takumi intent model gpt-5.2` |
| `takumi mcp serve` | Takumi's commands as MCP tools, on stdin and stdout |

Exit statuses, for scripts. `ask` and `--plan`: 0 done, 2 no request, 3 not
set up, 4 the key or the sign-in was refused, 5 the service could not be
reached, 6 the model declined, 1 anything else; a failed plan prints nothing.
`setup`: 0 set up, 2 not an engine, 3 an answer was needed and none came (or
Claude Code is still missing or signed out), 4 the key did not work, 5 the
service could not be reached, 1 anything else. `model`: 0, 2 not a model
name, 3 not set up.

## How it works

**Tools.** Every command in `takumi --manifest` is a tool named
`<group>_<name>` (`switch_bluetooth`, `install_main`). Its input is
`{"args": [...]}` and its description is the command's summary, usage, risk
and examples. A call is checked before anything happens: the tool must exist,
`args` must be a list of strings with no control characters, and a command
with no usage takes none. Four kinds of command are never tools: Intent's
own, the MCP server, and `takumi wifi share` and `takumi disk recovery`,
which print a password or a recovery code that only ever goes to you.

**Risk.** Every command's ABOUT block declares its tier
([commands.md](commands.md)), and the Palette uses the same tier to decide
whether a row runs on Enter or asks.

| Tier | Meaning | Examples |
|---|---|---|
| 0 | reversible, local, no root | `theme set`, `switch bluetooth`, `audio volume` |
| 1 | installs or changes a service, root | `install docker`, `keys harmony off` |
| 2 | touches rooms, disks, boot | `update`, `rollback`, `room prune` |

Risk 0 runs at once. In the Core it can ask you what it needs and your answer
goes to it, never to the model; anywhere else nothing answers it (stdin is
empty, two minutes at most). The model reads what it printed, colours
removed, 4 KB at most. Risk 1 and 2 never run while the model works: the call
answers "needs the person's approval: takumi install docker", the line is
queued, and the model goes on. When it is done, one question names every
queued line; on yes they run in order where you can answer them, and the
first that fails stops the rest.

**Rounds.** At most eight. The model's last words are one or two plain
sentences about what it did; Intent adds what an approved command said last.

**Claude Code** runs as `claude -p` from `~/.local/state/takumi/intent`, the
request on stdin, with these flags from its
[CLI reference](https://code.claude.com/docs/en/cli-reference):

- a plan: `--output-format json --tools "" --system-prompt-file <prompt>
  --json-schema <schema> --no-session-persistence --strict-mcp-config`. No
  tools and no MCP servers; the plan is JSON checked against the schema.
- an answer: `--output-format json --tools "" --system-prompt-file <prompt>
  --mcp-config <file> --strict-mcp-config --allowedTools "mcp__takumi__*"
  --max-turns 8 --no-session-persistence`. The one MCP server is
  `takumi mcp serve`, with an events file in its environment
  (`TAKUMI_MCP_LOG`). It hands each risk 0 command back through that file to
  `takumi intent ask`, which runs it in the Core and answers in a reply file
  the server waits for, and it leaves there what waits for you, which becomes
  the question.
- `--model <model>` when intent.toml names one.

Claude Code's other settings for your account still apply; its tools and MCP
servers are only Takumi's.

**The Anthropic API**: `POST /v1/messages` over curl with
`anthropic-version: 2026-10-21`, `max_tokens` 16000, `tool_choice` auto, and
the effort set (`output_config`: low for a plan, medium for an answer);
thinking is left to the model. The system prompt is cached. With
`fallbacks: "default"` and the `server-side-fallback-2026-07-01` beta, a
request the model declines is answered by Anthropic's fallback model in the
same call. The whole answer, thinking included, goes back each round, and
all of a round's tool results go back in one message. A `refusal` stops with
"Claude declined that request"; a `max_tokens` stop runs none of that round's
tools.

**The OpenAI API**: `POST <endpoint>/chat/completions` with `tools` (function
calling), which services that copy OpenAI's API speak too. Each tool result
goes back as its own `tool` message.

A busy service, or none, is tried three times, two and four seconds apart; a
plan tries once.

## Takumi's tools in other MCP clients

`takumi mcp serve` speaks MCP over stdio, one JSON-RPC 2.0 message per line:
`initialize` (the client's protocol version when it is 2025-11-25,
2025-06-18, 2025-03-26 or 2024-11-05, else 2025-11-25),
`notifications/initialized`, `ping`, `tools/list` and `tools/call`. The tools
and the rule are the ones above: risk 0 runs with nothing to answer, and what
it printed is the result; risk 1 and 2 answer "needs the person's approval:
<the exact takumi line>" and run nothing. `TAKUMI_MCP_ALLOW_RISK=1` in the
server's environment runs them too, for a client that asks you itself.
Outside `takumi intent ask`, what the server ran or was asked for goes in the
transcript.

For a client that reads this form (Claude Code's `--mcp-config` does):

```json
{"mcpServers": {"takumi": {"command": "takumi", "args": ["mcp", "serve"]}}}
```

## Claude Code as a coding agent

Choosing Claude for the assistant also links Takumi's skill
(`default/coding-agents/takumi/SKILL.md`, installed in
`/usr/share/takumi/coding-agents/`) into `~/.claude/skills/takumi`, where
Claude Code looks for a person's own skills
([Claude Code: skills](https://code.claude.com/docs/en/skills)). A Claude Code
session you open yourself then knows to change this computer through `takumi`
commands, to ask before a risk 1 or 2 one, to leave sudo and system files
alone, and where the rooms and rollback are. A `takumi` folder of your own in
that place is left as it is.

## What is written down

`~/.local/state/takumi/intent/transcript.jsonl` gets one JSON line per event,
each with the time and the run's id: the request with the engine and model,
each command that ran with its exit status, what you were asked and your
answer, the last words, or why it stopped. Never a key, and never what a
command printed. A plan writes nothing. `install.log` beside it keeps what
Anthropic's installer said.

The model sees the request, the tools, and what the risk 0 commands it ran
printed: never your files, clipboard or shell history unless one of those
commands returns them.

## Not done

- No memory: every request starts fresh.
- Nothing runs on this computer: every engine is a service you sign in to or
  pay for with a key.
- At a terminal, or for an MCP client other than Intent, a risk 0 command
  that asks something gets no answer: a changed screen goes back.
- With Claude Code, the question about risky lines waits until Claude Code
  has finished.
- The notes say which command runs, not what the model is thinking.

## How it is tested

`test/intent` puts fake `claude`, `curl`, `secret-tool` and `foot` first in
PATH, in a small world of fake commands: risk 0, 1 and 2, one that asks
"Keep this?", one that talks, one that needs a terminal, two that print a
secret. It checks the plan's exact output on every engine; the agent on every
engine running risk 0 at once and asking once before anything risky; "Keep
this?" reaching you in the Core, through Claude Code too; what goes back to
the model each round; the request's model, effort, fallbacks and headers;
setup's conversations (a wrong key asked for again, the newest GPT model, no
keyring, Claude Code installed and signed in); the MCP server over a pipe; the
Palette's rows; and that no key appears in any argument, request, transcript
or log. Nothing reaches a network.

A real key and a real Claude Code sign-in are checked by hand: setting up
each engine, a plan, and an answer that runs a risk 0 command and asks before
a risky one.
