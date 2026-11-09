# Development

A computer for writing code is a few rows in the Core, each a conversation:
a language, containers, Git and GitHub, and a coding agent. Nothing here
asks for a terminal, and everything works from one too.

## Languages

"Set up a language for coding" asks which: Node.js, Python, Ruby, Go, Rust,
Java or PHP. `takumi dev node` (or `python`, `ruby`, `go`, `rust`, `java`,
`php`) skips the question. The Core then says "Node.js 24.11.1 is ready. Open
a new terminal to use it."

Languages come through [mise](https://mise.jdx.dev), which keeps every
version in your home folder: no password, nothing in the system's `/usr`,
nothing an update or a rollback touches, and a project's own versions
(`.mise.toml`, `.tool-versions`, `.nvmrc`) used inside it. When mise is not
there yet, the Core asks once and gets it from its makers
(`https://mise.run`, into `~/.local/bin`).

| Word | Through mise |
|---|---|
| node | `node@lts` |
| python | `python@latest` |
| ruby | `ruby@latest`, built on the computer, which takes a few minutes; Arch's `libyaml` first, with your password |
| go | `go@latest` |
| rust | `rust@stable` |
| java | `java@temurin-25`, the current long-term Java |

PHP comes from Arch's packages instead (`php` and `composer`, with your
password), because mise builds PHP from source, which needs a dozen
libraries and a long wait.

Terminals find the versions through mise's hook, added once to your shell's
settings (`~/.bashrc`, `~/.zshrc`, or fish's `conf.d`), which switches
versions as you enter a project. Apps started from the Core, an editor for
one, find them through mise's shims, from your next login
(`~/.config/environment.d/60-takumi-mise.conf`).

## Containers

"Set up containers" (`takumi dev containers`, and `takumi install docker`)
gives you Podman, rootless: containers run as you. `docker` and
`docker compose` work through it (`podman-docker`, unless Docker's own
command is already installed, and `docker-compose`), and Podman's socket
answers for every tool that speaks to Docker (`DOCKER_HOST`, from your next
login). Takumi does not add you to the docker group, because anyone in it
can become root without a password.

The password is asked once, for the packages, and once more only if you have
no range of user IDs of your own (`/etc/subuid`, `/etc/subgid`), which
rootless containers need.

## Git and GitHub

"Set up Git and GitHub" asks your name, offering the one on your account,
and your email, asking again when it cannot be one. Both go in
`~/.gitconfig`, with `main` as a new repository's first branch unless you
chose another.

Then "Sign in to GitHub too?" GitHub's own tool (`gh`, installed with your
password when it is missing) signs you in through the browser. In the Core
the one-time code is a card: the code in large type, and a square a phone
can scan to do it there. The browser opens on GitHub's page for the code,
`gh` waits in the background, and a notice says "Signed in to GitHub · as
octocat: git uses it to push" (`gh auth setup-git`). At a terminal, `gh`
signs you in right there.

## Coding agents

"Open Claude Code", "Open Codex" and "Open OpenCode" open the agent in a
terminal window (yours: `takumi app default terminal`), in `~/Work`, so what
it makes lands in one folder. The first time, the Core asks before
installing it:

| Agent | Installed from |
|---|---|
| Claude Code | Anthropic's installer ([setup](https://code.claude.com/docs/en/setup)), into `~/.local/bin`, no password |
| Codex | Arch's `openai-codex` package, with your password |
| OpenCode | Arch's `opencode` package, with your password |

Each agent signs you in the first time it runs, in its own window. Typed at
a terminal, `takumi agent open claude` runs the agent right there, in
`~/Work`. `takumi install agents` installs all three at once.

## Commands

```
takumi dev [node|python|ruby|go|rust|java|php]
takumi dev containers
takumi dev git
takumi agent open <claude|codex|opencode>
takumi agent claude | codex | opencode      the same, as rows of their own
takumi install agents
takumi install docker                       takumi dev containers
```

Each is a conversation (`lib/core.sh`): in the Core it asks in the field, at
a terminal it prompts, fed by a pipe it reads answers a line at a time. The
last line says what happened in words; the exit status says it for scripts:
0 done · 2 not a language or not an agent · 3 an answer was needed and none
came, or no · 1 anything else.

## Not yet

- Databases in containers, ready to use (PostgreSQL, MySQL, Redis).
- Each language's version chosen in the Core; mise's own commands choose
  them today (`mise use node@22`).
- An agent opened here is not given Takumi's MCP server (`takumi mcp
  serve`), which would let it change the system through Takumi's commands
  and their approvals.

## Testing

`test/dev` runs on any machine with fake `mise`, `git`, `gh`, `pacman`,
`podman` and terminals, and only basic tools besides: each language and
what it asks, the hook written once, PHP from Arch, containers that never
touch the docker group, a name and an email asked again when wrong, the
one-time code as a card and the notice when you are signed in, and each
agent installed its own way and opened in `~/Work`.

The code: `commands/dev/*`, `commands/agent/*`, and the agents' part of
`lib/apps.sh`.
