/**
 * TanStack Query functions for Scraping Configurations
 *
 * Queries and mutations for managing scraping configuration profiles
 */

import { createQuery, createMutation } from '@tanstack/svelte-query'
import { queryClient } from '$lib/query/client'

const API_BASE_URL = 'http://localhost:4002/api/configuration/scraping_configs'

/**
 * Scraping Config type based on Ash resource schema
 */
export interface ScrapingConfig {
  id: string
  name: string
  description: string | null
  is_active: boolean

  // HSE Configuration
  hse_base_url: string
  hse_database: 'convictions' | 'enforcement' | 'notices'

  // Rate Limiting
  requests_per_minute: number
  network_timeout_ms: number
  pause_between_pages_ms: number

  // Scraping Behavior
  consecutive_existing_threshold: number
  max_pages_per_session: number
  max_consecutive_errors: number
  batch_size: number

  // Feature Flags
  scheduled_scraping_enabled: boolean
  manual_scraping_enabled: boolean
  real_time_progress_enabled: boolean
  admin_notifications_enabled: boolean

  // Schedules (cron expressions)
  daily_scrape_cron: string | null
  weekly_scrape_cron: string | null

  // Metadata
  inserted_at: string
  updated_at: string
}

/**
 * Query key factory
 */
export const scrapingConfigKeys = {
  all: ['scraping-configs'] as const,
  lists: () => [...scrapingConfigKeys.all, 'list'] as const,
  list: (filters?: any) => [...scrapingConfigKeys.lists(), filters] as const,
  details: () => [...scrapingConfigKeys.all, 'detail'] as const,
  detail: (id: string) => [...scrapingConfigKeys.details(), id] as const,
  active: () => [...scrapingConfigKeys.all, 'active'] as const,
}

/**
 * Fetch all scraping configs from JSON API
 */
async function fetchScrapingConfigs(): Promise<ScrapingConfig[]> {
  const response = await fetch(API_BASE_URL, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/vnd.api+json',
      'Accept': 'application/vnd.api+json',
    },
  })

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`)
  }

  const result = await response.json()

  // Transform JSON:API format to plain objects
  return result.data.map((item: any) => ({
    id: item.id,
    ...item.attributes,
  }))
}

/**
 * Fetch a single scraping config by ID
 */
async function fetchScrapingConfigById(id: string): Promise<ScrapingConfig> {
  const response = await fetch(`${API_BASE_URL}/${id}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/vnd.api+json',
      'Accept': 'application/vnd.api+json',
    },
  })

  if (!response.ok) {
    throw new Error(`HTTP ${response.status}: ${response.statusText}`)
  }

  const result = await response.json()

  return {
    id: result.data.id,
    ...result.data.attributes,
  }
}

/**
 * Query hook for all scraping configs
 */
export function useScrapingConfigsQuery() {
  return createQuery({
    queryKey: scrapingConfigKeys.list(),
    queryFn: fetchScrapingConfigs,
    staleTime: 1000 * 60 * 5, // 5 minutes
  })
}

/**
 * Query hook for a single scraping config
 */
export function useScrapingConfigQuery(id: string) {
  return createQuery({
    queryKey: scrapingConfigKeys.detail(id),
    queryFn: () => fetchScrapingConfigById(id),
    enabled: !!id,
  })
}

/**
 * Create scraping config input type
 */
export interface CreateScrapingConfigInput {
  name: string
  description?: string | null
  is_active?: boolean
  hse_base_url?: string
  hse_database?: 'convictions' | 'enforcement' | 'notices'
  requests_per_minute?: number
  network_timeout_ms?: number
  pause_between_pages_ms?: number
  consecutive_existing_threshold?: number
  max_pages_per_session?: number
  max_consecutive_errors?: number
  batch_size?: number
  scheduled_scraping_enabled?: boolean
  manual_scraping_enabled?: boolean
  real_time_progress_enabled?: boolean
  admin_notifications_enabled?: boolean
  daily_scrape_cron?: string | null
  weekly_scrape_cron?: string | null
}

/**
 * Update scraping config input type
 */
export interface UpdateScrapingConfigInput {
  id: string
  description?: string | null
  is_active?: boolean
  hse_base_url?: string
  hse_database?: 'convictions' | 'enforcement' | 'notices'
  requests_per_minute?: number
  network_timeout_ms?: number
  pause_between_pages_ms?: number
  consecutive_existing_threshold?: number
  max_pages_per_session?: number
  max_consecutive_errors?: number
  batch_size?: number
  scheduled_scraping_enabled?: boolean
  manual_scraping_enabled?: boolean
  real_time_progress_enabled?: boolean
  admin_notifications_enabled?: boolean
  daily_scrape_cron?: string | null
  weekly_scrape_cron?: string | null
}

/**
 * Create scraping config mutation
 */
async function createScrapingConfigMutation(input: CreateScrapingConfigInput): Promise<ScrapingConfig> {
  const response = await fetch(API_BASE_URL, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/vnd.api+json',
      'Accept': 'application/vnd.api+json',
    },
    body: JSON.stringify({
      data: {
        type: 'scraping_config',
        attributes: input,
      },
    }),
  })

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}))
    throw new Error(errorData.errors?.[0]?.detail || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result = await response.json()

  return {
    id: result.data.id,
    ...result.data.attributes,
  }
}

/**
 * Update scraping config mutation
 */
async function updateScrapingConfigMutation(input: UpdateScrapingConfigInput): Promise<ScrapingConfig> {
  const { id, ...attributes } = input

  const response = await fetch(`${API_BASE_URL}/${id}`, {
    method: 'PATCH',
    headers: {
      'Content-Type': 'application/vnd.api+json',
      'Accept': 'application/vnd.api+json',
    },
    body: JSON.stringify({
      data: {
        type: 'scraping_config',
        id,
        attributes,
      },
    }),
  })

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}))
    throw new Error(errorData.errors?.[0]?.detail || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result = await response.json()

  return {
    id: result.data.id,
    ...result.data.attributes,
  }
}

/**
 * Delete scraping config mutation
 */
async function deleteScrapingConfigMutation(id: string): Promise<void> {
  const response = await fetch(`${API_BASE_URL}/${id}`, {
    method: 'DELETE',
    headers: {
      'Content-Type': 'application/vnd.api+json',
      'Accept': 'application/vnd.api+json',
    },
  })

  if (!response.ok) {
    const errorData = await response.json().catch(() => ({}))
    throw new Error(errorData.errors?.[0]?.detail || `HTTP ${response.status}: ${response.statusText}`)
  }
}

/**
 * Hook for creating scraping configs
 */
export function useCreateScrapingConfigMutation() {
  return createMutation({
    mutationFn: createScrapingConfigMutation,
    onSuccess: () => {
      queryClient?.invalidateQueries({ queryKey: scrapingConfigKeys.all })
    },
  })
}

/**
 * Hook for updating scraping configs
 */
export function useUpdateScrapingConfigMutation() {
  return createMutation({
    mutationFn: updateScrapingConfigMutation,
    onSuccess: () => {
      queryClient?.invalidateQueries({ queryKey: scrapingConfigKeys.all })
    },
  })
}

/**
 * Hook for deleting scraping configs
 */
export function useDeleteScrapingConfigMutation() {
  return createMutation({
    mutationFn: deleteScrapingConfigMutation,
    onSuccess: () => {
      queryClient?.invalidateQueries({ queryKey: scrapingConfigKeys.all })
    },
  })
}
