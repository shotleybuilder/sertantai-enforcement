#!/bin/bash

# EHS Enforcement Development - Manual Docker Commands
# Use this if docker-compose isn't installed

cd /home/jason/Desktop/ehs-enforcement

echo "🐳 Starting PostgreSQL with manual Docker commands..."

# Stop any existing container
docker stop ehs_enforcement_postgres 2>/dev/null
docker rm ehs_enforcement_postgres 2>/dev/null

# Create and start PostgreSQL container manually
docker run -d \
  --name ehs_enforcement_postgres \
  -e POSTGRES_DB=ehs_enforcement_dev \
  -e POSTGRES_USER=postgres \
  -e POSTGRES_PASSWORD=postgres \
  -p 5433:5432 \
  -v ehs_postgres_data:/var/lib/postgresql/data \
  --restart unless-stopped \
  postgres:16

echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 8

# Wait for PostgreSQL to accept connections
echo "🔍 Checking PostgreSQL connection..."
timeout=30
while ! docker exec ehs_enforcement_postgres pg_isready -U postgres >/dev/null 2>&1; do
    timeout=$((timeout - 1))
    if [ $timeout -eq 0 ]; then
        echo "❌ PostgreSQL failed to start within 30 seconds"
        exit 1
    fi
    sleep 1
done

echo "✅ PostgreSQL container running"

# Create database
echo "📦 Setting up database..."
mix ecto.create

# Start based on argument
if [ "$1" = "iex" ]; then
    echo "🚀 Starting in iex mode..."
    iex -S mix phx.server
else
    echo "🚀 Starting development server..."
    mix phx.server
fi