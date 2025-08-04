# Database Deployment Options for EHS Enforcement

## Current Architecture: Separate Containers (Recommended)

### **Structure:**
```
┌─────────────────┐    ┌──────────────────┐
│   App Container │    │ Postgres Container│
│                 │    │                  │
│ - Elixir/Phoenix│───▶│ - PostgreSQL 16  │
│ - Port 4000     │    │ - Port 5432      │
│ - Stateless     │    │ - Persistent Vol │
└─────────────────┘    └──────────────────┘
```

### **Benefits:**
- ✅ **Independent scaling** and updates
- ✅ **Data persistence** across app deployments  
- ✅ **Resource optimization** for each service
- ✅ **Easy backup/restore** procedures
- ✅ **Production-ready** architecture

### **Current Configuration:**
```yaml
# docker-compose.prod.yml
services:
  postgres:
    image: postgres:16-alpine        # Separate DB container
    volumes:
      - postgres_data:/var/lib/postgresql/data  # Persistent storage
    
  app:
    build: .                         # Your app container
    depends_on:
      postgres:
        condition: service_healthy   # Wait for DB to be ready
```

## Alternative Option 1: Bundled Container

### **Single Container with Embedded Database:**

```dockerfile
# Dockerfile.bundled (NOT RECOMMENDED)
FROM hexpm/elixir:1.17.3-erlang-27.1.2-alpine-3.20.3

# Install PostgreSQL in same container
RUN apk add --no-cache postgresql postgresql-contrib

# Start both services
CMD ["sh", "-c", "pg_ctl start -D /var/lib/postgresql/data && bin/server"]
```

### **Problems with Bundled Approach:**
- ❌ **Data loss risk** during app updates
- ❌ **Resource competition** between app and DB
- ❌ **Complex startup** orchestration
- ❌ **Difficult scaling** and maintenance
- ❌ **Not production-ready** for serious workloads

## Alternative Option 2: External Managed Database

### **Use Digital Ocean Managed Database:**

```yaml
# docker-compose.managed.yml
services:
  app:
    build: .
    environment:
      # Connect to managed database
      DATABASE_URL: postgresql://user:pass@db-cluster.digitalocean.com:25060/ehs_enforcement
    # No postgres service needed
```

### **Benefits of Managed Database:**
- ✅ **Automatic backups** and maintenance
- ✅ **High availability** with failover
- ✅ **Performance monitoring** included
- ✅ **Scaling on demand**
- ✅ **Security hardening** by provider
- ✅ **No database management** overhead

### **Trade-offs:**
- 💰 **Higher cost** than self-hosted
- 🔒 **Less control** over configuration
- 🌐 **Network dependency** for database access

## Alternative Option 3: Hybrid Approach

### **Local Dev + Managed Production:**

```yaml
# docker-compose.dev.yml (Development)
services:
  postgres:
    image: postgres:16-alpine    # Local development DB
    
  app:
    build: .
    environment:
      DATABASE_URL: postgresql://postgres:postgres@postgres:5432/ehs_enforcement_dev
```

```yaml
# docker-compose.prod.yml (Production)
services:
  app:
    build: .
    environment:
      DATABASE_URL: ${MANAGED_DATABASE_URL}  # Points to Digital Ocean managed DB
    # No postgres service in production
```

## Recommended Architecture for Digital Ocean VPS

### **Option A: Self-Managed (Current Setup)**
**Best for:** Cost-conscious deployments, full control needs

```
VPS Instance:
├── App Container (Phoenix/Elixir)
├── PostgreSQL Container  
├── Nginx Container (SSL termination)
└── Persistent volumes for data
```

### **Option B: Hybrid Managed**
**Best for:** Production reliability with managed services

```
VPS Instance:
├── App Container (Phoenix/Elixir)
├── Nginx Container (SSL termination)
└── External: Digital Ocean Managed PostgreSQL
```

## Migration Strategies

### **From Separate Containers to Managed Database:**

```bash
# 1. Create managed database on Digital Ocean
doctl databases create ehs-enforcement-prod --engine postgres --version 16

# 2. Export current database
./scripts/backup.sh prod

# 3. Import to managed database
psql $MANAGED_DATABASE_URL < backups/backup_latest.sql

# 4. Update environment variables
DATABASE_URL=postgresql://user:pass@managed-db.digitalocean.com:25060/ehs_enforcement

# 5. Deploy with new configuration
./scripts/deploy.sh prod
```

### **From Bundled to Separate Containers:**

```bash
# 1. Extract database from bundled container
docker exec bundled_container pg_dump -U postgres ehs_enforcement > backup.sql

# 2. Deploy separate containers
docker-compose -f docker-compose.prod.yml up -d postgres

# 3. Import data to separate container
docker-compose -f docker-compose.prod.yml exec -T postgres psql -U postgres ehs_enforcement < backup.sql

# 4. Deploy app container
docker-compose -f docker-compose.prod.yml up -d app
```

## Performance Considerations

### **Separate Containers:**
- **App Container**: 1-2 GB RAM, 1-2 CPU cores
- **Database Container**: 2-4 GB RAM, 2 CPU cores
- **Total VPS Requirements**: 4-8 GB RAM, 4 CPU cores

### **Resource Allocation:**
```yaml
# docker-compose.prod.yml with resource limits
services:
  app:
    deploy:
      resources:
        limits:
          memory: 2G
          cpus: '1.0'
        reservations:
          memory: 1G
          cpus: '0.5'
  
  postgres:
    deploy:
      resources:
        limits:
          memory: 4G
          cpus: '2.0'
        reservations:
          memory: 2G
          cpus: '1.0'
```

## Security Considerations

### **Container Network Isolation:**
```yaml
# Only app can access database
networks:
  ehs_network:
    internal: true  # No external access to DB
    
services:
  postgres:
    networks:
      - ehs_network
    # No published ports (only internal)
    
  app:
    networks:
      - ehs_network
    ports:
      - "4000:4000"  # Only app exposed
```

### **Database Security:**
- 🔐 **SSL connections** enforced
- 🚫 **No direct external access** to database
- 🔑 **Strong passwords** and secrets
- 📊 **Connection monitoring** and rate limiting

## Recommendation

**For Digital Ocean VPS deployment, stick with the current separate container approach because:**

1. ✅ **Production-proven** architecture
2. ✅ **Easy maintenance** and updates  
3. ✅ **Cost-effective** for small-medium scale
4. ✅ **Full control** over database configuration
5. ✅ **Simple backup/restore** procedures
6. ✅ **Can migrate to managed DB** later if needed

The current setup gives you the **best balance of cost, control, and reliability** for a VPS deployment!