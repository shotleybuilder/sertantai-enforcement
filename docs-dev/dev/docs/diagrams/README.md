# EHS Enforcement Architecture Diagrams

This directory contains automatically generated diagrams for the EHS Enforcement application using the `ash_diagram` library.

## 📊 Available Diagrams

### Application-Wide Diagrams
- **[application-architecture.md](application-architecture.md)** - C4 architecture diagram showing complete system structure
- **[application-entity-relationship.md](application-entity-relationship.md)** - Full database schema and resource relationships across all domains

### Domain-Specific Diagrams

Each domain has its own `diagrams/` directory with Entity Relationship and Class diagrams:

#### Enforcement Domain (`docs-dev/dev/enforcement/diagrams/`)
- Resources: Case, Notice, Offender, Offence, Legislation, Agency, Metrics
- [Entity Relationship Diagram](../../enforcement/diagrams/enforcement-entity-relationship.md)
- [Class Diagram](../../enforcement/diagrams/enforcement-class.md)

#### Scraping Domain (`docs-dev/dev/scraping/diagrams/`)
- Resources: ScrapeSession, ProcessingLog, ScrapeRequest, ScrapedCase
- [Entity Relationship Diagram](../../scraping/diagrams/scraping-entity-relationship.md)
- [Class Diagram](../../scraping/diagrams/scraping-class.md)

#### Accounts Domain (`docs-dev/dev/accounts/diagrams/`)
- Resources: User, UserIdentity, Token
- [Entity Relationship Diagram](../../accounts/diagrams/accounts-entity-relationship.md)
- [Class Diagram](../../accounts/diagrams/accounts-class.md)

#### Configuration Domain (`docs-dev/dev/configuration/diagrams/`)
- Resources: ScrapingConfig
- [Entity Relationship Diagram](../../configuration/diagrams/configuration-entity-relationship.md)
- [Class Diagram](../../configuration/diagrams/configuration-class.md)

#### Events Domain (`docs-dev/dev/events/diagrams/`)
- Resources: Event
- [Entity Relationship Diagram](../../events/diagrams/events-entity-relationship.md)
- [Class Diagram](../../events/diagrams/events-class.md)

## 🔄 Regenerating Diagrams

### Generate All Diagrams

```bash
mix diagrams.generate
```

### Generate Specific Domain

```bash
mix diagrams.generate --domain enforcement
mix diagrams.generate --domain scraping
mix diagrams.generate --domain accounts
mix diagrams.generate --domain configuration
mix diagrams.generate --domain events
```

### Generate Specific Formats

```bash
# Mermaid markdown (default, best for documentation)
mix diagrams.generate --format mermaid

# PNG images (requires mmdc CLI or uses Mermaid.ink)
mix diagrams.generate --format png

# SVG images
mix diagrams.generate --format svg
```

## 📖 Diagram Types

### Entity Relationship Diagrams (ERD)
Show the relationships between Ash resources and how they connect through:
- Belongs-to relationships
- Has-many relationships
- Many-to-many relationships
- Resource attributes and types

**Use when**: Understanding data model structure, planning database queries, designing new features

### Class Diagrams
Show the structure of individual resources including:
- All attributes with types
- Available actions (create, read, update, destroy, custom)
- Calculations and aggregates
- Identity fields and constraints

**Use when**: Implementing features, understanding resource capabilities, reviewing authorization policies

### Architecture Diagrams (C4)
Show the high-level system structure including:
- All domains and their resources
- System boundaries and contexts
- Inter-domain dependencies

**Use when**: Onboarding new developers, planning major refactors, creating presentations

## ⏰ When to Regenerate

Diagrams should be regenerated:

- ✅ **After adding/modifying Ash resources** - Ensures diagrams reflect current schema
- ✅ **After changing resource relationships** - Updates ER diagrams with new associations
- ✅ **After updating actions or policies** - Reflects in class diagrams
- ✅ **Before creating documentation** - Ensures accuracy for guides and READMEs
- ✅ **Before presentations or demos** - Professional, up-to-date visualizations
- ⚠️  **During PR review** (optional) - Can help reviewers understand changes

## 🎯 Using Diagrams in Documentation

### Markdown Embedding

All diagrams are in Mermaid format and will render automatically in:
- GitHub (in markdown files and PRs)
- VSCode (with Mermaid preview extensions)
- GitLab, Bitbucket, and other modern platforms
- Documentation sites (MkDocs, Docusaurus, etc.)

### Example Usage

```markdown
## Enforcement Data Model

See the complete entity relationships:

[View Enforcement ER Diagram](docs-dev/dev/enforcement/diagrams/enforcement-entity-relationship.md)

The Case resource structure:

[View Case Class Diagram](docs-dev/dev/enforcement/diagrams/enforcement-class.md)
```

## 🔧 Configuration

The diagram generation is configured in `config/dev.exs`:

```elixir
# Using Mermaid.ink online renderer (no local dependencies required)
config :ash_diagram, :renderer, AshDiagram.Renderer.MermaidInk
```

To use local CLI rendering instead (requires `npm install -g @mermaid-js/mermaid-cli`):

```elixir
config :ash_diagram, :renderer, AshDiagram.Renderer.CLI
```

## 📝 Notes

- **Format**: All diagrams are Mermaid markdown (`.md` files with Mermaid code blocks)
- **Version Control**: Diagrams are checked into git for visibility in diffs and PRs
- **Generation Time**: Full regeneration takes ~5-10 seconds for all domains
- **Dependencies**: Dev-only (`only: :dev, runtime: false`) - not included in production

## 🆘 Troubleshooting

### Diagrams not rendering in GitHub/VSCode

- Ensure Mermaid syntax is valid
- Check that code blocks use triple backticks with `mermaid` language identifier
- VSCode may require Mermaid preview extension

### Generation fails with undefined function error

- Ensure `ash_diagram` dependency is installed: `mix deps.get`
- Verify dev environment: Generation only works in dev mode

### Empty or minimal diagrams

- Check that Ash resources are properly defined with `use Ash.Resource`
- Verify resources are registered in domain modules
- Ensure relationships are defined on resources

## 📚 Further Reading

- [Ash Framework Documentation](https://hexdocs.pm/ash/)
- [ash_diagram on Hex](https://hex.pm/packages/ash_diagram)
- [Mermaid Documentation](https://mermaid.js.org/)
- [Mermaid Live Editor](https://mermaid.live/) - Test and edit diagrams interactively
