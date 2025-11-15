/**
 * Example ElectricSQL Shape Connection
 *
 * This demonstrates how to sync data from PostgreSQL to the client
 * using ElectricSQL's HTTP Shape API.
 *
 * Shapes are the core abstraction in ElectricSQL - they define
 * what data to sync to the client.
 */

import { ShapeStream } from '@electric-sql/client'
import type { Case } from '$lib/types/case'

// Environment configuration
const ELECTRIC_URL = import.meta.env.PUBLIC_ELECTRIC_URL || 'http://localhost:3000'

/**
 * Create a shape stream for Cases table
 *
 * This will sync all cases for a specific organization
 * and keep them up to date in real-time.
 */
export function createCasesShape(organizationId: string) {
  const stream = new ShapeStream<Case>({
    url: `${ELECTRIC_URL}/v1/shape`,
    params: {
      table: 'cases',
      // Filter by organization for multi-tenancy
      where: `organization_id='${organizationId}'`
    }
  })

  return stream
}

/**
 * Subscribe to case updates
 *
 * Example usage:
 *
 * ```typescript
 * const stream = createCasesShape(currentOrgId)
 *
 * stream.subscribe((messages) => {
 *   messages.forEach(msg => {
 *     switch (msg.action) {
 *       case 'insert':
 *         // New case added
 *         db.collections.cases.insert(msg.value)
 *         break
 *       case 'update':
 *         // Case updated
 *         db.collections.cases.update(msg.value.id, msg.value)
 *         break
 *       case 'delete':
 *         // Case deleted
 *         db.collections.cases.delete(msg.value.id)
 *         break
 *     }
 *   })
 * })
 * ```
 */
export function subscribeToCases(
  organizationId: string,
  onMessage: (messages: any[]) => void
) {
  const stream = createCasesShape(organizationId)

  return stream.subscribe(onMessage)
}

/**
 * Unsubscribe from updates
 */
export function unsubscribeFromCases(subscription: any) {
  if (subscription && typeof subscription.unsubscribe === 'function') {
    subscription.unsubscribe()
  }
}
