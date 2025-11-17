/**
 * Server-Sent Events (SSE) Store for Scraping Progress
 *
 * Manages EventSource connection and parses SSE events from backend
 */

import { writable } from 'svelte/store'
import type { SSEEvent, ProgressEvent, RecordProcessedEvent, ErrorEvent, CompletedEvent } from '$lib/types/scraping'

const API_BASE_URL = 'http://localhost:4002/api'

export interface SSEConnectionState {
  connected: boolean
  error: string | null
  lastEvent: SSEEvent | null
}

/**
 * Create an SSE store for a scraping session
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { createSSEStore } from '$lib/stores/sse'
 *
 *   const sse = createSSEStore()
 *
 *   // Connect to session
 *   sse.connect(sessionId)
 *
 *   // Subscribe to events
 *   $: if ($sse.lastEvent) {
 *     handleSSEEvent($sse.lastEvent)
 *   }
 *
 *   // Disconnect when done
 *   onDestroy(() => {
 *     sse.disconnect()
 *   })
 * </script>
 * ```
 */
export function createSSEStore() {
  const { subscribe, set, update } = writable<SSEConnectionState>({
    connected: false,
    error: null,
    lastEvent: null,
  })

  let eventSource: EventSource | null = null

  function connect(sessionId: string) {
    // Close existing connection if any
    disconnect()

    const url = `${API_BASE_URL}/scraping/subscribe/${sessionId}`
    console.log('[SSE] Connecting to:', url)

    try {
      eventSource = new EventSource(url)

      // Connection opened
      eventSource.onopen = () => {
        console.log('[SSE] Connection opened')
        update(state => ({
          ...state,
          connected: true,
          error: null,
        }))
      }

      // Generic error handler
      eventSource.onerror = (error) => {
        console.error('[SSE] Connection error:', error)
        update(state => ({
          ...state,
          connected: false,
          error: 'Connection error',
        }))

        // EventSource automatically reconnects, but if readyState is CLOSED, we should clean up
        if (eventSource?.readyState === EventSource.CLOSED) {
          console.log('[SSE] Connection closed, cleaning up')
          disconnect()
        }
      }

      // Progress events
      eventSource.addEventListener('progress', (event) => {
        try {
          const data: ProgressEvent = JSON.parse(event.data)
          console.log('[SSE] Progress:', data)
          update(state => ({
            ...state,
            lastEvent: { type: 'progress', data },
          }))
        } catch (err) {
          console.error('[SSE] Failed to parse progress event:', err)
        }
      })

      // Record processed events
      eventSource.addEventListener('record_processed', (event) => {
        try {
          const data: RecordProcessedEvent = JSON.parse(event.data)
          console.log('[SSE] Record processed:', data)
          update(state => ({
            ...state,
            lastEvent: { type: 'record_processed', data },
          }))
        } catch (err) {
          console.error('[SSE] Failed to parse record_processed event:', err)
        }
      })

      // Error events
      eventSource.addEventListener('error', (event) => {
        try {
          const data: ErrorEvent = JSON.parse((event as MessageEvent).data)
          console.error('[SSE] Scraping error:', data)
          update(state => ({
            ...state,
            lastEvent: { type: 'error', data },
          }))
        } catch (err) {
          console.error('[SSE] Failed to parse error event:', err)
        }
      })

      // Completed events
      eventSource.addEventListener('completed', (event) => {
        try {
          const data: CompletedEvent = JSON.parse(event.data)
          console.log('[SSE] Scraping completed:', data)
          update(state => ({
            ...state,
            lastEvent: { type: 'completed', data },
          }))

          // Auto-disconnect on completion
          setTimeout(() => {
            disconnect()
          }, 1000)
        } catch (err) {
          console.error('[SSE] Failed to parse completed event:', err)
        }
      })

      // Stopped events
      eventSource.addEventListener('stopped', (event) => {
        console.log('[SSE] Scraping stopped')
        update(state => ({
          ...state,
          lastEvent: { type: 'stopped', data: {} },
        }))

        // Auto-disconnect on stop
        setTimeout(() => {
          disconnect()
        }, 500)
      })

    } catch (err) {
      console.error('[SSE] Failed to create EventSource:', err)
      update(state => ({
        ...state,
        connected: false,
        error: `Failed to connect: ${err}`,
      }))
    }
  }

  function disconnect() {
    if (eventSource) {
      console.log('[SSE] Disconnecting')
      eventSource.close()
      eventSource = null
      set({
        connected: false,
        error: null,
        lastEvent: null,
      })
    }
  }

  return {
    subscribe,
    connect,
    disconnect,
  }
}
