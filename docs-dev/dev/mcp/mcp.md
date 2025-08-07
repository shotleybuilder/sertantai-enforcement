## Tidewave

```claude mcp add --transport sse tidewave http://localhost:$4000/tidewave/mcp```

## Usage Rules

```mix igniter.install usage_rules```

```mix usage_rules.sync CLAUDE.md --all \
    --inline usage_rules:all \
    --link-to-folder deps```

```mix usage_rules.sync CLAUDE.md ash phoenix --link-to-folder docs --link-style at```
