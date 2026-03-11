# Multi-Agent Architecture

This project implements a **separation-of-powers** multi-agent system on top of OpenClaw, inspired by legislative / executive / judiciary branches.

## Agents

| Agent | Emoji | Role | Purpose |
|-------|-------|------|---------|
| **main** | 🦞 | Default Assistant | General-purpose — job hunting, networking, daily tasks |
| **secretary** | 📋 | Orchestrator | Hanson's representative; coordinates the three branches via sub-agent spawning |
| **legislature** | 🏛️ | Policy Maker | Translates tasks into enforceable policy, constraints, and acceptance criteria |
| **executive** | ⚙️ | Planner / Doer | Proposes step-by-step plans and executes after approval |
| **judiciary** | ⚖️ | Reviewer | Reviews plans for compliance, risk, and evidence |

## Interaction Protocol

```
┌─────────┐
│  User   │
└────┬────┘
     │ task
     ▼
┌──────────┐   spawn    ┌─────────────┐
│ Secretary ├──────────►│ Legislature  │
│    📋     │◄──────────┤     🏛️       │
│           │  policy    └─────────────┘
│           │
│           │   spawn    ┌─────────────┐
│           ├──────────►│  Executive   │
│           │◄──────────┤     ⚙️       │
│           │   plan     └─────────────┘
│           │
│           │   spawn    ┌─────────────┐
│           ├──────────►│  Judiciary   │
│           │◄──────────┤     ⚖️       │
│           │  verdict   └─────────────┘
│           │
│           │  (loop if MODIFY)
│           │
└─────┬────┘
      │ summary
      ▼
┌─────────┐
│  User   │
└─────────┘
```

### Phase Flow

| Phase | Actor | Action | Output |
|-------|-------|--------|--------|
| A | Legislature | Draft policy from task description | POLICY document |
| B | Executive | Draft plan complying with policy | PLAN document |
| C | Judiciary | Review plan against policy | VERDICT: APPROVE / DENY / MODIFY |
| D | Executive | Revise plan (if MODIFY) | Updated PLAN |
| E | Executive | Execute approved plan | EXECUTION LOG with evidence |
| F | Judiciary | Final review of results | FINAL REVIEW: PASS / FAIL / PARTIAL |

## Technical Implementation

### Sub-Agent Spawning

The Secretary uses OpenClaw's `sessions_spawn` tool to delegate work:

```json
{
  "agentId": "legislature",
  "task": "Draft a POLICY for: [task description]",
  "label": "Legislature: Policy Draft"
}
```

Sub-agents run in isolated sessions. When finished, results are automatically announced back to the Secretary.

### Configuration (openclaw.json)

```json
{
  "agents": {
    "defaults": {
      "subagents": {
        "maxSpawnDepth": 2,
        "maxChildrenPerAgent": 5,
        "maxConcurrent": 8,
        "runTimeoutSeconds": 900
      }
    },
    "list": [
      {
        "id": "main",
        "subagents": { "allowAgents": ["*"] }
      },
      {
        "id": "secretary",
        "workspace": "/path/to/workspace-secretary",
        "subagents": {
          "allowAgents": ["legislature", "executive", "judiciary"]
        }
      },
      {
        "id": "legislature",
        "workspace": "/path/to/workspace-legislature"
      },
      {
        "id": "executive",
        "workspace": "/path/to/workspace-executive"
      },
      {
        "id": "judiciary",
        "workspace": "/path/to/workspace-judiciary"
      }
    ]
  }
}
```

### Automated Setup

After `./setup.sh` completes the basic deployment, run:

```bash
./setup-agents.sh
```

This script automatically:
1. Creates all 4 agents (legislature, executive, judiciary, secretary)
2. Sets up separate workspace directories
3. Deploys SOUL.md, IDENTITY.md, USER.md from templates
4. Copies model configuration from the main agent
5. Sets agent identities and emojis
6. Configures sub-agent spawn permissions
7. Restarts the gateway

Templates live in `templates/agents/` and can be customized before running the script.

### Workspace Isolation

Each agent has its own workspace directory to prevent SOUL.md and IDENTITY.md conflicts:

```
.openclaw-data/
├── workspace/                  # main agent
├── workspace-secretary/        # secretary (orchestrator)
├── workspace-legislature/      # legislature
├── workspace-executive/        # executive
└── workspace-judiciary/        # judiciary
```

Shared resources (e.g., `my_info/`, `pipeline/`) are symlinked into each workspace.

### Key Files Per Agent

| File | Purpose |
|------|---------|
| `SOUL.md` | Agent personality, behavior rules, output schemas |
| `IDENTITY.md` | Name, emoji, role description |
| `USER.md` | Information about the user (shared across agents) |

## Global Safety Rules

These rules are embedded in every agent's SOUL.md:

1. No agent may claim to have performed an action unless explicitly shown in the transcript
2. All outputs must use structured schemas
3. Missing information → smallest necessary assumptions, labeled as ASSUMPTIONS
4. Deny any step that could cause irreversible harm, privacy violation, security breach, or uncontrolled side effects
5. Prefer minimal-risk plans: smallest set of actions that achieves the task

## Access Control

- **Only the owner (Hanson)** can modify settings, configurations, or agent behavior
- Other WhatsApp contacts can chat but have zero admin privileges
- This is enforced in `USER.md` across all agent workspaces

## Using the System

### Via Dashboard

Navigate to the Secretary's session:

```
http://localhost:18789/chat?session=agent%3Asecretary%3Amain&token=YOUR_TOKEN
```

Give it a task and it will automatically orchestrate the three branches.

### Via Main Agent

The main agent (🦞) can also spawn sub-agents directly since `allowAgents: ["*"]`.

### Direct Agent Access

Each agent can be accessed directly via URL:

```
/chat?session=agent%3A{AGENT_ID}%3Amain
```

Replace `{AGENT_ID}` with: `main`, `secretary`, `legislature`, `executive`, `judiciary`.
