<script lang="ts">
	import { onMount } from 'svelte'
	import * as echarts from 'echarts/core'
	import { BarChart as EBarChart } from 'echarts/charts'
	import {
		TitleComponent,
		TooltipComponent,
		GridComponent,
		LegendComponent
	} from 'echarts/components'
	import { CanvasRenderer } from 'echarts/renderers'
	import type { EChartsOption } from 'echarts'

	echarts.use([
		EBarChart,
		TitleComponent,
		TooltipComponent,
		GridComponent,
		LegendComponent,
		CanvasRenderer
	])

	interface Props {
		title: string
		data: { name: string; value: number }[]
		height?: string
		horizontal?: boolean
		onChartClick?: (params: any) => void
		seriesName?: string
	}

	let {
		title,
		data,
		height = '400px',
		horizontal = false,
		onChartClick,
		seriesName = 'Value'
	}: Props = $props()

	let chartContainer: HTMLDivElement
	let chart: echarts.ECharts | null = $state(null)

	onMount(() => {
		chart = echarts.init(chartContainer)

		const handleResize = () => chart?.resize()
		window.addEventListener('resize', handleResize)

		return () => {
			window.removeEventListener('resize', handleResize)
			chart?.dispose()
		}
	})

	$effect(() => {
		if (!chart || !data) return

		const option: EChartsOption = horizontal
			? {
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
							type: 'shadow'
						}
					},
					grid: {
						left: '20%',
						right: '4%',
						bottom: '3%',
						top: '60px',
						containLabel: true
					},
					xAxis: {
						type: 'value',
						axisLabel: {
							fontSize: 12
						}
					},
					yAxis: {
						type: 'category',
						data: data.map((d) => d.name),
						axisLabel: {
							fontSize: 12
						}
					},
					series: [
						{
							name: seriesName,
							type: 'bar',
							data: data.map((d) => d.value),
							itemStyle: {
								borderRadius: [0, 4, 4, 0]
							}
						}
					]
				}
			: {
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
							type: 'shadow'
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
						data: data.map((d) => d.name),
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
							type: 'bar',
							data: data.map((d) => d.value),
							itemStyle: {
								borderRadius: [4, 4, 0, 0]
							}
						}
					]
				}

		chart.setOption(option)

		if (onChartClick) {
			chart.on('click', onChartClick)
		}
	})
</script>

<div bind:this={chartContainer} style="height: {height}; width: 100%;"></div>
