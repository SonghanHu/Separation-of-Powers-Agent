# OpenClaw, But With Checks and Balances

This repo turns OpenClaw into a small government.

Not the annoying kind. The useful kind.

Instead of one giant agent doing everything badly with great confidence, this setup splits work into roles:

- `main` is your everyday lobster
- `secretary` is the operator and traffic controller
- `legislature` writes the rules
- `executive` makes the plan and does the work
- `judiciary` reviews what happened and tells everyone to behave

The result is a multi-agent system that is easier to inspect, easier to debug, and much harder to let quietly go off the rails.

## Why This Exists

Single-agent systems are fun right up until they:

- misunderstand the task
- confidently improvise the wrong thing
- execute before reviewing
- lose track of context
- make it impossible to see who did what

This project is the opposite of that.

It gives you:

- a practical OpenClaw deployment
- a separation-of-powers workflow for serious tasks
- a readable task dashboard for sessions, tool calls, and flows
- a cleaner session model where each new conversation can be its own session

## The Cast

| Agent | Job |
|-------|-----|
| `main` | General assistant for webchat, Discord, WhatsApp, cron, and direct use |
| `secretary` | Breaks down a request, routes work, enforces workflow discipline |
| `legislature` | Defines policy, constraints, scope, and acceptance criteria |
| `executive` | Produces plans and executes approved work |
| `judiciary` | Reviews plans and outcomes with `APPROVE`, `MODIFY`, or `DENY` |

## How Work Flows

For structured work, the `secretary` uses `sessions_spawn` to run a task through a pipeline:

1. `legislature` drafts the policy
2. `executive` drafts the plan
3. `judiciary` reviews the plan
4. repair loop if needed
5. `executive` executes
6. `judiciary` performs final review

Every spawned phase uses the same `flowId`, formatted like:

```text
[flow:yyyyMMdd-HHmmss-xxxx] Executive: Plan Draft - TASK_TITLE
```

That shared `flowId` is what lets the dashboard reconstruct one task as one coherent flow instead of a pile of unrelated sessions.

## What You Get

### 1. OpenClaw Gateway

This repo packages a working OpenClaw gateway with a bunch of useful tooling already wired in:

- Docker-based deployment
- MiniMax M2.5 by default
- Brave Search
- Gmail support via `gog`
- WhatsApp support
- Discord support
- GitHub CLI
- Go, LaTeX, ffmpeg, Homebrew, and other nice extras

### 2. Task Progress Dashboard

There is a read-only dashboard at `http://localhost:3080` that shows what the system is actually doing.

It is useful when you want to answer questions like:

- Which agent touched this task?
- What tools were called?
- Did this come from the Secretary flow or from main directly?
- Why are these sessions grouped together?
- What happened in Discord versus webchat?

The dashboard separates flows into:

- `Separation of Powers System`
- `Lobster Main System`

It also:

- groups Secretary-led work by `flowId`
- shows per-session tool timelines
- exposes global tool activity
- gives synthetic `flowId`s to `main` sessions so they still show up as proper flows

### 3. Cleaner Session Behavior

Current working model:

- new conversation = new session
- session transcripts are history, not long-term memory
- long-lived user context belongs in `USER.md`
- task artifacts belong in workspace files and `pipeline/`

This keeps the system easier to reason about than one infinitely-growing mega-chat.

## Quick Start

### 1. Clone and create `.env`

```bash
git clone <your-repo>
cd openclaw
cp .env.example .env
```

Fill in at least:

- `OPENCLAW_GATEWAY_TOKEN`
- `OPENCLAW_CONFIG_DIR`
- `OPENCLAW_WORKSPACE_DIR`
- `MINIMAX_API_KEY`

Optional but useful:

- `BRAVE_API_KEY`
- Gmail / Discord related keys

### 2. Run base setup

```bash
./setup.sh
```

This will:

- create `.env` if missing
- generate a token
- create `.openclaw-data/`
- build the Docker image
- start the services

After setup, you should have:

- control console on `http://localhost:18789/?token=<YOUR_TOKEN>`
- task progress on `http://localhost:3080`

### 3. Create the multi-agent system

```bash
./setup-agents.sh
```

This script:

- creates `secretary`, `legislature`, `executive`, and `judiciary`
- deploys `SOUL.md`, `IDENTITY.md`, and `USER.md`
- configures sub-agent permissions
- restarts the gateway

## First Things To Open

### Talk to the Secretary

Use this when you want the full structured workflow:

```text
http://localhost:18789/chat?session=agent%3Asecretary%3Amain
```

### Talk to Main

Use this for regular chat, Discord-like use, or direct experimentation:

```text
http://localhost:18789/chat?session=agent%3Amain%3Amain
```

### Watch the Dashboard

```text
http://localhost:3080
```

## New Session / Switch Session

If you want a fresh `main` session:

- use the control UI's `New session` button
- or send `/new`
- or send `/reset`

If you want to switch sessions:

- use the control UI session list if available
- or change the `session=` URL parameter directly

Examples:

- `agent%3Amain%3Amain`
- `agent%3Asecretary%3Amain`
- `agent%3Amain%3Adiscord%3Achannel%3A123`

## Task Progress Dashboard

The dashboard is intentionally read-only. It reads `.openclaw-data` and reconstructs activity from session metadata and transcripts.

### Tabs

- `Dashboard`: grouped flows, per-session tool activity, filters, system split
- `Pipeline`: Secretary spawn phases
- `Global Tool Flow`: raw tool activity across agents

### APIs

- `GET /api/sessions`
- `GET /api/pipeline`
- `GET /api/tools`
- `GET /api/health`

### Restart After Frontend Changes

Because the container copies the app into `/tmp/app` on startup, frontend/backend dashboard changes should be reloaded with:

```bash
docker compose up -d --force-recreate task-progress
```

Yes, `--force-recreate` matters here.

## Project Structure

```text
docker-compose.yml          # gateway + task-progress
Dockerfile                  # custom OpenClaw image
setup.sh                    # base setup
setup-agents.sh             # multi-agent setup
ARCHITECTURE.md             # architecture notes
task-progress/              # dashboard backend + frontend
docs/                       # design notes
templates/agents/           # prompts and identities
my_info/                    # your mounted reference files
.env.example                # environment template
```

## Customize It

### Change the default model

```bash
docker compose exec openclaw-gateway openclaw config set agents.defaults.model minimax/MiniMax-M2.5
docker compose restart openclaw-gateway
```

### Edit agent behavior

Update:

- `templates/agents/*_SOUL.md`
- `templates/agents/*_IDENTITY.md`
- `templates/agents/USER.md`

Then re-run:

```bash
./setup-agents.sh
```

You can also edit runtime copies under `.openclaw-data/workspace-*` directly if you want immediate local changes.

## Security Notes

- `.env`, `.openclaw-data/`, `.gog-auth/`, and other secrets are git-ignored
- the control console is token-protected
- the task-progress dashboard is read-only
- owner-only configuration rules are enforced in `USER.md`

## If You Like Metaphors

This repo is basically:

- one lobster
- one chief of staff
- three branches of government
- one surveillance room full of timelines

Surprisingly effective.

## License

MIT
