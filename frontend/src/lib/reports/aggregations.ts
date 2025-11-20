/**
 * Report Aggregation Utilities
 *
 * Client-side data aggregation functions for reports.
 * These work on data from TanStack DB / ElectricSQL sync.
 */

import type { Case } from '$lib/electric/schema'

/**
 * Time period types for grouping
 */
export type TimePeriod = 'day' | 'week' | 'month' | 'quarter' | 'year'

/**
 * Format a date according to the specified period
 */
export function formatDateByPeriod(date: Date | string, period: TimePeriod): string {
	const d = typeof date === 'string' ? new Date(date) : date

	if (isNaN(d.getTime())) {
		return 'Invalid Date'
	}

	switch (period) {
		case 'day':
			return d.toISOString().split('T')[0] // YYYY-MM-DD
		case 'week': {
			// Get ISO week number
			const firstDayOfYear = new Date(d.getFullYear(), 0, 1)
			const pastDaysOfYear = (d.getTime() - firstDayOfYear.getTime()) / 86400000
			const weekNum = Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7)
			return `${d.getFullYear()}-W${String(weekNum).padStart(2, '0')}`
		}
		case 'month':
			return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}`
		case 'quarter': {
			const quarter = Math.floor(d.getMonth() / 3) + 1
			return `${d.getFullYear()}-Q${quarter}`
		}
		case 'year':
			return `${d.getFullYear()}`
	}
}

/**
 * Group cases by time period
 */
export function groupCasesByTime(
	cases: Case[],
	dateField: keyof Case,
	period: TimePeriod = 'month'
): { date: string; count: number; totalFines: number; cases: Case[] }[] {
	const grouped = new Map<string, Case[]>()

	for (const c of cases) {
		const dateValue = c[dateField]
		if (!dateValue) continue

		const key = formatDateByPeriod(dateValue as string, period)
		if (!grouped.has(key)) {
			grouped.set(key, [])
		}
		grouped.get(key)!.push(c)
	}

	// Convert to array and sort by date
	return Array.from(grouped.entries())
		.map(([date, cases]) => ({
			date,
			count: cases.length,
			totalFines: cases.reduce((sum, c) => sum + (c.offence_fine || 0), 0),
			cases
		}))
		.sort((a, b) => a.date.localeCompare(b.date))
}

/**
 * Get top N items by a numeric field
 */
export function topN<T>(
	items: T[],
	field: keyof T,
	n: number = 10,
	descending: boolean = true
): T[] {
	const sorted = [...items].sort((a, b) => {
		const aVal = (a[field] as number) || 0
		const bVal = (b[field] as number) || 0
		return descending ? bVal - aVal : aVal - bVal
	})
	return sorted.slice(0, n)
}

/**
 * Group by a field and sum another field
 */
export function groupByAndSum<T>(
	items: T[],
	groupField: keyof T,
	sumField: keyof T
): { name: string; value: number; items: T[] }[] {
	const grouped = new Map<string, T[]>()

	for (const item of items) {
		const key = String(item[groupField] || 'Unknown')
		if (!grouped.has(key)) {
			grouped.set(key, [])
		}
		grouped.get(key)!.push(item)
	}

	return Array.from(grouped.entries()).map(([name, items]) => ({
		name,
		value: items.reduce((sum, item) => sum + ((item[sumField] as number) || 0), 0),
		items
	}))
}

/**
 * Group by a field and count
 */
export function groupByAndCount<T>(
	items: T[],
	groupField: keyof T
): { name: string; value: number; items: T[] }[] {
	const grouped = new Map<string, T[]>()

	for (const item of items) {
		const key = String(item[groupField] || 'Unknown')
		if (!grouped.has(key)) {
			grouped.set(key, [])
		}
		grouped.get(key)!.push(item)
	}

	return Array.from(grouped.entries()).map(([name, items]) => ({
		name,
		value: items.length,
		items
	}))
}

/**
 * Create histogram buckets
 */
export function bucketByRange<T>(
	items: T[],
	field: keyof T,
	buckets: { min: number; max: number; label: string }[]
): { label: string; count: number; items: T[] }[] {
	const result = buckets.map((bucket) => ({
		label: bucket.label,
		count: 0,
		items: [] as T[]
	}))

	for (const item of items) {
		const value = (item[field] as number) || 0
		const bucketIndex = buckets.findIndex(
			(b) => value >= b.min && (b.max === Infinity || value < b.max)
		)
		if (bucketIndex >= 0) {
			result[bucketIndex].count++
			result[bucketIndex].items.push(item)
		}
	}

	return result
}

/**
 * Calculate summary statistics
 */
export function calculateStats<T>(items: T[], field: keyof T) {
	const values = items.map((item) => (item[field] as number) || 0).filter((v) => v > 0)

	if (values.length === 0) {
		return {
			count: 0,
			sum: 0,
			mean: 0,
			median: 0,
			min: 0,
			max: 0
		}
	}

	const sorted = [...values].sort((a, b) => a - b)
	const sum = values.reduce((acc, v) => acc + v, 0)
	const mean = sum / values.length
	const median =
		values.length % 2 === 0
			? (sorted[values.length / 2 - 1] + sorted[values.length / 2]) / 2
			: sorted[Math.floor(values.length / 2)]

	return {
		count: values.length,
		sum,
		mean,
		median,
		min: sorted[0],
		max: sorted[sorted.length - 1]
	}
}

/**
 * Format currency (GBP)
 */
export function formatCurrency(amount: number): string {
	return new Intl.NumberFormat('en-GB', {
		style: 'currency',
		currency: 'GBP',
		minimumFractionDigits: 0,
		maximumFractionDigits: 0
	}).format(amount)
}

/**
 * Format large numbers with abbreviations
 */
export function formatNumber(num: number): string {
	if (num >= 1000000) {
		return (num / 1000000).toFixed(1) + 'M'
	}
	if (num >= 1000) {
		return (num / 1000).toFixed(1) + 'K'
	}
	return num.toString()
}
