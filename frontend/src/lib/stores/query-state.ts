import { writable } from 'svelte/store'

export interface QueryState {
  query: string
  filters: any[]
  sort: any | null
  columns?: string[]
  columnOrder?: string[]
  timestamp: number
}

function createQueryStore() {
  const { subscribe, set, update } = writable<QueryState | null>(null)

  return {
    subscribe,
    setQuery: (state: Omit<QueryState, 'timestamp'>) => {
      set({ ...state, timestamp: Date.now() })
    },
    clear: () => set(null)
  }
}

export const queryState = createQueryStore()
