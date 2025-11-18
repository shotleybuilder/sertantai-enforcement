#!/bin/bash

# EHS Enforcement Development Environment (No Docker Fallback)
# Use this if Docker isn't available

cd /home/jason/Desktop/ehs-enforcement

echo "🚨 Running without Docker - using local PostgreSQL"
echo "Make sure you have PostgreSQL running locally!"

# Try to create database (might fail if DB doesn't exist or wrong credentials)
echo "📦 Attempting to create database..."
if mix ecto.create 2>/dev/null; then
    echo "✅ Database ready"
else
    echo "⚠️  Database creation failed - you may need to:"
    echo "   1. Start local PostgreSQL service"
    echo "   2. Update config/dev.exs with correct credentials"
    echo "   3. Create database manually: createdb ehs_enforcement_dev"
fi

# Start Phoenix server or iex based on argument
if [ "$1" = "iex" ]; then
    echo "🚀 Starting EHS Enforcement in iex mode (no Docker)..."
    iex -S mix phx.server
else
    echo "🚀 Starting EHS Enforcement development server (no Docker)..."
    mix phx.server
fi