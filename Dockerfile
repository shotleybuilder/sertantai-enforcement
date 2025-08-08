# WORK IN PROGRESS - Alpine Dockerfile with OpenSSL compatibility issues
# TODO: Fix crypto library loading error with Alpine/musl libc
# Current issue: EVP_MD_CTX_get_size_ex symbol not found
# Consider this deprecated in favor of Dockerfile.debian

# Build stage - use same Alpine version for both stages
FROM elixir:1.18-alpine AS build

# Install build-time dependencies
RUN apk add --no-cache \
    build-base \
    git \
    python3 \
    curl \
    nodejs \
    npm \
    make \
    gcc \
    g++ \
    musl-dev \
    pkgconfig \
    cmake \
    linux-headers \
    zlib-dev \
    openssl-dev

# Set build ENV
ENV MIX_ENV=prod

# Create app directory
WORKDIR /app

# Copy mix files
COPY mix.exs mix.lock ./

# Install mix dependencies
RUN mix local.hex --force && \
    mix local.rebar --force && \
    mix deps.get --only prod && \
    mkdir config

# Copy compile-time config files before we compile dependencies
COPY config/config.exs config/${MIX_ENV}.exs config/

# Compile dependencies
RUN mix deps.compile

# Compile assets
COPY assets assets
COPY priv priv
RUN mix assets.deploy

# Compile the release
COPY lib lib
RUN mix compile

# Changes to config/runtime.exs don't require recompiling the code
COPY config/runtime.exs config/

# Copy release files
COPY rel rel
RUN mix release

# Runtime stage - use same base as build to ensure compatibility
FROM elixir:1.18-alpine AS app

# Install only runtime dependencies (Elixir already includes OpenSSL)
RUN apk add --no-cache \
    libstdc++ \
    ncurses-libs \
    ca-certificates

# Set environment
ENV MIX_ENV=prod
ENV PHX_SERVER=true
ENV LANG=C.UTF-8

# Create app user
RUN addgroup -g 1000 -S phoenix && \
    adduser -S phoenix -u 1000 -G phoenix

# Create app directory
WORKDIR /app

# Copy the release from build stage
COPY --from=build --chown=phoenix:phoenix /app/_build/prod/rel/ehs_enforcement ./

# Switch to phoenix user
USER phoenix

# Expose port
EXPOSE 4002

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4002/health || exit 1

# Start the release
CMD ["bin/ehs_enforcement", "start"]