/**
 * TanStack Query functions for Offender Match Reviews
 *
 * Queries and mutations for reviewing offender-to-company matches from Companies House
 */

import { createQuery, createMutation } from '@tanstack/svelte-query'
import { queryClient } from '$lib/query/client'

const API_BASE_URL = 'http://localhost:4002/api/match-reviews'

/**
 * Review status types
 */
export type ReviewStatus = 'pending' | 'approved' | 'skipped' | 'needs_review'

/**
 * Candidate company from Companies House search
 */
export interface CandidateCompany {
  company_number: string
  company_name: string
  company_status: string
  company_type: string
  address: string
  similarity_score: number
}

/**
 * Offender summary in review
 */
export interface ReviewOffender {
  id: string
  name: string
  company_registration_number: string | null
  town: string | null
  county: string | null
  postcode: string | null
}

/**
 * Reviewer user info
 */
export interface Reviewer {
  id: string
  email: string
}

/**
 * Match review summary (for list view)
 */
export interface MatchReviewSummary {
  id: string
  offender_id: string
  offender_name: string | null
  status: ReviewStatus
  confidence_score: number
  candidate_count: number
  searched_at: string
  reviewed_at: string | null
  reviewed_by_id: string | null
}

/**
 * Match review detail (for single review view)
 */
export interface MatchReviewDetail {
  id: string
  offender_id: string
  offender: ReviewOffender | null
  status: ReviewStatus
  confidence_score: number
  candidate_companies: CandidateCompany[]
  selected_company_number: string | null
  review_notes: string | null
  searched_at: string
  reviewed_at: string | null
  reviewed_by_id: string | null
  reviewed_by: Reviewer | null
  inserted_at: string
  updated_at: string
}

/**
 * Query key factory
 */
export const matchReviewsKeys = {
  all: ['match-reviews'] as const,
  lists: () => [...matchReviewsKeys.all, 'list'] as const,
  list: (status?: ReviewStatus) => [...matchReviewsKeys.lists(), { status }] as const,
  details: () => [...matchReviewsKeys.all, 'detail'] as const,
  detail: (id: string) => [...matchReviewsKeys.details(), id] as const,
}

/**
 * Fetch match reviews with optional status filter
 */
async function fetchMatchReviews(status?: ReviewStatus): Promise<MatchReviewSummary[]> {
  const url = status ? `${API_BASE_URL}?status=${status}` : API_BASE_URL

  const response = await fetch(url, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || data.details || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result = await response.json()
  return result.data
}

/**
 * Query hook for fetching match reviews
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useMatchReviewsQuery } from '$lib/query/match-reviews'
 *   const reviewsQuery = useMatchReviewsQuery('pending')
 * </script>
 *
 * {#if $reviewsQuery.isLoading}
 *   Loading...
 * {:else if $reviewsQuery.data}
 *   {$reviewsQuery.data.length} pending reviews
 * {/if}
 * ```
 */
export function useMatchReviewsQuery(status?: ReviewStatus) {
  return createQuery({
    queryKey: matchReviewsKeys.list(status),
    queryFn: () => fetchMatchReviews(status),
    staleTime: 1000 * 60 * 5, // 5 minutes
  })
}

/**
 * Fetch single match review by ID
 */
async function fetchMatchReview(id: string): Promise<MatchReviewDetail> {
  const response = await fetch(`${API_BASE_URL}/${id}`, {
    method: 'GET',
    headers: {
      'Content-Type': 'application/json',
    },
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || data.details || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result = await response.json()
  return result.data
}

/**
 * Query hook for fetching single match review
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useMatchReviewQuery } from '$lib/query/match-reviews'
 *   const reviewQuery = useMatchReviewQuery(reviewId)
 * </script>
 *
 * {#if $reviewQuery.data}
 *   <h2>{$reviewQuery.data.offender.name}</h2>
 *   <p>Confidence: {$reviewQuery.data.confidence_score}</p>
 * {/if}
 * ```
 */
export function useMatchReviewQuery(id: string) {
  return createQuery({
    queryKey: matchReviewsKeys.detail(id),
    queryFn: () => fetchMatchReview(id),
    staleTime: 1000 * 60 * 2, // 2 minutes
  })
}

/**
 * Approve match review input
 */
export interface ApproveMatchInput {
  id: string
  company_number: string
}

/**
 * Approve a match review
 */
async function approveMatch(input: ApproveMatchInput): Promise<MatchReviewDetail> {
  const response = await fetch(`${API_BASE_URL}/${input.id}/approve`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      company_number: input.company_number,
    }),
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || data.details || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result = await response.json()
  return result.data
}

/**
 * Hook for approving a match
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useApproveMatchMutation } from '$lib/query/match-reviews'
 *   const approveMutation = useApproveMatchMutation()
 *
 *   function handleApprove(companyNumber: string) {
 *     $approveMutation.mutate({ id: reviewId, company_number: companyNumber })
 *   }
 * </script>
 * ```
 */
export function useApproveMatchMutation() {
  return createMutation({
    mutationFn: approveMatch,
    onSuccess: (data) => {
      // Invalidate all reviews lists
      queryClient?.invalidateQueries({ queryKey: matchReviewsKeys.lists() })
      // Update the detail query
      queryClient?.setQueryData(matchReviewsKeys.detail(data.id), data)
    },
  })
}

/**
 * Skip a match review
 */
async function skipMatch(id: string): Promise<MatchReviewDetail> {
  const response = await fetch(`${API_BASE_URL}/${id}/skip`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || data.details || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result = await response.json()
  return result.data
}

/**
 * Hook for skipping a match
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useSkipMatchMutation } from '$lib/query/match-reviews'
 *   const skipMutation = useSkipMatchMutation()
 *
 *   function handleSkip() {
 *     $skipMutation.mutate(reviewId)
 *   }
 * </script>
 * ```
 */
export function useSkipMatchMutation() {
  return createMutation({
    mutationFn: skipMatch,
    onSuccess: (data) => {
      // Invalidate all reviews lists
      queryClient?.invalidateQueries({ queryKey: matchReviewsKeys.lists() })
      // Update the detail query
      queryClient?.setQueryData(matchReviewsKeys.detail(data.id), data)
    },
  })
}

/**
 * Flag for later input
 */
export interface FlagForLaterInput {
  id: string
  notes?: string
}

/**
 * Flag a match review for later
 */
async function flagForLater(input: FlagForLaterInput): Promise<MatchReviewDetail> {
  const response = await fetch(`${API_BASE_URL}/${input.id}/flag`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      notes: input.notes,
    }),
  })

  if (!response.ok) {
    const data = await response.json().catch(() => ({}))
    throw new Error(data.error || data.details || `HTTP ${response.status}: ${response.statusText}`)
  }

  const result = await response.json()
  return result.data
}

/**
 * Hook for flagging a review for later
 *
 * Usage:
 * ```svelte
 * <script>
 *   import { useFlagForLaterMutation } from '$lib/query/match-reviews'
 *   const flagMutation = useFlagForLaterMutation()
 *
 *   function handleFlag() {
 *     $flagMutation.mutate({ id: reviewId, notes: 'Need more info' })
 *   }
 * </script>
 * ```
 */
export function useFlagForLaterMutation() {
  return createMutation({
    mutationFn: flagForLater,
    onSuccess: (data) => {
      // Invalidate all reviews lists
      queryClient?.invalidateQueries({ queryKey: matchReviewsKeys.lists() })
      // Update the detail query
      queryClient?.setQueryData(matchReviewsKeys.detail(data.id), data)
    },
  })
}
