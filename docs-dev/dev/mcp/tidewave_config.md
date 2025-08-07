# Tidewave MCP Configuration Guide

This document summarizes the Tidewave MCP setup for Phoenix projects and lessons learned from troubleshooting connection issues.

## Overview

Tidewave MCP (Model Context Protocol) provides runtime intelligence for Phoenix applications, allowing Claude Code to understand your application structure, routes, LiveViews, database models, and development workflow.

## Key Learnings

### 1. Tidewave MCP Runs Inside Your Phoenix App
- **Tidewave is a Phoenix plug** that runs as part of your application
- **MCP endpoint is available at** `http://localhost:{PORT}/tidewave/mcp` where PORT is your Phoenix app's port
- **Not a separate service** - it's embedded in your Phoenix application via the Tidewave dependency

### 2. Connection Method Matters
- **Direct SSE connections fail** with Claude Code due to protocol mismatches
- **Use `stdio` with mcp-proxy** for reliable connections
- **Never use `"type": "sse"`** - causes "Dynamic client registration failed: HTTP 404" errors

### 3. Port Management for Multiple Projects
- **Each Phoenix project needs its own port** to avoid conflicts when running concurrently
- **MCP configuration follows the Phoenix app port**
- **Use project-specific configurations** for different ports

## Configuration Structure

### Global Configuration
**File**: `~/.claude/mcpServers.json`
```json
{
  "tidewave": {
    "type": "stdio",
    "command": "/home/jason/mcp-proxy",
    "args": [
      "http://localhost:4000/tidewave/mcp"
    ],
    "env": {}
  }
}
```

### Project-Specific Overrides
**File**: `{PROJECT_ROOT}/.mcp.json`

**⚠️ CRITICAL**: The `.mcp.json` file MUST have `mcpServers` as the root key to pass schema validation.

```json
{
  "mcpServers": {
    "tidewave": {
      "type": "stdio",
      "command": "/home/jason/mcp-proxy",
      "args": [
        "http://localhost:4002/tidewave/mcp"
      ],
      "env": {}
    }
  }
}
```

## Port Allocation Strategy

| Project | Port | MCP Endpoint | Configuration |
|---------|------|-------------|---------------|
| Sertantai | 4000 | `localhost:4000/tidewave/mcp` | Global config |
| EHS Enforcement | 4002 | `localhost:4002/tidewave/mcp` | Project-specific |
| Future Projects | 4000 (default) | `localhost:4000/tidewave/mcp` | Global config |

## Phoenix Configuration

Update `config/dev.exs` to set your project's port:
```elixir
config :your_app, YourAppWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4002")],
```

## Troubleshooting Common Issues

### Issue: "Does not adhere to MCP server configuration schema"
**Cause**: Missing `mcpServers` root key in `.mcp.json` file
**Solution**: Wrap server configurations in `mcpServers` object:
```json
{
  "mcpServers": {
    "your-server": { ... }
  }
}
```

### Issue: "Dynamic client registration failed: HTTP 404"
**Cause**: Using `"type": "sse"` instead of `"type": "stdio"`
**Solution**: Always use stdio with mcp-proxy

### Issue: "Initialization timeout after 30 seconds"
**Cause**: Protocol mismatch between Claude Code MCP client and Tidewave
**Solution**: Use the mcp-proxy wrapper instead of direct connections

### Issue: Port conflicts when running multiple Phoenix apps
**Cause**: Multiple apps trying to use the same port
**Solution**: Use project-specific `.mcp.json` files with different ports

### Issue: Large `.claude.json` file
**Cause**: MCP configurations embedded in conversation history
**Solution**: Use external MCP files (global `mcpServers.json` + project-specific `.mcp.json` overrides)

## Configuration Hierarchy

1. **Project-specific** `.mcp.json` (highest priority)
2. **Global** `~/.claude/mcpServers.json` (fallback)
3. **Embedded** in `.claude.json` (deprecated, causes bloat)

## Setup Checklist for New Projects

- [ ] Add Tidewave dependency to `mix.exs`
- [ ] Configure Tidewave plug in Phoenix endpoint
- [ ] Set unique port in `config/dev.exs` if needed
- [ ] Create project-specific `.mcp.json` if using non-standard port
- [ ] Test MCP connection with `/mcp` command in Claude Code
- [ ] Verify Tidewave endpoint responds: `curl http://localhost:{PORT}/tidewave/mcp`

## Dependencies Required

```elixir
# mix.exs
{:tidewave, "~> 0.2", only: [:dev]}
```

```elixir
# lib/your_app_web/endpoint.ex
if Code.ensure_loaded?(Tidewave) do
  plug Tidewave
end
```

## Benefits of Proper Configuration

- **Runtime Intelligence**: Understanding of Phoenix app structure
- **Multiple Projects**: Can run several Phoenix apps simultaneously
- **Clean Configuration**: MCP settings separate from conversation history
- **Reliable Connections**: No timeout or protocol issues
- **Port Flexibility**: Easy to adapt for different project needs

## File Locations Summary

- **Global MCP Config**: `~/.claude/mcpServers.json`
- **Project MCP Override**: `{PROJECT_ROOT}/.mcp.json`
- **Phoenix Port Config**: `config/dev.exs`
- **MCP Proxy**: `/home/jason/mcp-proxy` (shared across projects)
- **Conversation History**: `~/.claude.json` (should be much smaller now)