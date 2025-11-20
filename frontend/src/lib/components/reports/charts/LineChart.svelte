<script lang="ts">
	import { onMount } from 'svelte'
	import * as echarts from 'echarts/core'
	import { LineChart as ELineChart } from 'echarts/charts'
	import {
		TitleComponent,
		TooltipComponent,
		GridComponent,
		LegendComponent,
		DataZoomComponent
	} from 'echarts/components'
	import { CanvasRenderer } from 'echarts/renderers'
	import type { EChartsOption } from 'echarts'

	// Register only what we need (tree-shaking)
	echarts.use([
		ELineChart,
		TitleComponent,
		TooltipComponent,
		GridComponent,
		LegendComponent,
		DataZoomComponent,
		CanvasRenderer
	])

	interface Props {
		title: string
		data: { date: string; value: number; series?: string }[]
		height?: string
		onChartClick?: (params: any) => void
		seriesName?: string
	}

	let { title, data, height = '400px', onChartClick, seriesName = 'Count' }: Props = $props()

	let chartContainer: HTMLDivElement
	let chart: echarts.ECharts | null = $state(null)

	onMount(() => {
		chart = echarts.init(chartContainer)

		// Handle window resize
		const handleResize = () => chart?.resize()
		window.addEventListener('resize', handleResize)

		// Cleanup
		return () => {
			window.removeEventListener('resize', handleResize)
			chart?.dispose()
		}
	})

	$effect(() => {
		if (!chart || !data) return

		const option: EChartsOption = {
			title: {
				text: title,
				left: 'center',
				textStyle: {
					fontSize: 18,
					fontWeight: 'bold'
				}
			},
			tooltip: {
				trigger: 'axis',
				axisPointer: {
					type: 'cross'
				}
			},
			grid: {
				left: '3%',
				right: '4%',
				bottom: '80px',
				top: '60px',
				containLabel: true
			},
			xAxis: {
				type: 'category',
				data: data.map((d) => d.date),
				axisLabel: {
					rotate: 45,
					fontSize: 12
				}
			},
			yAxis: {
				type: 'value',
				axisLabel: {
					fontSize: 12
				}
			},
			series: [
				{
					name: seriesName,
					type: 'line',
					data: data.map((d) => d.value),
					smooth: true,
					areaStyle: {
						opacity: 0.2
					},
					lineStyle: {
						width: 2
					},
					itemStyle: {
						borderWidth: 2
					}
				}
			],
			dataZoom: [
				{
					type: 'inside',
					start: 0,
					end: 100
				},
				{
					start: 0,
					end: 100
				}
			]
		}

		chart.setOption(option)

		// Handle click events
		if (onChartClick) {
			chart.on('click', onChartClick)
		}
	})
</script>

<div bind:this={chartContainer} style="height: {height}; width: 100%;"></div>
