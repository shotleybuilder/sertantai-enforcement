# TanStack DB Setup

This directory contains the TanStack DB configuration for the local-first database.

## Overview

TanStack DB provides:
- **Reactive queries**: Automatically update when data changes
- **Local storage**: Data persists in IndexedDB
- **Normalized storage**: Efficient data organization
- **Mutations**: Built-in optimistic updates with sync

## Setup (To be implemented in Week 3-4)

1. Define database schema matching Ash resources
2. Configure ElectricSQL sync
3. Set up reactive queries
4. Implement mutations

## Example Structure

```typescript
// db/schema.ts
export const schema = {
  cases: {
    id: 'string',
    organization_id: 'string',
    title: 'string',
    status: 'string',
    created_at: 'timestamp'
  },
  notices: {
    // ...
  },
  offenders: {
    // ...
  }
}

// db/index.ts
import { createDB } from '@tanstack/db'
import { schema } from './schema'

export const db = createDB({
  schema,
  storage: 'indexeddb'
})
```

## Usage

```typescript
// Reactive query
const cases = db.query((q) =>
  q.cases
    .where('organization_id', orgId)
    .where('status', 'open')
    .orderBy('created_at', 'desc')
)

// Use in Svelte component
{#each $cases as case}
  <CaseCard {case} />
{/each}

// Mutation
await db.mutate((m) =>
  m.cases.update(caseId, { status: 'closed' })
)
```

## See Also

- [TanStack DB Docs](https://tanstack.com/db/latest)
- [ElectricSQL Integration](../electric/README.md)
- Main migration plan: `.claude/sessions/2025-11-15-local-first-migration-plan.md`
