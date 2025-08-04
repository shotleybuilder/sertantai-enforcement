# Build stage
FROM hexpm/elixir:1.17.3-erlang-27.1.2-alpine-3.20.3 AS build

# Install build-time dependencies
RUN apk add --no-cache \
    build-base \
    git \
    nodejs \
    npm \
    ca-certificates \
    openssl \
    ncurses-libs

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

# Copy compile-time config files
COPY config/config.exs config/prod.exs config/runtime.exs config/

# Compile dependencies
RUN mix deps.compile

# Copy application code
COPY priv priv
COPY lib lib
COPY assets assets

# Install node dependencies and build assets
RUN cd assets && npm ci --only=production
RUN mix assets.deploy

# Compile the release
RUN mix compile

# Create release
RUN mix release

# Runtime stage
FROM alpine:3.20.3 AS app

# Install runtime dependencies
RUN apk add --no-cache \
    libstdc++ \
    openssl \
    ncurses-libs \
    ca-certificates

# Set environment
ENV MIX_ENV=prod
ENV PHX_SERVER=true
ENV LANG=C.UTF-8

# Create app user
RUN addgroup -g 1000 -S app && \
    adduser -u 1000 -s /bin/sh -G app -S app

# Create app directory
WORKDIR /app

# Copy built application
COPY --from=build --chown=app:app /app/_build/prod/rel/ehs_enforcement ./

# Switch to app user
USER app

# Expose port
EXPOSE 4000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD wget --no-verbose --tries=1 --spider http://localhost:4000/health || exit 1

# Start the release
CMD ["bin/server"]