# Development Scripts

Scripts for starting and managing your local development environment.

## Quick Start

```bash
# Most common: Start dev with Docker
./scripts/development/ehs-dev.sh

# Or without Docker
./scripts/development/ehs-dev-no-docker.sh
```

## Available Scripts

### ehs-dev.sh

**Start complete development environment with Docker PostgreSQL**

```bash
./scripts/development/ehs-dev.sh
```

**What it does:**
- Stops any existing PostgreSQL containers
- Starts PostgreSQL 14 in Docker on port 5434
- Creates database if needed
- Runs migrations
- Starts Phoenix server on port 4002

**When to use:**
- Daily development startup
- Fresh environment setup
- You don't have PostgreSQL installed locally

---

### ehs-dev-no-docker.sh

**Start development environment without Docker**

```bash
./scripts/development/ehs-dev-no-docker.sh
```

**What it does:**
- Creates database using local PostgreSQL
- Runs migrations
- Starts Phoenix server

**When to use:**
- Docker not available
- Using local PostgreSQL installation
- Prefer native database

**Prerequisites:**
- PostgreSQL installed locally
- Database configured in `config/dev.exs`

---

### start-dev.sh

**Quick start Phoenix server (assumes database running)**

```bash
./scripts/development/start-dev.sh
```

**What it does:**
- Starts Phoenix server only
- No database setup or checks

**When to use:**
- Database already running
- Quick restart after code changes
- Environment already set up

---

### docker-manual.sh

**Manual Docker PostgreSQL management**

```bash
./scripts/development/docker-manual.sh
```

**What it does:**
- Creates PostgreSQL container manually (no docker-compose)
- Provides manual container control

**When to use:**
- docker-compose not available
- Need manual container management
- Troubleshooting container issues

---

### setup_database.sh

**Database setup and connectivity helper**

```bash
./scripts/development/setup_database.sh
```

**What it does:**
- Checks PostgreSQL connectivity
- Creates database if missing
- Tests connection

**When to use:**
- Initial database setup
- Database connection issues
- Verifying database access

---

## Common Workflows

### First Time Setup

```bash
# 1. Start development environment
./scripts/development/ehs-dev.sh

# 2. Import sample data (optional)
./scripts/data/airtable_import.sh dev --cases --limit 100
```

### Daily Development

```bash
# Start with fresh database
./scripts/development/ehs-dev.sh

# Or just start server if DB already running
./scripts/development/start-dev.sh
```

### Troubleshooting

```bash
# Database won't connect?
./scripts/development/setup_database.sh

# Need manual control?
./scripts/development/docker-manual.sh

# Port conflict?
# Edit scripts to use different port or kill process:
lsof -i :4002  # Find process on port 4002
kill -9 <PID>  # Kill it
```

---

## Configuration

All scripts respect environment variables and `config/dev.exs` settings:

- **Database Port**: Default 5434 (Docker), 5432 (local)
- **Phoenix Port**: 4002
- **Database Name**: ehs_enforcement_dev
- **Database User**: postgres
- **Database Password**: postgres

To customize, edit `config/dev.exs` or set environment variables.

---

## Related Documentation

- **[docs-dev/GETTING_STARTED.md](../../docs-dev/GETTING_STARTED.md)** - Initial setup guide
- **[docs-dev/DEVELOPMENT_WORKFLOW.md](../../docs-dev/DEVELOPMENT_WORKFLOW.md)** - Day-to-day workflow
- **[docs-dev/TROUBLESHOOTING.md](../../docs-dev/TROUBLESHOOTING.md)** - Common issues

---

**Parent README**: [scripts/README.md](../README.md)
