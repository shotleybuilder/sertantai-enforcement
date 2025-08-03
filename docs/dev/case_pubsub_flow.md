# Case PubSub Flow Documentation

## Overview

The Case PubSub system provides real-time updates when cases are created or updated during scraping operations. This document explains how PubSub events flow through the system.

**Updated**: As of 2025-08-03, the Records component uses direct state management instead of `keep_live` for session-specific data, resolving timing issues and improving performance.

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

The Scrape LiveView uses two different patterns for reactive updates:

#### A. Resource-Level Data (keep_live pattern)
For general resource queries (recent cases, active sessions), uses `AshPhoenix.LiveView.keep_live/4`:

```elixir
# For recent cases - resource-level reactive query
socket = AshPhoenix.LiveView.keep_live(socket, :recent_cases, fn socket ->
  EhsEnforcement.Enforcement.Case
  |> Ash.Query.sort(inserted_at: :desc)
  |> Ash.Query.limit(100)
  |> Ash.read!(actor: socket.assigns.current_user)
end,
  subscribe: ["case:created:*", "case:updated:*"],
  results: :keep,
  refetch_window: :timer.seconds(5)
)
```

#### B. Session-Specific Data (Direct State Management)
For session-specific transient data (scraped cases during current session), uses manual PubSub subscriptions:

```elixir
# Manual PubSub subscription for session-specific scraped cases
if connected?(socket) do
  Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:synced")
  Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:created")
end

# Initialize empty scraped_cases list in socket assigns
socket = assign(socket, scraped_cases: [])
```

### 5. Message Handling

LiveView handles PubSub messages via `handle_info/2` with different patterns:

#### A. keep_live Pattern (Resource-Level Data)
```elixir
def handle_info(%Phoenix.Socket.Broadcast{topic: "case:created", event: "create", payload: notification}, socket) do
  # Trigger keep_live refresh for resource-level queries
  {:noreply, AshPhoenix.LiveView.handle_live(socket, "case:created", [:recent_cases])}
end
```

#### B. Direct State Management (Session-Specific Data)
```elixir
def handle_info(%Phoenix.Socket.Broadcast{topic: "case:synced", event: "sync", payload: notification}, socket) do
  # Only add to scraped_cases if we have an active session and case was synced after session started
  socket = if socket.assigns.scraping_session_started_at && 
              notification.data.last_synced_at && 
              DateTime.compare(notification.data.last_synced_at, socket.assigns.scraping_session_started_at) != :lt do
    
    # Load full case data with associations
    case = EhsEnforcement.Enforcement.Case
    |> Ash.get!(notification.data.id, load: [:agency, :offender], actor: socket.assigns.current_user)
    
    # Add to the beginning of the list (most recent first)
    updated_scraped_cases = [case | socket.assigns.scraped_cases]
    
    # Keep only the most recent 50 cases
    updated_scraped_cases = Enum.take(updated_scraped_cases, 50)
    
    assign(socket, scraped_cases: updated_scraped_cases)
  else
    socket
  end
  
  {:noreply, socket}
end

def handle_info(%Phoenix.Socket.Broadcast{topic: "case:created", event: "create", payload: notification}, socket) do
  # Only add to scraped_cases if we have an active session
  socket = if socket.assigns.scraping_session_started_at do
    # Load full case data with associations
    case = EhsEnforcement.Enforcement.Case
    |> Ash.get!(notification.data.id, load: [:agency, :offender], actor: socket.assigns.current_user)
    
    # Add to the beginning of the list (most recent first)
    updated_scraped_cases = [case | socket.assigns.scraped_cases]
    
    # Keep only the most recent 50 cases
    updated_scraped_cases = Enum.take(updated_scraped_cases, 50)
    
    assign(socket, scraped_cases: updated_scraped_cases)
  else
    socket
  end
  
  {:noreply, socket}
end
```

## Key Points

1. **Automatic Broadcasting**: Ash automatically broadcasts PubSub events when actions succeed
2. **Topic Structure**: Topics follow the pattern `prefix:event` or `prefix:event:id`
3. **Two Integration Patterns**: 
   - **keep_live**: For resource-level reactive queries (recent cases, active sessions)
   - **Direct State Management**: For session-specific transient data (current scraping progress)
4. **Real-time Updates**: The UI updates automatically when cases are created or synced
5. **Session Filtering**: Session-specific data is filtered in PubSub handlers, not database queries
6. **Performance**: Direct state management avoids expensive database queries on every PubSub event
7. **Debouncing**: `refetch_window` prevents overwhelming the system with rapid updates (keep_live only)
8. **Actor Context**: All operations respect the current user's permissions

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

## Architecture Decision: When to Use Each Pattern

### Use keep_live When:
- Displaying resource-level data that should react to all changes
- Query results don't depend on specific session state
- You want automatic database query execution and caching
- Example: Recent cases list, active sessions, user profiles

### Use Direct State Management When:
- Data is session-specific or transient
- Query logic depends on LiveView session state
- You need immediate control over when and how data updates
- Performance is critical (avoiding database queries on every event)
- Example: Current scraping progress, temporary form data, session-specific filtered lists

## Common Issues

1. **No PubSub events**: Ensure the PubSub module is correctly configured in the resource
2. **UI not updating**: 
   - For keep_live: Check that LiveView is subscribing to the correct topics
   - For direct management: Verify PubSub subscriptions and handle_info handlers exist
3. **Too many updates**: 
   - For keep_live: Adjust the `refetch_window` to debounce updates
   - For direct management: Implement your own debouncing logic if needed
4. **Session data not filtering correctly**: 
   - Ensure session state (like `scraping_session_started_at`) is set before background tasks start
   - Apply session filters in PubSub handlers, not database queries
5. **Memory leaks with direct management**: 
   - Always limit list sizes (e.g., `Enum.take(list, 50)`)
   - Clear session-specific data when sessions end