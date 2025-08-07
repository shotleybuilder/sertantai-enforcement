# Customizable Table Columns Feature Plan

## Overview
Create a comprehensive feature that allows users to customize which fields are displayed in data tables (starting with the notices table), with support for column reordering, persistence across sessions, and integration with existing filtering and export functionality.

## Business Requirements

### User Stories
- **As a user**, I want to choose which columns are visible so I can focus on relevant data
- **As a user**, I want to reorder columns so I can organize information according to my workflow
- **As a user**, I want my column preferences saved so I don't have to reconfigure each time
- **As an admin**, I want to export only the visible columns to create focused reports
- **As a user**, I want to share specific column configurations via URLs for collaboration

### Success Criteria
- Users can toggle column visibility with immediate table updates
- Column preferences persist across browser sessions
- Export functionality respects visible column selection
- Interface is intuitive and doesn't impact table performance
- Feature works consistently across all data tables in the application

## Technical Architecture

### 1. Frontend Components

#### Column Selection UI
```heex
<!-- Column Configuration Modal -->
<div class="fixed inset-0 z-50" phx-click="close_column_modal" style="display: none;" id="column-modal">
  <div class="bg-white rounded-lg shadow-xl max-w-md mx-auto mt-20">
    <div class="px-4 py-5 sm:p-6">
      <h3 class="text-lg font-medium text-gray-900 mb-4">Customize Columns</h3>
      
      <!-- Available Columns with Checkboxes -->
      <div class="space-y-3 max-h-64 overflow-y-auto">
        <%= for column <- @available_columns do %>
          <label class="flex items-center">
            <input 
              type="checkbox" 
              phx-click="toggle_column" 
              phx-value-column={column.key}
              checked={column.key in @visible_columns}
              class="h-4 w-4 text-indigo-600 rounded"
            />
            <span class="ml-2 text-sm text-gray-700"><%= column.label %></span>
          </label>
        <% end %>
      </div>
      
      <!-- Action Buttons -->
      <div class="mt-5 flex justify-between">
        <button phx-click="reset_columns" class="text-sm text-gray-500 hover:text-gray-700">
          Reset to Default
        </button>
        <div class="space-x-2">
          <button phx-click="close_column_modal" class="px-3 py-2 text-sm border rounded">
            Cancel
          </button>
          <button phx-click="save_column_preferences" class="px-3 py-2 text-sm bg-indigo-600 text-white rounded">
            Save
          </button>
        </div>
      </div>
    </div>
  </div>
</div>

<!-- Column Configuration Trigger -->
<button phx-click="open_column_modal" class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50">
  <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6V4m0 2a2 2 0 100 4m0-4a2 2 0 110 4m-6 8a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4m6 6v10m6-2a2 2 0 100-4m0 4a2 2 0 100 4m0-4v2m0-6V4"></path>
  </svg>
  Customize Columns
</button>
```

#### Dynamic Table Headers
```heex
<thead class="bg-gray-50">
  <tr>
    <%= for column_key <- @visible_columns do %>
      <% column = get_column_config(column_key, @available_columns) %>
      <th 
        scope="col" 
        class={[
          "px-3 py-3.5 text-left text-sm font-semibold text-gray-900",
          column.sortable && "cursor-pointer hover:bg-gray-100"
        ]}
        phx-click={column.sortable && "sort"}
        phx-value-field={column_key}
      >
        <%= column.label %>
        <%= if column.sortable, do: get_sort_icon(assigns, column_key) %>
      </th>
    <% end %>
    <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-6">
      <span class="sr-only">Actions</span>
    </th>
  </tr>
</thead>
```

#### Dynamic Table Cells
```heex
<tbody class="divide-y divide-gray-200 bg-white">
  <%= for notice <- @notices do %>
    <tr>
      <%= for column_key <- @visible_columns do %>
        <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-900">
          <%= render_column_value(notice, column_key) %>
        </td>
      <% end %>
      <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-6">
        <.link navigate={~p"/notices/#{notice.id}"} class="text-indigo-600 hover:text-indigo-900">
          View
        </.link>
      </td>
    </tr>
  <% end %>
</tbody>
```

### 2. Backend State Management

#### LiveView Socket State
```elixir
def mount(_params, _session, socket) do
  available_columns = [
    %{key: :regulator_id, label: "Notice ID", sortable: true, default: true},
    %{key: :offence_action_type, label: "Notice Type", sortable: true, default: true},
    %{key: :offender_name, label: "Offender", sortable: true, default: true},
    %{key: :agency_name, label: "Agency", sortable: false, default: true},
    %{key: :notice_date, label: "Notice Date", sortable: true, default: true},
    %{key: :compliance_date, label: "Compliance Date", sortable: true, default: false},
    %{key: :operative_date, label: "Operative Date", sortable: true, default: false},
    %{key: :notice_body, label: "Notice Body", sortable: false, default: false},
    %{key: :offence_breaches, label: "Breaches", sortable: false, default: false},
    %{key: :url, label: "Source URL", sortable: false, default: false}
  ]
  
  default_visible_columns = available_columns
    |> Enum.filter(& &1.default)
    |> Enum.map(& &1.key)
  
  # Load user preferences from localStorage or use defaults
  visible_columns = get_user_column_preferences(socket) || default_visible_columns
  
  {:ok,
   socket
   |> assign(:available_columns, available_columns)
   |> assign(:visible_columns, visible_columns)
   |> assign(:column_modal_open, false)
   |> assign(:page_title, "Notice Management")
   # ... other existing assigns
  }
end
```

#### Event Handlers
```elixir
def handle_event("open_column_modal", _params, socket) do
  {:noreply, assign(socket, :column_modal_open, true)}
end

def handle_event("close_column_modal", _params, socket) do
  {:noreply, assign(socket, :column_modal_open, false)}
end

def handle_event("toggle_column", %{"column" => column_key}, socket) do
  column_atom = String.to_existing_atom(column_key)
  current_columns = socket.assigns.visible_columns
  
  updated_columns = if column_atom in current_columns do
    List.delete(current_columns, column_atom)
  else
    current_columns ++ [column_atom]
  end
  
  # Ensure at least one column is always visible
  final_columns = if Enum.empty?(updated_columns) do
    [:regulator_id]  # Always show at least Notice ID
  else
    updated_columns
  end
  
  {:noreply, 
   socket
   |> assign(:visible_columns, final_columns)
   |> push_event("save-column-preferences", %{columns: final_columns})}
end

def handle_event("reset_columns", _params, socket) do
  default_columns = socket.assigns.available_columns
    |> Enum.filter(& &1.default)
    |> Enum.map(& &1.key)
  
  {:noreply,
   socket
   |> assign(:visible_columns, default_columns)
   |> push_event("save-column-preferences", %{columns: default_columns})}
end

def handle_event("reorder_columns", %{"columns" => new_order}, socket) do
  # Convert string keys back to atoms and filter to only include valid columns
  valid_column_keys = Enum.map(socket.assigns.available_columns, & &1.key)
  reordered_columns = new_order
    |> Enum.map(&String.to_existing_atom/1)
    |> Enum.filter(&(&1 in valid_column_keys))
  
  {:noreply,
   socket
   |> assign(:visible_columns, reordered_columns)
   |> push_event("save-column-preferences", %{columns: reordered_columns})}
end

def handle_event("save_column_preferences", _params, socket) do
  # This event is triggered after localStorage save is complete
  {:noreply, 
   socket
   |> assign(:column_modal_open, false)
   |> put_flash(:info, "Column preferences saved")}
end
```

### 3. Helper Functions

```elixir
defp get_column_config(column_key, available_columns) do
  Enum.find(available_columns, &(&1.key == column_key))
end

defp render_column_value(notice, column_key) do
  case column_key do
    :regulator_id -> 
      notice.regulator_id
    
    :offence_action_type -> 
      content_tag(:span, notice.offence_action_type, 
        class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{notice_type_class(notice.offence_action_type)}")
    
    :offender_name -> 
      if notice.offender do
        [
          content_tag(:div, notice.offender.name, class: "font-medium"),
          content_tag(:div, notice.offender.local_authority, class: "text-xs text-gray-500")
        ]
      else
        "—"
      end
    
    :agency_name -> 
      if notice.agency, do: notice.agency.name, else: "—"
    
    :notice_date -> 
      format_date(notice.notice_date)
    
    :compliance_date -> 
      format_date(notice.compliance_date)
    
    :operative_date -> 
      format_date(notice.operative_date)
    
    :notice_body -> 
      truncate_text(notice.notice_body, 100)
    
    :offence_breaches -> 
      truncate_text(notice.offence_breaches, 80)
    
    :url -> 
      if notice.url do
        content_tag(:a, "View Source", 
          href: notice.url, 
          target: "_blank",
          class: "text-indigo-600 hover:text-indigo-900 underline")
      else
        "—"
      end
    
    _ -> 
      "—"
  end
end

defp truncate_text(nil, _length), do: "—"
defp truncate_text(text, length) when byte_size(text) <= length, do: text
defp truncate_text(text, length), do: String.slice(text, 0, length) <> "..."

defp get_user_column_preferences(socket) do
  # This will be populated by JavaScript hook on mount
  # Returns nil initially, preferences loaded via client event
  nil
end
```

### 4. JavaScript Integration

#### LiveView Hook for localStorage
```javascript
// assets/js/hooks/column_preferences.js
export const ColumnPreferences = {
  mounted() {
    // Load preferences on mount
    const saved = localStorage.getItem('notices_visible_columns');
    if (saved) {
      try {
        const columns = JSON.parse(saved);
        this.pushEvent("load_column_preferences", { columns });
      } catch (e) {
        console.warn('Invalid column preferences in localStorage:', e);
      }
    }
    
    // Listen for save events
    this.handleEvent("save-column-preferences", ({ columns }) => {
      localStorage.setItem('notices_visible_columns', JSON.stringify(columns));
    });
  }
};

// assets/js/app.js
import { ColumnPreferences } from "./hooks/column_preferences";

let Hooks = {
  ColumnPreferences: ColumnPreferences
};

let liveSocket = new LiveSocket("/live", Socket, {
  params: { _csrf_token: csrfToken },
  hooks: Hooks
});
```

#### Drag and Drop for Column Reordering (Phase 2)
```javascript
// assets/js/hooks/column_reorder.js
import Sortable from 'sortablejs';

export const ColumnReorder = {
  mounted() {
    const container = this.el.querySelector('#column-list');
    this.sortable = Sortable.create(container, {
      animation: 150,
      ghostClass: 'opacity-50',
      onEnd: (evt) => {
        const columns = Array.from(container.children).map(el => 
          el.dataset.columnKey
        );
        this.pushEvent("reorder_columns", { columns });
      }
    });
  },
  
  destroyed() {
    if (this.sortable) {
      this.sortable.destroy();
    }
  }
};
```

### 5. Persistence Strategies

#### Phase 1: Browser localStorage
- **Pros**: Simple implementation, no backend changes, works immediately
- **Cons**: Not synced across devices, lost if storage cleared
- **Implementation**: JavaScript hooks save/load preferences

#### Phase 2: Database Storage
```elixir
# Migration
defmodule EhsEnforcement.Repo.Migrations.CreateUserPreferences do
  use Ecto.Migration
  
  def change do
    create table(:user_preferences, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id), null: false
      add :page, :string, null: false  # e.g., "notices", "cases"
      add :preferences, :map, null: false  # JSON storage
      
      timestamps()
    end
    
    create unique_index(:user_preferences, [:user_id, :page])
  end
end

# Ash Resource
defmodule EhsEnforcement.Accounts.UserPreference do
  use Ash.Resource,
    domain: EhsEnforcement.Accounts,
    data_layer: AshPostgres.DataLayer
  
  attributes do
    uuid_primary_key :id
    attribute :page, :string, allow_nil?: false
    attribute :preferences, :map, allow_nil?: false
    
    create_timestamp :inserted_at
    update_timestamp :updated_at
  end
  
  relationships do
    belongs_to :user, EhsEnforcement.Accounts.User, allow_nil?: false
  end
  
  actions do
    defaults [:read, :destroy]
    
    create :create do
      accept [:page, :preferences]
      argument :user_id, :uuid, allow_nil?: false
      change manage_relationship(:user_id, :user, type: :append_and_remove)
    end
    
    update :update do
      accept [:preferences]
    end
  end
end
```

#### Phase 3: URL Parameters (Shareable Configurations)
```elixir
def handle_params(%{"cols" => encoded_columns}, _url, socket) do
  case decode_column_params(encoded_columns) do
    {:ok, columns} ->
      valid_columns = validate_columns(columns, socket.assigns.available_columns)
      {:noreply, assign(socket, :visible_columns, valid_columns)}
    
    {:error, _} ->
      {:noreply, socket}
  end
end

defp decode_column_params(encoded) do
  with {:ok, decoded} <- Base.url_decode64(encoded),
       {:ok, columns} <- Jason.decode(decoded) do
    {:ok, Enum.map(columns, &String.to_existing_atom/1)}
  else
    _ -> {:error, :invalid_encoding}
  end
rescue
    _ -> {:error, :invalid_format}
end

defp generate_shareable_url(columns) do
  encoded = columns
    |> Enum.map(&to_string/1)
    |> Jason.encode!()
    |> Base.url_encode64()
  
  ~p"/notices?cols=#{encoded}"
end
```

### 6. Export Integration

#### Update Export Functions
```elixir
def handle_event("export", %{"format" => format}, socket) do
  visible_columns = socket.assigns.visible_columns
  notices = socket.assigns.notices
  
  case format do
    "csv" -> 
      csv_data = export_notices_csv(notices, visible_columns)
      {:noreply, push_event(socket, "download-csv", %{data: csv_data, filename: "notices.csv"})}
    
    "xlsx" ->
      # Generate Excel with only visible columns
      {:noreply, redirect(socket, external: export_notices_xlsx_url(visible_columns))}
  end
end

defp export_notices_csv(notices, visible_columns) do
  headers = visible_columns
    |> Enum.map(&get_column_label/1)
    |> Enum.join(",")
  
  rows = notices
    |> Enum.map(fn notice ->
      visible_columns
      |> Enum.map(&format_export_value(notice, &1))
      |> Enum.join(",")
    end)
  
  [headers | rows]
  |> Enum.join("\n")
end

defp format_export_value(notice, column_key) do
  case column_key do
    :offence_action_type -> notice.offence_action_type
    :offender_name -> if notice.offender, do: notice.offender.name, else: ""
    :agency_name -> if notice.agency, do: notice.agency.name, else: ""
    :notice_date -> if notice.notice_date, do: Date.to_string(notice.notice_date), else: ""
    # ... handle all column types for export
    _ -> ""
  end
  |> String.replace(",", ";")  # Escape commas for CSV
  |> String.replace("\n", " ")  # Replace newlines
end
```

## Implementation Phases

### Phase 1: Basic Column Selection (Week 1)
**Goal**: Users can show/hide columns with localStorage persistence

**Deliverables**:
- [ ] Column selection modal with checkboxes
- [ ] Dynamic table header/cell rendering
- [ ] Basic localStorage persistence via JavaScript hooks
- [ ] Reset to default functionality
- [ ] Integration with existing notices table

**Files to Create/Modify**:
- Modify: `lib/ehs_enforcement_web/live/notice_live/index.ex`
- Modify: `lib/ehs_enforcement_web/live/notice_live/index.html.heex`
- Create: `assets/js/hooks/column_preferences.js`
- Modify: `assets/js/app.js`

### Phase 2: Enhanced User Experience (Week 2)
**Goal**: Drag-and-drop reordering, database persistence, column grouping

**Deliverables**:
- [ ] Sortable.js integration for column reordering
- [ ] Database storage for logged-in users
- [ ] Column grouping in selection UI
- [ ] Improved modal design with search
- [ ] Column width optimization

**Files to Create/Modify**:
- Create: `lib/ehs_enforcement/accounts/resources/user_preference.ex`
- Create: Database migration for user_preferences table
- Create: `assets/js/hooks/column_reorder.js`
- Modify: Column selection UI templates
- Add: Column grouping logic

### Phase 3: Advanced Features (Week 3)
**Goal**: Resizable columns, export integration, URL sharing

**Deliverables**:
- [ ] Resizable columns with width persistence
- [ ] Export respects visible columns
- [ ] Shareable column configurations via URL
- [ ] Performance optimizations
- [ ] Comprehensive testing

**Files to Create/Modify**:
- Create: `assets/js/hooks/column_resize.js`
- Modify: Export controller to handle column selection
- Add: URL parameter handling for column configuration
- Create: Performance monitoring for large datasets
- Create: Comprehensive test suite

## Testing Strategy

### Unit Tests
```elixir
defmodule EhsEnforcementWeb.NoticeLive.IndexTest do
  use EhsEnforcementWeb.ConnCase, async: true
  import Phoenix.LiveViewTest
  
  describe "column customization" do
    test "default columns are visible", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notices")
      
      assert has_element?(view, "th", "Notice ID")
      assert has_element?(view, "th", "Notice Type")
      assert has_element?(view, "th", "Offender")
      assert has_element?(view, "th", "Agency")
      assert has_element?(view, "th", "Notice Date")
    end
    
    test "can toggle column visibility", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notices")
      
      view |> element("button", "Customize Columns") |> render_click()
      view |> element("input[phx-value-column='compliance_date']") |> render_click()
      
      assert has_element?(view, "th", "Compliance Date")
    end
    
    test "column preferences persist", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/notices")
      
      # Simulate localStorage load event
      render_hook(view, "load_column_preferences", %{
        columns: ["regulator_id", "notice_date", "compliance_date"]
      })
      
      assert has_element?(view, "th", "Notice ID")
      assert has_element?(view, "th", "Notice Date") 
      assert has_element?(view, "th", "Compliance Date")
      refute has_element?(view, "th", "Notice Type")
    end
  end
end
```

### Integration Tests
```elixir
defmodule EhsEnforcementWeb.NoticeExportTest do
  use EhsEnforcementWeb.ConnCase, async: true
  
  test "CSV export includes only visible columns", %{conn: conn} do
    notice = notice_fixture()
    
    {:ok, view, _html} = live(conn, ~p"/notices")
    
    # Set visible columns
    render_hook(view, "load_column_preferences", %{
      columns: ["regulator_id", "notice_date"]
    })
    
    view |> element("button", "Export") |> render_click()
    
    assert_push_event(view, "download-csv", %{data: csv_data})
    assert csv_data =~ "Notice ID,Notice Date"
    refute csv_data =~ "Notice Type"
  end
end
```

### Browser Tests
```javascript
// test/e2e/column_customization.spec.js
describe('Column Customization', () => {
  it('should save column preferences to localStorage', async () => {
    await page.goto('/notices');
    
    await page.click('button:has-text("Customize Columns")');
    await page.check('input[data-column="compliance_date"]');
    await page.click('button:has-text("Save")');
    
    const stored = await page.evaluate(() => 
      localStorage.getItem('notices_visible_columns')
    );
    
    expect(JSON.parse(stored)).toContain('compliance_date');
  });
  
  it('should restore preferences on page reload', async () => {
    // Set preferences
    await page.evaluate(() => {
      localStorage.setItem('notices_visible_columns', 
        JSON.stringify(['regulator_id', 'compliance_date']));
    });
    
    await page.goto('/notices');
    
    expect(page.locator('th:has-text("Notice ID")')).toBeVisible();
    expect(page.locator('th:has-text("Compliance Date")')).toBeVisible();
    expect(page.locator('th:has-text("Notice Type")')).not.toBeVisible();
  });
});
```

## Performance Considerations

### Rendering Optimization
- Use `Phoenix.Component` for column rendering helpers
- Implement memo patterns for expensive column calculations
- Lazy load column data for large datasets
- Virtual scrolling for tables with 1000+ rows

### Database Optimization
- Index user_preferences table on (user_id, page) for fast lookups
- Cache column configurations in socket assigns
- Batch preference updates to reduce database calls

### Frontend Optimization
- Debounce localStorage writes during rapid column changes
- Use CSS transforms for smooth column reordering animations
- Implement column width caching to prevent layout shifts

## Security Considerations

### Input Validation
- Whitelist valid column keys to prevent injection
- Sanitize column labels and values for XSS prevention
- Validate column order arrays for proper structure

### Access Control
- Ensure column visibility doesn't bypass data permissions
- Audit logging for sensitive column access
- Rate limiting for preference save operations

## Maintenance and Extension

### Adding New Tables
The column customization system is designed to be reusable:

1. **Define available columns** for the new table
2. **Add JavaScript hook** with table-specific localStorage key
3. **Implement column rendering** helpers for the table's data types
4. **Copy event handlers** and adapt for the new LiveView

### Future Enhancements
- **Column Templates**: Predefined column sets for different use cases
- **Advanced Filtering**: Per-column filter controls
- **Data Visualization**: Chart integration with selected columns
- **Bulk Operations**: Actions on selected columns/rows
- **Mobile Optimization**: Responsive column selection for mobile devices

## File Structure
```
lib/ehs_enforcement_web/
├── live/
│   └── notice_live/
│       ├── index.ex                    # Enhanced with column logic
│       └── index.html.heex            # Dynamic table templates
├── controllers/
│   └── notice_controller.ex           # Export with column selection
└── components/
    └── table_components.ex            # Reusable column components

assets/js/
├── hooks/
│   ├── column_preferences.js          # localStorage management
│   ├── column_reorder.js             # Drag-and-drop functionality
│   └── column_resize.js              # Resizable columns
└── app.js                            # Hook registration

lib/ehs_enforcement/
└── accounts/
    └── resources/
        └── user_preference.ex         # Database persistence

docs/
└── guides/
    └── customizable_columns.md       # User documentation

test/
├── ehs_enforcement_web/
│   └── live/
│       └── notice_live/
│           └── index_test.exs         # Column functionality tests
└── e2e/
    └── column_customization.spec.js   # Browser tests
```

This comprehensive plan provides a solid foundation for implementing customizable table columns that will enhance user experience and provide flexible data views across the application.

## Open Source Library Research

### Existing Libraries on Hex.pm

We researched existing Phoenix LiveView table libraries to determine if this functionality already exists:

#### 1. **LiveTable** (`live_table`)
- **Most comprehensive** table solution for Phoenix LiveView
- Features: Sorting, filtering, pagination, multiple view modes (table/card), export (CSV/PDF)
- **Unclear** if it supports column visibility toggling or reordering
- Actively maintained and well-documented

#### 2. **Exzeitable** (`exzeitable`) 
- Provides "dynamically updating, searchable, sortable datatables"
- Requires PostgreSQL with pg_trgm extension
- **No clear indication** of column customization features from documentation

#### 3. **Phoenix Better Table** (`phoenix_better_table`)
- Version 0.5.0, requires LiveView >= 0.18.0
- Allows custom render functions for columns
- **Limited information** available about advanced column customization

### Key Finding

**None of the existing libraries provide the specific column customization features** outlined in this plan:
- ✗ User-selectable column visibility
- ✗ Drag-and-drop column reordering  
- ✗ Column preference persistence (localStorage/database)
- ✗ Shareable column configurations via URL

### Recommendation

Our custom implementation plan remains the best approach because:

1. **No existing library fully addresses the requirements** for user-customizable column visibility and reordering
2. **Our plan is more comprehensive** than what's currently available on Hex
3. **Potential for open source contribution** - our implementation could fill a gap in the Phoenix LiveView ecosystem
4. **Tailored to our specific needs** with Ash framework integration

## Future Open Source Opportunity

Once we implement this feature successfully, we could consider:
- **Extracting it into a reusable library**
- **Publishing on Hex.pm** as `phoenix_customizable_table` or similar
- **Contributing to the Phoenix LiveView ecosystem**

Our implementation would create something genuinely useful that doesn't currently exist in the open source Phoenix LiveView community, filling a clear gap in available table customization solutions.