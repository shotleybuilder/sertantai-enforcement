# EHS Enforcement - Frontend

Local-first SvelteKit frontend with ElectricSQL sync and TanStack DB.

## Tech Stack

- **SvelteKit**: Meta-framework for Svelte
- **TypeScript**: Type-safe development
- **TailwindCSS v4**: Utility-first CSS
- **ElectricSQL**: PostgreSQL sync to client
- **TanStack DB**: Local reactive database
- **Vitest**: Unit testing
- **ESLint + Prettier**: Code quality

## Getting Started

### Prerequisites

- Node.js 20+
- npm or pnpm

### Installation

```bash
# Install dependencies
npm install

# Copy environment template
cp .env.example .env.local

# Start development server
npm run dev
```

The app will be available at http://localhost:5173

## Development

### Available Scripts

```bash
npm run dev          # Start dev server (hot reload)
npm run build        # Build for production
npm run preview      # Preview production build
npm run check        # TypeScript type checking
npm run format       # Format code with Prettier
npm run lint         # Lint with ESLint
npm run test         # Run tests with Vitest
npm run test:ui      # Run tests with UI
```

### Project Structure

```
frontend/
├── src/
│   ├── lib/
│   │   ├── db/          # TanStack DB setup
│   │   ├── electric/    # ElectricSQL sync
│   │   └── components/  # Svelte components
│   ├── routes/          # SvelteKit routes (file-based routing)
│   └── app.html         # HTML template
├── static/              # Static assets
└── tests/               # Test files
```

## ElectricSQL Integration

The frontend uses ElectricSQL to sync data from PostgreSQL to a local TanStack DB instance.

### How it works:

1. **ElectricSQL** consumes PostgreSQL logical replication
2. **HTTP Shape API** streams changes to client
3. **TanStack DB** stores data locally (IndexedDB)
4. **Reactive queries** update UI automatically

### Example Usage:

```typescript
import { db } from '$lib/db'

// Reactive query - updates automatically when data changes
const cases = db.query((q) =>
  q.cases
    .where('organization_id', currentOrgId)
    .orderBy('created_at', 'desc')
)

// In Svelte component
{#each $cases as case}
  <CaseCard {case} />
{/each}
```

## TanStack DB Mutations

Client-side mutations with automatic sync:

```typescript
// Create
await db.mutate((m) =>
  m.cases.create({
    id: crypto.randomUUID(),
    title: 'New case',
    organization_id: currentOrgId
  })
)

// Update
await db.mutate((m) =>
  m.cases.update(caseId, { status: 'closed' })
)

// Delete
await db.mutate((m) =>
  m.cases.delete(caseId)
)
```

## Testing

```bash
# Run tests
npm test

# Run tests with UI
npm run test:ui

# Run tests with coverage
npm run test:coverage
```

## Build & Deploy

```bash
# Build for production
npm run build

# Preview production build
npm run preview
```

The build output will be in `build/` directory (static adapter).

## Environment Variables

See `.env.example` for all available configuration options.

Key variables:
- `PUBLIC_API_URL`: Phoenix backend URL
- `PUBLIC_ELECTRIC_URL`: ElectricSQL sync service URL
- `PUBLIC_ENV`: Environment (development/production)

## Contributing

See main project CLAUDE.md for development guidelines.
