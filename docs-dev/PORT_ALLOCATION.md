# Port Allocation Strategy

> **Purpose**: Prevent port conflicts across multiple local development projects

## sertantai-enforcement Ports

| Service | Port | Internal Port | Notes |
|---------|------|---------------|-------|
| **Phoenix Backend** | 4002 | - | Configured in `config/dev.exs` |
| **SvelteKit Frontend** | 5173 | - | Vite default (configured in `package.json`) |
| **PostgreSQL** | 5434 | 5432 | Docker mapped port (avoid default 5432) |
| **ElectricSQL** | 3001 | 3000 | Docker mapped port (avoid conflict with controls) |
| **Redis** | 6380 | 6379 | Docker mapped port (TBC) |

## Database

- **Name**: `sertantai_enforcement_dev`
- **User**: `postgres`
- **Password**: `postgres` (dev only)
- **Docker Container**: `ehs_dev_postgres`

## Cross-Project Port Map

| Project | Backend | Frontend | DB | Electric | Stack |
|---------|---------|----------|-----|----------|-------|
| **sertantai-auth** | 4000 | N/A | 5432 | N/A | Phoenix (no Ash) |
| **sertantai-controls** | 4001 | 5174 | 5435 | 3000 | Ash + ElectricSQL + SvelteKit |
| **sertantai-enforcement** | 4002 | 5173 | 5434 | 3001 | Ash + ElectricSQL + SvelteKit |

## Port Allocation Rules

1. **Phoenix Backends**: Increment from 4000 (4000, 4001, 4002, ...)
2. **SvelteKit Frontends**: Use Vite defaults or increment (5173, 5174, ...)
3. **PostgreSQL Docker**: Increment from 5434 to avoid default 5432 (5434, 5435, ...)
4. **ElectricSQL**: Increment from 3000 (3000, 3001, 3002, ...)
5. **Redis**: Increment from 6380 to avoid default 6379

## Starting Services

### Full Stack (Recommended for Development)
```bash
# Backend + Database + ElectricSQL
docker compose -f docker-compose.dev.yml up -d postgres electric redis
mix phx.server  # Terminal 1

# Frontend
cd frontend && npm run dev  # Terminal 2
```

### Services Only
```bash
# Just infrastructure
docker compose -f docker-compose.dev.yml up -d postgres electric redis

# Then run Phoenix and SvelteKit on host
```

## Stopping Services

```bash
# Stop all Docker services
docker compose -f docker-compose.dev.yml down

# Or stop individual services
docker stop ehs_dev_postgres ehs_dev_electric ehs_dev_redis
```

## Verifying No Conflicts

```bash
# Check what's using ports
sudo lsof -i :4002  # Phoenix
sudo lsof -i :5173  # SvelteKit
sudo lsof -i :5434  # PostgreSQL
sudo lsof -i :3001  # ElectricSQL

# Check Docker containers
docker ps | grep ehs_dev
```

## Health Checks

- **Phoenix**: http://localhost:4002
- **SvelteKit**: http://localhost:5173
- **ElectricSQL**: http://localhost:3001/v1/shape?table=cases&offset=-1
- **PostgreSQL**: `psql -h localhost -p 5434 -U postgres -d sertantai_enforcement_dev`

## Environment Variables

**Backend** (`config/dev.exs`):
```elixir
http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("PORT") || "4002")]
```

**Frontend** (`frontend/.env.example`):
```bash
PUBLIC_API_URL=http://localhost:4002
PUBLIC_ELECTRIC_URL=http://localhost:3001
PUBLIC_ENV=development
```

**Docker** (`docker-compose.dev.yml`):
```yaml
postgres:
  ports:
    - "5434:5432"

electric:
  ports:
    - "3001:3000"
```
