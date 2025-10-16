#!/bin/bash

# EHS Enforcement Database Setup Script
# This script helps create the database if you have PostgreSQL already running

echo "🗄️  EHS Enforcement Database Setup"
echo "=================================="

# Check if we can connect to PostgreSQL
if ! command -v psql &> /dev/null; then
    echo "❌ psql command not found. Please install PostgreSQL client tools."
    exit 1
fi

# Try to create the database
echo "📦 Creating ehs_enforcement_dev database..."

# Try with default postgres user first
if psql -U postgres -lqt | cut -d \| -f 1 | grep -qw ehs_enforcement_dev 2>/dev/null; then
    echo "✅ Database ehs_enforcement_dev already exists"
else
    # Try to create database
    if psql -U postgres -c "CREATE DATABASE ehs_enforcement_dev;" 2>/dev/null; then
        echo "✅ Database ehs_enforcement_dev created successfully"
    else
        echo "⚠️  Could not create database with default postgres user"
        echo "You may need to:"
        echo "1. Set the correct username/password in config/dev.exs"
        echo "2. Or use environment variables:"
        echo "   export DB_USERNAME=your_username"
        echo "   export DB_PASSWORD=your_password"
        echo "3. Or create the database manually with your credentials"
        exit 1
    fi
fi

echo "🎉 Database setup complete!"
echo "You can now run: mix phx.server or ehs-dev"