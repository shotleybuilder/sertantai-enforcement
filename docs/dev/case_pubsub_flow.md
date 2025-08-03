# Case PubSub Flow Documentation

## Overview

The Case PubSub system provides real-time updates when cases are created or updated during scraping operations. This document explains how PubSub events flow through the system.

## Architecture

### 1. Case Resource Configuration

The Case resource (`lib/ehs_enforcement/enforcement/resources/case.ex`) is configured with Ash's PubSub notifier:

```elixir
use Ash.Resource,
  notifiers: [Ash.Notifier.PubSub]

pub_sub do
  module(EhsEnforcement.PubSub)
  prefix("case")
  
  publish(:create, ["created", :id])
  publish(:create, ["created"])
  publish(:sync, ["synced", :id])
  publish(:sync, ["synced"])
end
```

### 2. PubSub Module

The `EhsEnforcement.PubSub` module wraps Phoenix.PubSub and formats messages for compatibility with Phoenix.LiveView:

```elixir
def broadcast(topic, event, notification) do
  message = %Phoenix.Socket.Broadcast{
    topic: topic,
    event: event,
    payload: notification
  }
  
  Phoenix.PubSub.broadcast(EhsEnforcement.PubSub, topic, message)
end
```

### 3. Event Flow During Scraping

1. **Case Creation (New Case)**
   - Scraper calls `Enforcement.create_case/2`
   - Ash automatically publishes to:
     - `case:created` (general topic)
     - `case:created:<case_id>` (specific topic)

2. **Case Sync (Existing Case)**
   - Scraper finds existing case
   - Calls `Ash.update(case, %{}, action: :sync)`
   - The `:sync` action updates `last_synced_at`
   - Ash publishes to:
     - `case:synced` (general topic)
     - `case:synced:<case_id>` (specific topic)

### 4. LiveView Integration

The Scrape LiveView uses `AshPhoenix.LiveView.keep_live/4` for reactive updates:

```elixir
socket = AshPhoenix.LiveView.keep_live(socket, :scraped_cases, fn socket ->
  # Query for recently synced cases
  EhsEnforcement.Enforcement.Case
  |> Ash.Query.filter(last_synced_at > ^recent_cutoff)
  |> Ash.Query.sort([last_synced_at: :desc])
  |> Ash.read!(actor: socket.assigns.current_user)
end,
  subscribe: ["case:synced", "case:created"],
  results: :keep,
  refetch_window: :timer.seconds(2)
)
```

### 5. Message Handling

LiveView handles PubSub messages via `handle_info/2`:

```elixir
def handle_info(%Phoenix.Socket.Broadcast{topic: "case:synced", event: "sync", payload: notification}, socket) do
  # Trigger keep_live refresh
  {:noreply, AshPhoenix.LiveView.handle_live(socket, "case:synced", [:scraped_cases])}
end
```

## Key Points

1. **Automatic Broadcasting**: Ash automatically broadcasts PubSub events when actions succeed
2. **Topic Structure**: Topics follow the pattern `prefix:event` or `prefix:event:id`
3. **Real-time Updates**: The UI updates automatically when cases are created or synced
4. **Debouncing**: `refetch_window` prevents overwhelming the system with rapid updates
5. **Actor Context**: All operations respect the current user's permissions

## Debugging

To see PubSub events in action:

1. Enable Ash PubSub debugging in `config/dev.exs`:
   ```elixir
   config :ash, :pub_sub, debug?: true
   ```

2. Look for these log patterns:
   - `🟠 UI: Received Case sync notification`
   - `🔴 keep_live query triggered!`
   - `✅ Updated existing case via :sync action`

## Common Issues

1. **No PubSub events**: Ensure the PubSub module is correctly configured in the resource
2. **UI not updating**: Check that LiveView is subscribing to the correct topics
3. **Too many updates**: Adjust the `refetch_window` to debounce updates