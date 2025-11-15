/**
 * Database Type Definitions
 *
 * TypeScript types mirroring Ash resources from EhsEnforcement.Enforcement
 * These types are used by TanStack DB collections for type safety.
 */

/**
 * Case Type
 * Mirrors: EhsEnforcement.Enforcement.Case
 */
export interface Case {
  // Primary key
  id: string

  // Core case identification
  case_reference: string | null
  regulator_id: string | null

  // Offense details
  offence_result: string | null
  offence_fine: number | null
  offence_costs: number | null
  offence_action_date: string | null // ISO date string
  offence_hearing_date: string | null // ISO date string
  offence_action_type: string | null
  offence_breaches: string | null

  // Regulator information
  regulator_function: string | null
  regulator_url: string | null

  // EA-specific fields
  ea_event_reference: string | null
  ea_total_violation_count: number | null
  environmental_impact: string | null
  environmental_receptor: string | null
  is_ea_multi_violation: boolean | null

  // Relationships (foreign keys)
  agency_id: string
  offender_id: string

  // Metadata
  url: string | null
  related_cases: string | null
  last_synced_at: string | null // ISO datetime string

  // Timestamps
  inserted_at: string // ISO datetime string
  updated_at: string // ISO datetime string
}

/**
 * Agency Type
 * Mirrors: EhsEnforcement.Enforcement.Agency
 */
export interface Agency {
  id: string
  name: string
  acronym: string | null
  country: string | null
  website: string | null
  inserted_at: string
  updated_at: string
}

/**
 * Offender Type
 * Mirrors: EhsEnforcement.Enforcement.Offender
 */
export interface Offender {
  id: string
  name: string
  address: string | null
  postcode: string | null
  country: string | null
  company_number: string | null
  inserted_at: string
  updated_at: string
}
