#!/usr/bin/env bash
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

CONTAINER="openclaw-gateway"
DATA_DIR="${OPENCLAW_CONFIG_DIR:-./.openclaw-data}"
AGENTS=(legislature executive judiciary secretary)
MODEL="minimax/MiniMax-M2.5"

docker compose ps --format json | grep -q "$CONTAINER" || error "Container '$CONTAINER' is not running. Run 'docker compose up -d' first."

info "=== Multi-Agent Architecture Setup ==="
echo ""

# --- Create agents ---
EXISTING=$(docker compose exec "$CONTAINER" openclaw agents list --json 2>/dev/null | grep '"id"' | sed 's/.*"id": "\(.*\)".*/\1/' || true)

for agent in "${AGENTS[@]}"; do
  if echo "$EXISTING" | grep -q "^${agent}$"; then
    info "Agent '$agent' already exists, skipping creation."
  else
    info "Creating agent: $agent ..."
    docker compose exec "$CONTAINER" openclaw agents add "$agent" \
      --model "$MODEL" \
      --non-interactive \
      --workspace "/home/node/.openclaw/workspace-${agent}" 2>&1 | tail -1
  fi
done

# --- Create workspace directories on host ---
info "Creating workspace directories..."
for agent in "${AGENTS[@]}"; do
  mkdir -p "$DATA_DIR/workspace-${agent}"
done
mkdir -p "$DATA_DIR/workspace/pipeline"

# --- Copy templates ---
info "Deploying SOUL.md, IDENTITY.md, USER.md templates..."
for agent in "${AGENTS[@]}"; do
  WS="$DATA_DIR/workspace-${agent}"

  if [ ! -f "$WS/SOUL.md" ] || [ "$WS/SOUL.md" -ot "templates/agents/${agent}_SOUL.md" ]; then
    cp "templates/agents/${agent}_SOUL.md" "$WS/SOUL.md"
  fi

  if [ ! -f "$WS/IDENTITY.md" ] || [ "$WS/IDENTITY.md" -ot "templates/agents/${agent}_IDENTITY.md" ]; then
    cp "templates/agents/${agent}_IDENTITY.md" "$WS/IDENTITY.md"
  fi

  if [ ! -f "$WS/USER.md" ]; then
    cp "templates/agents/USER.md" "$WS/USER.md"
  fi

  # Symlink shared directories
  [ -L "$WS/my_info" ] || [ -d "$WS/my_info" ] || ln -sf "$DATA_DIR/workspace/my_info" "$WS/my_info" 2>/dev/null || true
  [ -L "$WS/pipeline" ] || [ -d "$WS/pipeline" ] || ln -sf "$DATA_DIR/workspace/pipeline" "$WS/pipeline" 2>/dev/null || true
done

# --- Copy models.json from main to all agents ---
info "Syncing model configuration..."
MAIN_MODELS="$DATA_DIR/agents/main/agent/models.json"
if [ -f "$MAIN_MODELS" ]; then
  for agent in "${AGENTS[@]}"; do
    AGENT_MODELS="$DATA_DIR/agents/${agent}/agent/models.json"
    if [ -f "$AGENT_MODELS" ]; then
      cp "$MAIN_MODELS" "$AGENT_MODELS"
    fi
  done
fi

# --- Set identities ---
info "Setting agent identities..."
docker compose exec "$CONTAINER" openclaw agents set-identity --agent legislature --name "Legislature" --emoji "🏛️" 2>&1 | tail -1
docker compose exec "$CONTAINER" openclaw agents set-identity --agent executive --name "Executive" --emoji "⚙️" 2>&1 | tail -1
docker compose exec "$CONTAINER" openclaw agents set-identity --agent judiciary --name "Judiciary" --emoji "⚖️" 2>&1 | tail -1
docker compose exec "$CONTAINER" openclaw agents set-identity --agent secretary --name "Secretary" --emoji "📋" 2>&1 | tail -1

# --- Configure sub-agent permissions ---
info "Configuring sub-agent permissions..."
CONFIG="$DATA_DIR/openclaw.json"

if [ -f "$CONFIG" ]; then
  docker compose exec "$CONTAINER" node -e "
    const fs = require('fs');
    const cfg = JSON.parse(fs.readFileSync('/home/node/.openclaw/openclaw.json', 'utf8'));

    if (!cfg.agents.defaults.subagents) {
      cfg.agents.defaults.subagents = {
        maxSpawnDepth: 2,
        maxChildrenPerAgent: 5,
        maxConcurrent: 8,
        runTimeoutSeconds: 900
      };
    }

    for (const a of cfg.agents.list) {
      if (a.id === 'main' && !a.subagents) {
        a.subagents = { allowAgents: ['*'] };
      }
      if (a.id === 'secretary' && !a.subagents) {
        a.subagents = { allowAgents: ['legislature', 'executive', 'judiciary'] };
      }
    }

    fs.writeFileSync('/home/node/.openclaw/openclaw.json', JSON.stringify(cfg, null, 2));
    console.log('Sub-agent permissions configured.');
  " 2>&1
fi

# --- Restart ---
info "Restarting gateway..."
docker compose restart "$CONTAINER" 2>&1 | tail -1

echo ""
info "=== Setup Complete ==="
echo ""
echo "  Agents created:"
echo "    🦞 main        — Default assistant"
echo "    📋 secretary   — Orchestrator (spawns sub-agents)"
echo "    🏛️  legislature — Policy Maker"
echo "    ⚙️  executive   — Planner / Doer"
echo "    ⚖️  judiciary   — Independent Reviewer"
echo ""
echo "  Access Secretary via Dashboard:"
echo "    http://localhost:18789/chat?session=agent%3Asecretary%3Amain"
echo ""
echo "  Next steps:"
echo "    1. Edit each workspace's USER.md with your info"
echo "    2. Open Secretary session and give it a task"
echo "    3. See ARCHITECTURE.md for the full design"
echo ""
