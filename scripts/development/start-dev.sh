#!/bin/bash

# EHS Enforcement Development Starter
# Simple version that mimics sertantai's approach

cd /home/jason/Desktop/ehs_enforcement

echo "🐳 Starting EHS Enforcement PostgreSQL..."

# Start our container (similar to sertantai)
docker-compose up -d postgres

echo "⏳ Waiting for PostgreSQL to be ready..."
sleep 5

# Test if container is actually running
if docker ps | grep -q "ehs_enforcement_postgres"; then
    echo "✅ PostgreSQL container running"
else
    echo "❌ PostgreSQL container failed to start"
    echo "Checking logs:"
    docker logs ehs_enforcement_postgres
    exit 1
fi

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