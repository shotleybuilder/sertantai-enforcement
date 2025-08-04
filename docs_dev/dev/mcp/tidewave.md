# Tidewave MCP Setup for EHS Enforcement

Tidewave is an AI assistant that understands your web application, how it runs, and what it delivers. It connects your editor's assistant to your Phoenix framework runtime via MCP (Model Context Protocol).

## Current Status
- ✅ **Dependency added**: `{:tidewave, "~> 0.1", only: [:dev]}` is in `mix.exs`
- ❌ **Not configured**: Tidewave plug is missing from the Phoenix endpoint
- ❌ **Route not available**: `/tidewave/mcp` endpoint doesn't exist

## Steps to Enable Tidewave MCP

### 1. Add Tidewave Plug to Phoenix Endpoint

Edit `/lib/ehs_enforcement_web/endpoint.ex` and add the Tidewave plug **right above** the `if code_reloading? do` block:

```elixir
# Add this block above the code_reloading check
if Code.ensure_loaded?(Tidewave) do
  plug Tidewave
end

if code_reloading? do
  # existing code...
```

### 2. Install Dependencies

```bash
mix deps.get
```

### 3. Start Phoenix Server

```bash
mix phx.server
```

After this setup, Tidewave MCP will be available at:
```
http://localhost:4000/tidewave/mcp
```

### 4. Optional: Install MCP Proxy (for Claude Desktop)

For editors like Claude Desktop that need MCP proxy:

```bash
# Install the MCP proxy
mix archive.install hex igniter_new
mix igniter.install tidewave
```

Or manually install the proxy and configure Claude Desktop:

```json
{
  "mcpServers": {
    "ehs-enforcement": {
      "command": "/path/to/escript",
      "args": ["/path/to/mcp-proxy", "http://localhost:4000/tidewave/mcp"]
    }
  }
}
```

### Configuration Options

You can configure Tidewave with options:

```elixir
if Code.ensure_loaded?(Tidewave) do
  plug Tidewave, 
    allow_remote_access: false,  # localhost only
    autoformat: true,           # auto-format Elixir files
    tools: %{
      include: nil,  # include all tools
      exclude: []    # exclude specific tools
    }
end
```

## Features

Once configured, you'll have access to Runtime Intelligence that understands:
- Phoenix application structure
- Routes and LiveViews
- Database models and schemas
- Test files and coverage
- Development workflow

## Testing Access

After setup, test Tidewave MCP availability:

```bash
# Check if MCP endpoint is available
curl http://localhost:4000/tidewave/mcp

# Access via the CLAUDE.md instructions
/home/jason/mcp-proxy http://localhost:4000/tidewave/mcp
```

## Resources

- [Tidewave Phoenix GitHub](https://github.com/tidewave-ai/tidewave_phoenix)
- [MCP Proxy Setup](https://github.com/tidewave-ai/tidewave_phoenix/blob/main/pages/guides/mcp_proxy.md)
- [Installation Guide](https://github.com/tidewave-ai/tidewave_phoenix/blob/main/pages/installation.md)
- [Hex Documentation](https://hexdocs.pm/tidewave/installation.html)