---
name: tanstack-table-svelte-advanced
description: Implements advanced TanStack Table v8 features in Svelte including column filtering, resizing, visibility, sorting, and pagination with localStorage persistence. Use when working with TanStack Table in Svelte or when users request table customization features like filters, column management, or data persistence.
---

# TanStack Table Advanced Features for Svelte

This skill teaches how to implement advanced TanStack Table v8 features in Svelte 4 applications with localStorage persistence for user preferences.

## Prerequisites

Ensure TanStack Table is installed:

```bash
npm install @tanstack/svelte-table
```

Import required functions from `@tanstack/svelte-table` and Svelte's writable store from `svelte/store`.

## Core Pattern: State Management with Svelte Stores

TanStack Table requires writable stores for reactive state management:

```typescript
import { writable } from 'svelte/store'
import { createSvelteTable } from '@tanstack/svelte-table'

let data = writable([...]) // Your table data
let columns = [...] // Column definitions

const options = writable({
  data: $data,
  columns,
  getCoreRowModel: getCoreRowModel()
})

const table = createSvelteTable(options)
```

Access table state with `$table` syntax in Svelte templates.

## Column Visibility

Allow users to show/hide columns with a visibility picker.

**Add visibility state:**

```typescript
import { type VisibilityState } from '@tanstack/svelte-table'

const VISIBILITY_STORAGE_KEY = 'your_table_column_visibility'

function loadColumnVisibility(): VisibilityState {
  if (!browser) return {}
  try {
    const saved = localStorage.getItem(VISIBILITY_STORAGE_KEY)
    return saved ? JSON.parse(saved) : {}
  } catch {
    return {}
  }
}

let columnVisibility = writable<VisibilityState>(loadColumnVisibility())

$: if (browser) {
  localStorage.setItem(VISIBILITY_STORAGE_KEY, JSON.stringify($columnVisibility))
}
```

**Add to table options:**

```typescript
const options = writable({
  state: {
    columnVisibility: $columnVisibility
  },
  onColumnVisibilityChange: (updater) => {
    if (updater instanceof Function) {
      columnVisibility.update(updater)
    } else {
      columnVisibility.set(updater)
    }
  }
})
```

**Create visibility picker UI:**

```svelte
<div class="relative">
  <button on:click={() => showColumnPicker = !showColumnPicker}>
    Columns
  </button>

  {#if showColumnPicker}
    <div class="absolute right-0 mt-2 w-56 bg-white shadow-lg rounded-md">
      {#each $table.getAllLeafColumns() as column}
        {#if column.getCanHide()}
          <label class="flex items-center px-4 py-2 hover:bg-gray-50">
            <input
              type="checkbox"
              checked={column.getIsVisible()}
              on:change={column.getToggleVisibilityHandler()}
            />
            <span class="ml-2">{column.id}</span>
          </label>
        {/if}
      {/each}
    </div>
  {/if}
</div>
```

## Column Filtering

Enable per-column filtering with various filter types.

**Add filtering state:**

```typescript
import { getFilteredRowModel, type ColumnFiltersState } from '@tanstack/svelte-table'

const FILTERS_STORAGE_KEY = 'your_table_column_filters'

function loadColumnFilters(): ColumnFiltersState {
  if (!browser) return []
  try {
    const saved = localStorage.getItem(FILTERS_STORAGE_KEY)
    return saved ? JSON.parse(saved) : []
  } catch {
    return []
  }
}

let columnFilters = writable<ColumnFiltersState>(loadColumnFilters())

$: if (browser) {
  localStorage.setItem(FILTERS_STORAGE_KEY, JSON.stringify($columnFilters))
}
```

**Add to table options:**

```typescript
const options = writable({
  state: {
    columnFilters: $columnFilters
  },
  onColumnFiltersChange: (updater) => {
    if (updater instanceof Function) {
      columnFilters.update(updater)
    } else {
      columnFilters.set(updater)
    }
  },
  getFilteredRowModel: getFilteredRowModel()
})
```

**Create filter UI:**

For dropdown filters (exact match):

```svelte
<select
  value={$table.getColumn('columnId')?.getFilterValue() ?? ''}
  on:change={(e) => $table.getColumn('columnId')?.setFilterValue(e.currentTarget.value || undefined)}
>
  <option value="">All</option>
  {#each uniqueValues as value}
    <option value={value}>{value}</option>
  {/each}
</select>
```

For text filters (case-insensitive):

```svelte
<input
  type="text"
  value={$table.getColumn('columnId')?.getFilterValue() ?? ''}
  on:input={(e) => $table.getColumn('columnId')?.setFilterValue(e.currentTarget.value || undefined)}
  placeholder="Search..."
/>
```

**Clear all filters:**

```typescript
function clearAllFilters() {
  columnFilters.set([])
}

$: hasActiveFilters = $columnFilters.length > 0
```

## Column Resizing

Allow users to drag column borders to adjust widths.

**Add resizing state:**

```typescript
import { type ColumnSizingState } from '@tanstack/svelte-table'

const SIZING_STORAGE_KEY = 'your_table_column_sizing'

function loadColumnSizing(): ColumnSizingState {
  if (!browser) return {}
  try {
    const saved = localStorage.getItem(SIZING_STORAGE_KEY)
    return saved ? JSON.parse(saved) : {}
  } catch {
    return {}
  }
}

let columnSizing = writable<ColumnSizingState>(loadColumnSizing())

$: if (browser) {
  localStorage.setItem(SIZING_STORAGE_KEY, JSON.stringify($columnSizing))
}
```

**Add to table options:**

```typescript
const options = writable({
  state: {
    columnSizing: $columnSizing
  },
  onColumnSizingChange: (updater) => {
    if (updater instanceof Function) {
      columnSizing.update(updater)
    } else {
      columnSizing.set(updater)
    }
  },
  columnResizeMode: 'onChange', // Real-time updates
  enableColumnResizing: true
})
```

**Add resize handles to column headers:**

```svelte
{#each $table.getHeaderGroups() as headerGroup}
  <tr>
    {#each headerGroup.headers as header}
      <th style="width: {header.getSize()}px; position: relative;">
        {header.column.columnDef.header}

        {#if header.column.getCanResize()}
          <div
            on:mousedown={header.getResizeHandler()}
            on:touchstart={header.getResizeHandler()}
            class="absolute right-0 top-0 h-full w-1 cursor-col-resize hover:bg-indigo-500"
            class:bg-indigo-600={header.column.getIsResizing()}
          />
        {/if}
      </th>
    {/each}
  </tr>
{/each}
```

## Column Sorting

Enable click-to-sort on column headers.

**Add sorting state:**

```typescript
import { getSortedRowModel, type SortingState } from '@tanstack/svelte-table'

const SORTING_STORAGE_KEY = 'your_table_sorting'

function loadSorting(): SortingState {
  if (!browser) return []
  try {
    const saved = localStorage.getItem(SORTING_STORAGE_KEY)
    return saved ? JSON.parse(saved) : []
  } catch {
    return []
  }
}

let sorting = writable<SortingState>(loadSorting())

$: if (browser) {
  localStorage.setItem(SORTING_STORAGE_KEY, JSON.stringify($sorting))
}
```

**Add to table options:**

```typescript
const options = writable({
  state: {
    sorting: $sorting
  },
  onSortingChange: (updater) => {
    if (updater instanceof Function) {
      sorting.update(updater)
    } else {
      sorting.set(updater)
    }
  },
  getSortedRowModel: getSortedRowModel()
})
```

**Make headers sortable:**

```svelte
<th on:click={header.column.getToggleSortingHandler()}>
  <div class="flex items-center gap-2">
    {header.column.columnDef.header}
    {#if header.column.getIsSorted() === 'asc'}
      ↑
    {:else if header.column.getIsSorted() === 'desc'}
      ↓
    {/if}
  </div>
</th>
```

## Pagination

Add pagination controls for large datasets.

**Add pagination state:**

```typescript
import { getPaginationRowModel, type PaginationState } from '@tanstack/svelte-table'

const PAGINATION_STORAGE_KEY = 'your_table_pagination'

function loadPagination(): PaginationState {
  if (!browser) return { pageIndex: 0, pageSize: 10 }
  try {
    const saved = localStorage.getItem(PAGINATION_STORAGE_KEY)
    return saved ? JSON.parse(saved) : { pageIndex: 0, pageSize: 10 }
  } catch {
    return { pageIndex: 0, pageSize: 10 }
  }
}

let pagination = writable<PaginationState>(loadPagination())

$: if (browser) {
  localStorage.setItem(PAGINATION_STORAGE_KEY, JSON.stringify($pagination))
}
```

**Add to table options:**

```typescript
const options = writable({
  state: {
    pagination: $pagination
  },
  onPaginationChange: (updater) => {
    if (updater instanceof Function) {
      pagination.update(updater)
    } else {
      pagination.set(updater)
    }
  },
  getPaginationRowModel: getPaginationRowModel()
})
```

**Create pagination UI:**

```svelte
<div class="flex items-center gap-4">
  <button
    on:click={() => $table.setPageIndex(0)}
    disabled={!$table.getCanPreviousPage()}
  >
    First
  </button>

  <button
    on:click={() => $table.previousPage()}
    disabled={!$table.getCanPreviousPage()}
  >
    Previous
  </button>

  <span>
    Page {$table.getState().pagination.pageIndex + 1} of {$table.getPageCount()}
  </span>

  <button
    on:click={() => $table.nextPage()}
    disabled={!$table.getCanNextPage()}
  >
    Next
  </button>

  <button
    on:click={() => $table.setPageIndex($table.getPageCount() - 1)}
    disabled={!$table.getCanNextPage()}
  >
    Last
  </button>

  <select
    value={$table.getState().pagination.pageSize}
    on:change={(e) => $table.setPageSize(Number(e.currentTarget.value))}
  >
    {#each [10, 20, 50, 100] as pageSize}
      <option value={pageSize}>{pageSize} rows</option>
    {/each}
  </select>
</div>
```

## Complete Example Pattern

Combine all features in your component:

```typescript
import { writable } from 'svelte/store'
import { browser } from '$app/environment'
import {
  createSvelteTable,
  getCoreRowModel,
  getFilteredRowModel,
  getSortedRowModel,
  getPaginationRowModel,
  type ColumnDef,
  type VisibilityState,
  type ColumnFiltersState,
  type ColumnSizingState,
  type SortingState,
  type PaginationState,
  flexRender
} from '@tanstack/svelte-table'

// Load all persisted states
let columnVisibility = writable<VisibilityState>(loadColumnVisibility())
let columnFilters = writable<ColumnFiltersState>(loadColumnFilters())
let columnSizing = writable<ColumnSizingState>(loadColumnSizing())
let sorting = writable<SortingState>(loadSorting())
let pagination = writable<PaginationState>(loadPagination())

// Create table with all features
const options = writable({
  data: $data,
  columns,
  state: {
    columnVisibility: $columnVisibility,
    columnFilters: $columnFilters,
    columnSizing: $columnSizing,
    sorting: $sorting,
    pagination: $pagination
  },
  onColumnVisibilityChange: (updater) => { /* ... */ },
  onColumnFiltersChange: (updater) => { /* ... */ },
  onColumnSizingChange: (updater) => { /* ... */ },
  onSortingChange: (updater) => { /* ... */ },
  onPaginationChange: (updater) => { /* ... */ },
  getCoreRowModel: getCoreRowModel(),
  getFilteredRowModel: getFilteredRowModel(),
  getSortedRowModel: getSortedRowModel(),
  getPaginationRowModel: getPaginationRowModel(),
  columnResizeMode: 'onChange',
  enableColumnResizing: true
})

const table = createSvelteTable(options)
```

## Column Reordering

Use native HTML5 drag and drop API for column reordering (no external dependencies).

**Add column order state:**

```typescript
import { type ColumnOrderState } from '@tanstack/svelte-table'

const ORDER_STORAGE_KEY = 'your_table_column_order'

function loadColumnOrder(): ColumnOrderState {
  if (!browser) return []
  try {
    const saved = localStorage.getItem(ORDER_STORAGE_KEY)
    return saved ? JSON.parse(saved) : []
  } catch {
    return []
  }
}

let columnOrder = writable<ColumnOrderState>(loadColumnOrder())

$: if (browser) {
  localStorage.setItem(ORDER_STORAGE_KEY, JSON.stringify($columnOrder))
}

// Initialize column order if empty
$: if ($columnOrder.length === 0 && columns.length > 0) {
  columnOrder.set(columns.map((col) => col.accessorKey || col.id) as string[])
}
```

**Add to table options:**

```typescript
const options = writable({
  state: {
    columnOrder: $columnOrder
  },
  onColumnOrderChange: (updater) => {
    if (updater instanceof Function) {
      columnOrder.update(updater)
    } else {
      columnOrder.set(updater)
    }
  }
})
```

**Implement drag and drop handlers:**

```typescript
let draggedColumnId: string | null = null

function handleDragStart(columnId: string) {
  draggedColumnId = columnId
}

function handleDragOver(event: DragEvent) {
  event.preventDefault() // Required to allow drop
}

function handleDrop(targetColumnId: string) {
  if (!draggedColumnId || draggedColumnId === targetColumnId) {
    draggedColumnId = null
    return
  }

  const oldIndex = $columnOrder.indexOf(draggedColumnId)
  const newIndex = $columnOrder.indexOf(targetColumnId)

  if (oldIndex !== -1 && newIndex !== -1) {
    const newColumnOrder = [...$columnOrder]
    const [movedColumn] = newColumnOrder.splice(oldIndex, 1)
    newColumnOrder.splice(newIndex, 0, movedColumn)
    columnOrder.set(newColumnOrder)
  }

  draggedColumnId = null
}
```

**Make headers draggable:**

```svelte
<th
  draggable="true"
  on:dragstart={() => handleDragStart(header.column.id)}
  on:dragover={handleDragOver}
  on:drop|preventDefault={() => handleDrop(header.column.id)}
  class:opacity-50={draggedColumnId === header.column.id}
  style="cursor: grab;"
>
```

**Note:** Avoid `@dnd-kit` (React-only, uses React hooks incompatible with Svelte). Native HTML5 API is simpler and requires no dependencies.

## Best Practices

1. **Always check `browser` before accessing localStorage** - prevents SSR errors
2. **Use try-catch for localStorage operations** - handles quota exceeded and parsing errors
3. **Unique storage keys** - prevent conflicts between different tables
4. **Default values** - provide sensible defaults when localStorage is empty
5. **Reactive persistence** - use `$:` to save state changes automatically
6. **Type safety** - import TanStack Table types for proper TypeScript support

## Troubleshooting

**"ctx[2].getState is not a function" error:**
- Ensure `options` is a writable store, not a plain object
- Pattern: `const options = writable({ ... })`

**Filters/sorting not persisting:**
- Verify storage keys are unique
- Check browser console for localStorage errors
- Ensure reactive statement `$:` is saving state changes

**Column widths reset on reload:**
- Apply `width: {header.getSize()}px` inline style to `<th>` elements
- Verify `columnResizeMode: 'onChange'` is set

**SSR errors with localStorage:**
- Always wrap localStorage calls with `if (!browser) return defaultValue`
- Import `{ browser }` from `'$app/environment'`
