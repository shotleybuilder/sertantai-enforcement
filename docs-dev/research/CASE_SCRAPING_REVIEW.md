# Case Scraping Review: Separation of Concerns Analysis

**Date**: 2025-08-13  
**Reviewer**: Claude Code Analysis  
**Focus**: Identifying overly complex case statements and poor separation of concerns

## Executive Summary

The EHS Enforcement codebase demonstrates **mostly idiomatic Elixir patterns** with good separation of concerns. However, there are **3 key areas** where unnecessary complexity exists due to agency-specific duplication rather than proper abstraction.

**Overall Complexity Rating**: 6/10 (Moderate - could be improved to 4/10)

## ✅ Strengths (Good Patterns)

### 1. Proper Elixir Idioms
- **Case statements** are used appropriately for error handling and pattern matching
- **Pattern matching** follows Elixir best practices
- No excessive if/else chains found

### 2. Good Architecture Decisions
- **Single Cases table** for all agencies ✓
- **Ash Framework integration** properly implemented ✓
- **Consistent error handling** patterns ✓

### 3. Code Organization
- Clear module structure with agency-specific namespacing
- Proper use of LiveView patterns
- Good separation between scraping logic and UI

## ⚠️ Areas of Unnecessary Complexity

### 1. Agency Switching in Templates (Minor Issue)

**File**: `lib/ehs_enforcement_web/live/admin/case_live/scrape.html.heex:177-185`

```heex
<% selected_agency = Phoenix.HTML.Form.input_value(@form, :agency) %>
<%= if selected_agency in [:hse, "hse"] do %>
  <!-- HSE Progress Component (Page-based) -->
  <.hse_progress_component progress={@progress} />
<% else %>
  <!-- EA Progress Component (Case-based) -->
  <.ea_progress_component progress={@progress} />
<% end %>
```

**Problem**: Template logic deciding which component to render
**Impact**: Template complexity, duplication of progress display logic

### 2. Dual Processing Log Resources (Medium Issue)

**Files**: 
- `lib/ehs_enforcement/scraping/resources/hse_page_processing_log.ex`
- `lib/ehs_enforcement/scraping/resources/ea_case_processing_log.ex`

**Current Field Mismatches**:
```elixir
# HSE Processing Log
cases_scraped: :integer     # ← Different field name
cases_skipped: :integer     # ← Different field name  
existing_count: :integer    # ← Different field name

# EA Processing Log  
cases_found: :integer       # ← Different field name
cases_failed: :integer      # ← Different field name
cases_existing: :integer    # ← Different field name
```

**Runtime Error**: `** (KeyError) key :cases_scraped not found in: %EhsEnforcement.Scraping.EaCaseProcessingLog{}`

**Impact**: 
- Runtime errors when template tries to access wrong field names
- Code duplication maintaining two similar resources
- Template complexity with `Map.get` fallbacks

### 3. Agency-Specific Scraping Functions (Medium Issue)

**File**: `lib/ehs_enforcement_web/live/admin/case_live/scrape.ex:151-159`

```elixir
case scrape_request.agency do
  :hse -> start_hse_scraping(socket, scrape_request)
  :ea -> start_ea_scraping(socket, scrape_request)
  _ -> {:noreply, put_flash(socket, :error, "Unknown agency selected")}
end
```

**Problem**: Separate functions with different parameter structures and internal logic
**Impact**: Code duplication, harder to maintain agency-specific behavior

## 🔧 Recommended Refactoring

### Priority 1: Unify Processing Log Resources (High Priority)

**Goal**: Fix runtime errors and eliminate field name confusion

**Solution**: Create a unified processing log resource:

```elixir
defmodule EhsEnforcement.Scraping.ProcessingLog do
  @moduledoc """
  Unified processing log for all agency scraping operations.
  Replaces separate HSE and EA processing log resources.
  """
  
  use Ash.Resource,
    domain: EhsEnforcement.Scraping,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id
    
    # Common fields
    attribute :session_id, :string, allow_nil?: false
    attribute :agency, :atom, allow_nil?: false  # :hse, :ea, etc.
    
    # Unified naming (agency-agnostic)
    attribute :batch_or_page, :integer, default: 1  # page for HSE, batch for EA
    attribute :items_found, :integer, default: 0    # cases_scraped/cases_found
    attribute :items_created, :integer, default: 0  # cases_created (same for both)
    attribute :items_existing, :integer, default: 0 # existing_count/cases_existing  
    attribute :items_failed, :integer, default: 0   # cases_skipped/cases_failed
    
    # Common metadata
    attribute :creation_errors, {:array, :string}, default: []
    attribute :scraped_items, {:array, :map}, default: []

    timestamps()
  end
end
```

**Template Update**:
```heex
<!-- No more Map.get fallbacks needed -->
<span class="font-medium"><%= details.items_found %></span> scraped
<span class="font-medium"><%= details.items_created %></span> created
<span class="font-medium"><%= details.items_existing %></span> existing
<span class="font-medium"><%= details.items_failed %></span> failed
```

### Priority 2: Unify Progress Components (Medium Priority)

**Goal**: Eliminate template agency switching logic

**Solution**: Single progress component with internal agency handling:

```elixir
defmodule EhsEnforcementWeb.Components.ProgressComponent do
  use Phoenix.Component

  def unified_progress_component(assigns) do
    ~H"""
    <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
      <div class="flex items-center justify-between mb-4">
        <h2 class="text-xl font-semibold text-gray-900">
          <%= agency_display_name(@agency) %> Progress
        </h2>
        <div class="flex items-center space-x-2">
          <%= render_status_indicator(@progress) %>
        </div>
      </div>
      
      <%= if agency_uses_pagination?(@agency) do %>
        <%= render_page_based_progress(assigns) %>
      <% else %>
        <%= render_batch_based_progress(assigns) %>
      <% end %>
    </div>
    """
  end
  
  defp agency_uses_pagination?(agency) when agency in [:hse, "hse"], do: true
  defp agency_uses_pagination?(_), do: false
  
  defp agency_display_name(:hse), do: "HSE"
  defp agency_display_name(:ea), do: "EA"
  defp agency_display_name(agency), do: String.upcase(to_string(agency))
end
```

**Template Update**:
```heex
<!-- Simple, no agency switching -->
<.unified_progress_component agency={@selected_agency} progress={@progress} />
```

### Priority 3: Agency Behavior Pattern (Low Priority - Future Enhancement)

**Goal**: Cleaner agency-specific scraping logic

**Solution**: Use Elixir behaviors for agency-specific implementations:

```elixir
defmodule EhsEnforcement.Scraping.AgencyBehavior do
  @moduledoc """
  Behavior for agency-specific scraping implementations.
  """
  
  @callback validate_params(params :: map()) :: {:ok, map()} | {:error, term()}
  @callback start_scraping(params :: map(), opts :: keyword()) :: {:ok, term()} | {:error, term()}
  @callback process_results(results :: term()) :: term()
end

defmodule EhsEnforcement.Scraping.Agencies.Hse do
  @behaviour EhsEnforcement.Scraping.AgencyBehavior
  
  @impl true
  def validate_params(params) do
    # HSE-specific validation (requires start_page, end_page)
  end
  
  @impl true  
  def start_scraping(params, opts) do
    # HSE-specific scraping logic
  end
end

defmodule EhsEnforcement.Scraping.Agencies.Ea do
  @behaviour EhsEnforcement.Scraping.AgencyBehavior
  
  @impl true
  def validate_params(params) do
    # EA-specific validation (requires date_from, date_to)
  end
  
  @impl true
  def start_scraping(params, opts) do
    # EA-specific scraping logic
  end
end
```

**Coordinator Update**:
```elixir
def start_scraping(scrape_request, opts \\ []) do
  agency_module = get_agency_module(scrape_request.agency)
  
  with {:ok, validated_params} <- agency_module.validate_params(scrape_request),
       {:ok, results} <- agency_module.start_scraping(validated_params, opts) do
    agency_module.process_results(results)
  end
end

defp get_agency_module(:hse), do: EhsEnforcement.Scraping.Agencies.Hse
defp get_agency_module(:ea), do: EhsEnforcement.Scraping.Agencies.Ea
```

## 📊 Impact Assessment

### Before Refactoring
- **Complexity**: 6/10
- **Maintainability**: Medium (field name confusion, template duplication)
- **Runtime Issues**: KeyError on EA processing logs
- **Code Duplication**: 3 areas of unnecessary duplication

### After Refactoring  
- **Complexity**: 4/10
- **Maintainability**: High (unified resources, clear separation)
- **Runtime Issues**: Eliminated
- **Code Duplication**: Minimal, well-abstracted

## 🎯 Implementation Plan

### Phase 1: Critical Fixes (High Priority)
1. **Create unified ProcessingLog resource**
2. **Migrate existing HSE/EA logs to new structure**
3. **Update templates to use unified field names**
4. **Remove old processing log resources**

### Phase 2: UI Improvements (Medium Priority)  
1. **Create unified progress component**
2. **Update scraping templates**
3. **Remove agency-specific progress components**

### Phase 3: Architecture Enhancement (Future)
1. **Implement agency behavior pattern**
2. **Refactor scraping coordinator**
3. **Add new agency support easily**

## 🔍 Additional Notes

### Non-Issues Found
- **Case statements**: All case statements follow proper Elixir patterns
- **Error handling**: Consistent {:ok, result} | {:error, reason} patterns
- **Module organization**: Clear, logical structure
- **Ash integration**: Proper use of resources and actions

### Code Quality
The codebase demonstrates **good Elixir practices** overall. The complexity issues are **architectural** rather than **syntactic**, focusing on unnecessary duplication rather than anti-patterns.

## Conclusion

The EHS Enforcement scraping system is **well-architected** but suffers from **agency-specific duplication** that can be resolved through proper abstraction. The recommended refactoring will eliminate runtime errors, reduce complexity, and make adding new agencies significantly easier.

**Priority**: Focus on **Phase 1** to resolve immediate runtime issues, then consider **Phase 2** for UI improvements.