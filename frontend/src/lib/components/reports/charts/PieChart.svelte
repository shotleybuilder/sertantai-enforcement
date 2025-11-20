<script lang="ts">
	import { onMount } from 'svelte'
	import * as echarts from 'echarts/core'
	import { PieChart as EPieChart } from 'echarts/charts'
	import {
		TitleComponent,
		TooltipComponent,
		LegendComponent
	} from 'echarts/components'
	import { CanvasRenderer } from 'echarts/renderers'
	import type { EChartsOption } from 'echarts'

	echarts.use([EPieChart, TitleComponent, TooltipComponent, LegendComponent, CanvasRenderer])

	interface Props {
		title: string
		data: { name: string; value: number }[]
		height?: string
		onChartClick?: (params: any) => void
	}

	let { title, data, height = '400px', onChartClick }: Props = $props()

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
				trigger: 'item',
				formatter: '{a} <br/>{b}: {c} ({d}%)'
			},
			legend: {
				orient: 'horizontal',
				bottom: '10px',
				left: 'center'
			},
			series: [
				{
					name: title,
					type: 'pie',
					radius: ['40%', '70%'],
					avoidLabelOverlap: false,
					itemStyle: {
						borderRadius: 10,
						borderColor: '#fff',
						borderWidth: 2
					},
					label: {
						show: false,
						position: 'center'
					},
					emphasis: {
						label: {
							show: true,
							fontSize: 20,
							fontWeight: 'bold'
						}
					},
					labelLine: {
						show: false
					},
					data
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
