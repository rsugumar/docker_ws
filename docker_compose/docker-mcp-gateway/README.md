# Docker MCP Gateway

Runs the Docker MCP Gateway as a persistent container, exposing GitHub, Brave
Search, Redis, Playwright, Docker Hub, and Desktop Commander via SSE on port 8811.

## Prerequisites

- Docker Engine 24+ (CE or Desktop)
- MCP Toolkit config at `~/.docker/mcp/` (catalogs, config.yaml, registry.yaml, tools.yaml)
- Secrets file at `~/.docker/mcp/secrets.env`

## Secrets file format

```env
github.personal_access_token=ghp_...
dockerhub.pat_token=dckr_pat_...
brave.api_key=BSA...
```

## Usage

```bash
# Start (detached, auto-restarts on reboot)
docker compose up -d

# Follow logs
docker compose logs -f

# Stop
docker compose down

# Restart
docker compose restart
```

## Verify

```bash
# Health check
curl http://localhost:8811/health

# List available tools
curl http://localhost:8811/sse
```

## OpenCode integration

Already configured in `~/.config/opencode/opencode.jsonc`:

```jsonc
"docker-mcp-gateway": {
  "type": "remote",
  "url": "http://localhost:8811/sse",
  "disabled": false
}
```

