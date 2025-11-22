# Sprint: AI-Powered Predictive Risk Intelligence

**Sprint Duration**: 3 weeks
**Team Size**: 3-4 developers (1 backend, 1 data engineer, 1 frontend, 1 AI/ML)
**Prerequisites**: Case enrichment system operational, sufficient historical data (1000+ cases)

---

## 🎯 Sprint Goal

Build an AI-powered analytics system that identifies emerging enforcement trends, predicts regulatory risks, and provides actionable intelligence to help compliance professionals proactively manage risk.

---

## 📋 User Stories

### Story 1: Trend Detection Engine
**As a** compliance officer
**I want** to see emerging enforcement trends in my sector
**So that** I can proactively address risks before they become issues

**Acceptance Criteria**:
- [ ] System analyzes cases from last 12 months
- [ ] Identifies trends rising >20% quarter-over-quarter
- [ ] Categorizes by breach type, sector, geography, regulator
- [ ] AI generates natural language explanations for each trend
- [ ] Confidence scores provided for all predictions
- [ ] Updates daily with new case data
- [ ] Exports available as PDF reports

**Story Points**: 13

---

### Story 2: Regulator Focus Analysis
**As a** legal professional
**I want** to understand each regulator's current enforcement priorities
**So that** I can advise clients on likely areas of scrutiny

**Acceptance Criteria**:
- [ ] Pattern analysis identifies regulator priorities from recent cases
- [ ] Shows typical penalties (median, range) by breach type
- [ ] Calculates settlement likelihood percentage
- [ ] Displays average resolution time
- [ ] Compares enforcement intensity across regulators
- [ ] Historical comparison (current vs 6 months ago)
- [ ] Exportable regulator profiles

**Story Points**: 8

---

### Story 3: Sector-Specific Benchmarks
**As an** SME owner
**I want** to see how enforcement affects my specific sector
**So that** I can understand my risk profile

**Acceptance Criteria**:
- [ ] Risk scores calculated per sector (0-100 scale)
- [ ] Common breaches listed for each sector
- [ ] Average fines and costs displayed
- [ ] Trend over time (improving/worsening)
- [ ] Prevention resources linked (guidance, consultants)
- [ ] Comparison with national average
- [ ] Industry-specific insights

**Story Points**: 8

---

### Story 4: Predictive Forecasting
**As a** consultant
**I want** to forecast enforcement activity for the next 6 months
**So that** I can target my business development efforts

**Acceptance Criteria**:
- [ ] Time series forecasting using historical data
- [ ] Predictions at sector, geography, breach type levels
- [ ] Confidence intervals provided (95% CI)
- [ ] Scenario analysis (what-if modeling)
- [ ] Automated alerts when predictions update significantly
- [ ] Export forecast data via API
- [ ] Forecast accuracy tracked and displayed

**Story Points**: 13

---

### Story 5: Real-Time Risk Alerts
**As a** premium subscriber
**I want** real-time alerts when new risk patterns emerge
**So that** I can respond immediately

**Acceptance Criteria**:
- [ ] Email alerts for emerging trends in selected sectors
- [ ] Push notifications for high-priority risks
- [ ] Customizable alert thresholds (e.g., >30% increase)
- [ ] Alert frequency controls (instant/daily/weekly)
- [ ] In-app notification center
- [ ] Alert history and archive
- [ ] Snooze/dismiss functionality

**Story Points**: 8

---

### Story 6: Intelligence Dashboard
**As a** user
**I want** a visual dashboard summarizing all risk intelligence
**So that** I can quickly grasp the current enforcement landscape

**Acceptance Criteria**:
- [ ] Interactive charts (line, bar, heat map)
- [ ] Filterable by date range, sector, geography, regulator
- [ ] Drill-down from summary to detailed cases
- [ ] Exportable charts as PNG/SVG
- [ ] Shareable dashboard URLs
- [ ] Responsive design for mobile
- [ ] Print-friendly layout

**Story Points**: 8

---

## 🏗️ Technical Architecture

### Backend Components

#### 1. Risk Analysis Engine
```elixir
defmodule EhsEnforcement.Analytics.RiskAnalysisEngine do
  @moduledoc """
  Core analytics engine for trend detection and risk forecasting
  """

  alias EhsEnforcement.Analytics.{TrendDetector, ForecastingService, BenchmarkCalculator}

  def generate_risk_intelligence do
    %{
      emerging_risks: detect_emerging_risks(),
      regulator_patterns: analyze_regulator_patterns(),
      sector_benchmarks: calculate_sector_benchmarks(),
      forecasts: generate_forecasts(),
      generated_at: DateTime.utc_now(),
      next_update: next_update_time()
    }
  end

  defp detect_emerging_risks do
    TrendDetector.analyze_trends(%{
      time_period: :last_12_months,
      comparison_period: :previous_12_months,
      threshold: 0.20  # 20% increase
    })
  end

  defp analyze_regulator_patterns do
    EhsEnforcement.Enforcement.Case
    |> group_by_regulator()
    |> calculate_enforcement_metrics()
    |> identify_priorities()
  end

  defp calculate_sector_benchmarks do
    BenchmarkCalculator.calculate_all_sectors()
  end

  defp generate_forecasts do
    ForecastingService.forecast(%{
      horizon: 6,  # months
      confidence_level: 0.95
    })
  end
end
```

#### 2. Trend Detection Service
```elixir
defmodule EhsEnforcement.Analytics.TrendDetector do
  @moduledoc """
  Detects emerging trends in enforcement data using statistical analysis
  """

  def analyze_trends(opts) do
    cases = fetch_cases(opts.time_period)
    baseline = fetch_cases(opts.comparison_period)

    cases
    |> group_by_category()
    |> calculate_change_rates(baseline)
    |> filter_significant_trends(opts.threshold)
    |> enrich_with_ai_insights()
  end

  defp calculate_change_rates(current_data, baseline_data) do
    Enum.map(current_data, fn {category, current_count} ->
      baseline_count = Map.get(baseline_data, category, 0)

      percentage_change = if baseline_count > 0 do
        ((current_count - baseline_count) / baseline_count) * 100
      else
        100.0
      end

      %{
        category: category,
        current_count: current_count,
        baseline_count: baseline_count,
        percentage_change: percentage_change,
        trend: determine_trend(percentage_change)
      }
    end)
  end

  defp determine_trend(change) when change > 20, do: :surging
  defp determine_trend(change) when change > 5, do: :rising
  defp determine_trend(change) when change < -20, do: :declining
  defp determine_trend(change) when change < -5, do: :falling
  defp determine_trend(_), do: :stable

  defp enrich_with_ai_insights(trends) do
    Enum.map(trends, fn trend ->
      ai_analysis = EhsEnforcement.AI.TrendAnalysisService.analyze(trend)
      Map.put(trend, :ai_insights, ai_analysis)
    end)
  end
end
```

#### 3. Forecasting Service
```elixir
defmodule EhsEnforcement.Analytics.ForecastingService do
  @moduledoc """
  Time series forecasting using Prophet or ARIMA models
  """

  def forecast(opts) do
    # Fetch historical data
    historical = fetch_time_series_data()

    # Apply forecasting model (using Python bridge or Nx)
    predictions = apply_prophet_model(historical, opts)

    # Calculate confidence intervals
    with_confidence_intervals(predictions, opts.confidence_level)
  end

  defp apply_prophet_model(data, opts) do
    # Option 1: Use Python via Ports
    # Option 2: Use Nx/Scholar for pure Elixir solution
    # Option 3: Use external forecasting API

    # For now, simple moving average + linear regression
    calculate_moving_average(data)
    |> apply_linear_trend()
    |> project_forward(opts.horizon)
  end

  defp with_confidence_intervals(predictions, confidence_level) do
    # Calculate prediction intervals using standard error
    std_error = calculate_standard_error(predictions)
    z_score = z_score_for_confidence(confidence_level)

    Enum.map(predictions, fn pred ->
      margin = std_error * z_score

      %{
        date: pred.date,
        predicted_value: pred.value,
        lower_bound: pred.value - margin,
        upper_bound: pred.value + margin,
        confidence_level: confidence_level
      }
    end)
  end
end
```

#### 4. Database Schema
```elixir
defmodule EhsEnforcement.Analytics.RiskIntelligence do
  use Ash.Resource,
    domain: EhsEnforcement.Analytics,
    data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # Emerging risks
    attribute :emerging_risks, {:array, :map} do
      description "List of emerging risk trends"
    end

    # Regulator patterns
    attribute :regulator_patterns, {:array, :map} do
      description "Enforcement pattern analysis by regulator"
    end

    # Sector benchmarks
    attribute :sector_benchmarks, {:array, :map} do
      description "Risk benchmarks by industry sector"
    end

    # Forecasts
    attribute :forecasts, :map do
      description "6-month forecasts with confidence intervals"
    end

    # Metadata
    attribute :analysis_period_start, :date
    attribute :analysis_period_end, :date
    attribute :model_version, :string
    attribute :generated_at, :utc_datetime_usec
    attribute :next_update, :utc_datetime_usec

    timestamps()
  end

  actions do
    defaults [:read]

    create :generate do
      accept []

      change fn changeset, _context ->
        intelligence = EhsEnforcement.Analytics.RiskAnalysisEngine.generate_risk_intelligence()

        changeset
        |> Ash.Changeset.change_attribute(:emerging_risks, intelligence.emerging_risks)
        |> Ash.Changeset.change_attribute(:regulator_patterns, intelligence.regulator_patterns)
        |> Ash.Changeset.change_attribute(:sector_benchmarks, intelligence.sector_benchmarks)
        |> Ash.Changeset.change_attribute(:forecasts, intelligence.forecasts)
        |> Ash.Changeset.change_attribute(:generated_at, intelligence.generated_at)
      end
    end
  end
end
```

#### 5. Alert System
```elixir
defmodule EhsEnforcement.Analytics.AlertSystem do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  def init(state) do
    # Schedule daily analysis
    schedule_analysis()
    {:ok, state}
  end

  def handle_info(:run_analysis, state) do
    check_for_new_risks()
    schedule_analysis()
    {:noreply, state}
  end

  defp check_for_new_risks do
    # Get latest intelligence
    current = EhsEnforcement.Analytics.get_latest_intelligence()
    previous = EhsEnforcement.Analytics.get_previous_intelligence()

    # Compare and identify new risks
    new_risks = identify_new_risks(current, previous)

    # Send alerts to subscribed users
    Enum.each(new_risks, fn risk ->
      notify_subscribers(risk)
    end)
  end

  defp notify_subscribers(risk) do
    # Get users subscribed to this risk category
    subscribers = EhsEnforcement.Accounts.get_risk_alert_subscribers(
      sector: risk.sector,
      alert_threshold: risk.severity
    )

    # Send email/push notifications
    Enum.each(subscribers, fn user ->
      EhsEnforcement.Mailer.send_risk_alert(user, risk)
      EhsEnforcement.PubSub.publish_notification(user.id, risk)
    end)
  end

  defp schedule_analysis do
    # Run daily at 2 AM UTC
    Process.send_after(self(), :run_analysis, calculate_next_run())
  end
end
```

### Frontend Components

#### 1. Risk Intelligence Dashboard
```svelte
<!-- frontend/src/routes/intelligence/+page.svelte -->
<script lang="ts">
  import { db } from '$lib/db'
  import { Chart } from '$lib/components/charts'
  import EmergingRiskCard from '$lib/components/EmergingRiskCard.svelte'
  import RegulatorPatternChart from '$lib/components/RegulatorPatternChart.svelte'
  import ForecastChart from '$lib/components/ForecastChart.svelte'

  // Query latest intelligence
  $: intelligence = db.query((q) =>
    q.risk_intelligence
      .orderBy('generated_at', 'desc')
      .first()
  )

  let selectedSector = 'all'
  let dateRange = 'last_12_months'

  $: filteredRisks = $intelligence?.emerging_risks.filter(
    risk => selectedSector === 'all' || risk.sector === selectedSector
  )
</script>

<div class="intelligence-dashboard">
  <header>
    <h1>Risk Intelligence Dashboard</h1>
    <p class="text-gray-600">
      Last updated: {new Date($intelligence?.generated_at).toLocaleString()}
    </p>
    <p class="text-sm text-gray-500">
      Next update: {new Date($intelligence?.next_update).toLocaleString()}
    </p>
  </header>

  <!-- Filters -->
  <div class="filters">
    <select bind:value={selectedSector}>
      <option value="all">All Sectors</option>
      <option value="construction">Construction</option>
      <option value="manufacturing">Manufacturing</option>
      <option value="healthcare">Healthcare</option>
      <!-- ... more sectors -->
    </select>

    <select bind:value={dateRange}>
      <option value="last_3_months">Last 3 Months</option>
      <option value="last_6_months">Last 6 Months</option>
      <option value="last_12_months">Last 12 Months</option>
    </select>
  </div>

  <!-- Emerging Risks Section -->
  <section class="emerging-risks">
    <h2>Emerging Risks</h2>
    <div class="risk-grid">
      {#each filteredRisks as risk}
        <EmergingRiskCard {risk} />
      {/each}
    </div>
  </section>

  <!-- Regulator Patterns Section -->
  <section class="regulator-patterns">
    <h2>Regulator Enforcement Patterns</h2>
    <RegulatorPatternChart patterns={$intelligence?.regulator_patterns} />
  </section>

  <!-- Sector Benchmarks Section -->
  <section class="sector-benchmarks">
    <h2>Sector Risk Benchmarks</h2>
    <div class="benchmark-table">
      <table>
        <thead>
          <tr>
            <th>Sector</th>
            <th>Risk Score</th>
            <th>Common Breaches</th>
            <th>Avg Fine</th>
            <th>Trend</th>
          </tr>
        </thead>
        <tbody>
          {#each $intelligence?.sector_benchmarks as benchmark}
            <tr>
              <td>{benchmark.sector}</td>
              <td>
                <RiskScoreBadge score={benchmark.risk_score} />
              </td>
              <td>
                {benchmark.common_breaches.slice(0, 3).join(', ')}
              </td>
              <td>£{benchmark.median_fine.toLocaleString()}</td>
              <td>
                <TrendIndicator trend={benchmark.trend} />
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
    </div>
  </section>

  <!-- Forecasts Section -->
  <section class="forecasts">
    <h2>6-Month Forecast</h2>
    <p class="text-sm text-gray-600">
      Predicted enforcement activity based on historical patterns
    </p>
    <ForecastChart forecast={$intelligence?.forecasts} />
  </section>

  <!-- Export Options -->
  <div class="export-actions">
    <button on:click={exportPDF} class="btn-secondary">
      📄 Export Report (PDF)
    </button>
    <button on:click={exportExcel} class="btn-secondary">
      📊 Export Data (Excel)
    </button>
    <button on:click={shareLink} class="btn-secondary">
      🔗 Share Dashboard
    </button>
  </div>
</div>
```

#### 2. Emerging Risk Card Component
```svelte
<!-- frontend/src/lib/components/EmergingRiskCard.svelte -->
<script lang="ts">
  import type { EmergingRisk } from '$lib/types/intelligence'

  export let risk: EmergingRisk

  function getTrendColor(trend: string) {
    switch(trend) {
      case 'surging': return 'text-red-600'
      case 'rising': return 'text-orange-500'
      case 'stable': return 'text-gray-500'
      case 'declining': return 'text-green-600'
      default: return 'text-gray-500'
    }
  }

  function getTrendIcon(trend: string) {
    switch(trend) {
      case 'surging': return '📈'
      case 'rising': return '↗️'
      case 'stable': return '➡️'
      case 'declining': return '↘️'
      default: return '➡️'
    }
  }
</script>

<div class="risk-card border rounded-lg p-6 shadow-sm hover:shadow-md transition">
  <div class="flex justify-between items-start">
    <div>
      <h3 class="text-lg font-semibold">{risk.category}</h3>
      <p class="text-sm text-gray-600">{risk.sector}</p>
    </div>
    <span class="trend-badge {getTrendColor(risk.trend)}">
      {getTrendIcon(risk.trend)} {risk.trend}
    </span>
  </div>

  <div class="metrics mt-4 grid grid-cols-2 gap-4">
    <div>
      <p class="text-sm text-gray-500">Change (3M)</p>
      <p class="text-2xl font-bold {risk.percentage_change_3m > 0 ? 'text-red-600' : 'text-green-600'}">
        {risk.percentage_change_3m > 0 ? '+' : ''}{risk.percentage_change_3m.toFixed(1)}%
      </p>
    </div>
    <div>
      <p class="text-sm text-gray-500">Change (12M)</p>
      <p class="text-2xl font-bold {risk.percentage_change_12m > 0 ? 'text-red-600' : 'text-green-600'}">
        {risk.percentage_change_12m > 0 ? '+' : ''}{risk.percentage_change_12m.toFixed(1)}%
      </p>
    </div>
  </div>

  <div class="ai-insights mt-4">
    <h4 class="text-sm font-semibold mb-2">AI Analysis</h4>
    <p class="text-sm text-gray-700">{risk.analysis}</p>

    {#if risk.likely_drivers.length > 0}
      <div class="mt-2">
        <p class="text-xs font-semibold text-gray-600">Likely Drivers:</p>
        <ul class="text-sm list-disc list-inside">
          {#each risk.likely_drivers as driver}
            <li>{driver}</li>
          {/each}
        </ul>
      </div>
    {/if}

    {#if risk.geographic_hotspots.length > 0}
      <div class="mt-2">
        <p class="text-xs font-semibold text-gray-600">Geographic Hotspots:</p>
        <div class="flex flex-wrap gap-1 mt-1">
          {#each risk.geographic_hotspots as location}
            <span class="badge badge-sm">{location}</span>
          {/each}
        </div>
      </div>
    {/if}
  </div>

  {#if risk.forecast_6m}
    <div class="forecast mt-4 p-3 bg-gray-50 rounded">
      <p class="text-xs font-semibold text-gray-600 mb-1">6-Month Forecast</p>
      <p class="text-sm">
        Expected cases: <strong>{risk.forecast_6m.expected_cases}</strong>
        <span class="text-xs text-gray-500">
          (CI: {risk.forecast_6m.confidence_interval[0]}-{risk.forecast_6m.confidence_interval[1]})
        </span>
      </p>
    </div>
  {/if}

  {#if risk.recommended_actions.length > 0}
    <div class="actions mt-4">
      <p class="text-xs font-semibold text-gray-600 mb-1">Recommended Actions:</p>
      <ul class="text-sm list-disc list-inside">
        {#each risk.recommended_actions as action}
          <li>{action}</li>
        {/each}
      </ul>
    </div>
  {/if}

  <div class="mt-4">
    <a href="/intelligence/{risk.id}" class="text-sm text-blue-600 hover:underline">
      View detailed analysis →
    </a>
  </div>
</div>
```

#### 3. Forecast Chart Component
```svelte
<!-- frontend/src/lib/components/ForecastChart.svelte -->
<script lang="ts">
  import { onMount } from 'svelte'
  import * as d3 from 'd3'

  export let forecast: any

  let chartContainer: HTMLDivElement

  onMount(() => {
    if (!forecast) return

    const width = 800
    const height = 400
    const margin = { top: 20, right: 30, bottom: 30, left: 50 }

    // Create SVG
    const svg = d3.select(chartContainer)
      .append('svg')
      .attr('width', width)
      .attr('height', height)

    // Scales
    const x = d3.scaleTime()
      .domain(d3.extent(forecast.predictions, d => new Date(d.date)))
      .range([margin.left, width - margin.right])

    const y = d3.scaleLinear()
      .domain([0, d3.max(forecast.predictions, d => d.upper_bound)])
      .range([height - margin.bottom, margin.top])

    // Axes
    svg.append('g')
      .attr('transform', `translate(0,${height - margin.bottom})`)
      .call(d3.axisBottom(x))

    svg.append('g')
      .attr('transform', `translate(${margin.left},0)`)
      .call(d3.axisLeft(y))

    // Confidence interval area
    const area = d3.area()
      .x(d => x(new Date(d.date)))
      .y0(d => y(d.lower_bound))
      .y1(d => y(d.upper_bound))

    svg.append('path')
      .datum(forecast.predictions)
      .attr('fill', 'rgba(59, 130, 246, 0.2)')
      .attr('d', area)

    // Predicted line
    const line = d3.line()
      .x(d => x(new Date(d.date)))
      .y(d => y(d.predicted_value))

    svg.append('path')
      .datum(forecast.predictions)
      .attr('fill', 'none')
      .attr('stroke', '#3b82f6')
      .attr('stroke-width', 2)
      .attr('d', line)

    // Historical data (if available)
    if (forecast.historical) {
      const historicalLine = d3.line()
        .x(d => x(new Date(d.date)))
        .y(d => y(d.actual_value))

      svg.append('path')
        .datum(forecast.historical)
        .attr('fill', 'none')
        .attr('stroke', '#6b7280')
        .attr('stroke-width', 2)
        .attr('stroke-dasharray', '5,5')
        .attr('d', historicalLine)
    }
  })
</script>

<div bind:this={chartContainer} class="forecast-chart"></div>

<div class="legend mt-4 flex gap-4 text-sm">
  <div class="flex items-center gap-2">
    <div class="w-4 h-0.5 bg-gray-500"></div>
    <span>Historical</span>
  </div>
  <div class="flex items-center gap-2">
    <div class="w-4 h-0.5 bg-blue-500"></div>
    <span>Forecast</span>
  </div>
  <div class="flex items-center gap-2">
    <div class="w-4 h-4 bg-blue-200 rounded"></div>
    <span>95% Confidence Interval</span>
  </div>
</div>
```

---

## 🔧 Implementation Tasks

### Week 1: Data Analysis Engine

**Day 1-2: Database Schema & Analytics Resources**
- [ ] Create `risk_intelligence` table migration
- [ ] Create `risk_alerts` table migration
- [ ] Create `user_alert_subscriptions` table migration
- [ ] Define Ash resources
- [ ] Set up analytics domain
- [ ] Create indexes for performance
- [ ] Write resource tests

**Day 3-4: Trend Detection Engine**
- [ ] Implement `TrendDetector` module
- [ ] Build statistical analysis functions
- [ ] Create category grouping logic
- [ ] Implement change rate calculations
- [ ] Add AI insight generation
- [ ] Test with historical data
- [ ] Optimize query performance

**Day 5: Regulator Pattern Analysis**
- [ ] Implement regulator grouping logic
- [ ] Calculate enforcement metrics per regulator
- [ ] Identify priority areas using ML clustering
- [ ] Generate natural language summaries
- [ ] Test accuracy with known patterns

---

### Week 2: Forecasting & Benchmarks

**Day 6-7: Forecasting Service**
- [ ] Research forecasting libraries (Prophet, Nx)
- [ ] Implement time series data extraction
- [ ] Build forecasting model (moving average + linear regression)
- [ ] Calculate confidence intervals
- [ ] Validate forecast accuracy on historical data
- [ ] Add scenario modeling (what-if analysis)
- [ ] Optimize for performance

**Day 8-9: Sector Benchmarks**
- [ ] Implement `BenchmarkCalculator` module
- [ ] Calculate risk scores per sector
- [ ] Identify common breaches
- [ ] Calculate median fines and costs
- [ ] Generate trend indicators
- [ ] Link prevention resources
- [ ] Test benchmark accuracy

**Day 10: Alert System**
- [ ] Create alert GenServer
- [ ] Implement daily analysis schedule
- [ ] Build new risk detection logic
- [ ] Create email templates for alerts
- [ ] Implement push notifications
- [ ] Add subscription management
- [ ] Test alert delivery

---

### Week 3: Frontend & Integration

**Day 11-13: Intelligence Dashboard**
- [ ] Create dashboard page layout
- [ ] Build emerging risk cards
- [ ] Implement regulator pattern charts (D3.js)
- [ ] Build forecast chart with confidence intervals
- [ ] Create sector benchmark table
- [ ] Add filters (sector, date range)
- [ ] Implement export functionality (PDF, Excel)
- [ ] Style with TailwindCSS
- [ ] Make responsive for mobile

**Day 14-15: Real-time Features**
- [ ] Integrate ElectricSQL sync for intelligence data
- [ ] Add real-time update notifications
- [ ] Build in-app notification center
- [ ] Create alert preferences page
- [ ] Test real-time sync (intelligence updates propagate)
- [ ] Add loading states and skeletons
- [ ] Performance optimization

**Day 16-17: Testing & Polish**
- [ ] Write unit tests for analytics engine
- [ ] Write integration tests for forecasting
- [ ] E2E tests for dashboard
- [ ] Load testing with large datasets
- [ ] Accessibility audit
- [ ] Documentation
- [ ] Sprint demo preparation

---

## 🧪 Testing Strategy

### Unit Tests
```elixir
# test/ehs_enforcement/analytics/trend_detector_test.exs
defmodule EhsEnforcement.Analytics.TrendDetectorTest do
  use EhsEnforcement.DataCase

  alias EhsEnforcement.Analytics.TrendDetector

  describe "analyze_trends/1" do
    setup do
      # Create baseline data (100 asbestos cases in 2023)
      create_cases_fixture(100, breach_type: "asbestos", year: 2023)

      # Create current data (150 asbestos cases in 2024 - 50% increase)
      create_cases_fixture(150, breach_type: "asbestos", year: 2024)

      :ok
    end

    test "detects rising trend when cases increase >20%" do
      trends = TrendDetector.analyze_trends(%{
        time_period: :last_12_months,
        comparison_period: :previous_12_months,
        threshold: 0.20
      })

      asbestos_trend = Enum.find(trends, fn t -> t.category == "asbestos" end)

      assert asbestos_trend != nil
      assert asbestos_trend.trend == :rising
      assert asbestos_trend.percentage_change > 20
      assert asbestos_trend.ai_insights != nil
    end

    test "calculates correct percentage change" do
      trends = TrendDetector.analyze_trends(%{
        time_period: :last_12_months,
        comparison_period: :previous_12_months,
        threshold: 0.20
      })

      asbestos_trend = Enum.find(trends, fn t -> t.category == "asbestos" end)

      # 150 current vs 100 baseline = 50% increase
      assert_in_delta asbestos_trend.percentage_change, 50.0, 1.0
    end
  end
end
```

### Integration Tests
```elixir
# test/ehs_enforcement/analytics/forecasting_service_test.exs
defmodule EhsEnforcement.Analytics.ForecastingServiceTest do
  use EhsEnforcement.DataCase

  alias EhsEnforcement.Analytics.ForecastingService

  describe "forecast/1" do
    setup do
      # Create 24 months of historical data with upward trend
      Enum.each(1..24, fn month ->
        base_count = 100
        trend_count = base_count + (month * 2)  # Linear growth
        create_cases_fixture(trend_count, month: month)
      end)

      :ok
    end

    test "generates 6-month forecast" do
      forecast = ForecastingService.forecast(%{
        horizon: 6,
        confidence_level: 0.95
      })

      assert length(forecast.predictions) == 6
      assert Enum.all?(forecast.predictions, fn p ->
        p.predicted_value > 0 and
        p.lower_bound > 0 and
        p.upper_bound > p.predicted_value
      end)
    end

    test "confidence intervals are reasonable" do
      forecast = ForecastingService.forecast(%{
        horizon: 6,
        confidence_level: 0.95
      })

      first_prediction = List.first(forecast.predictions)

      # CI should be wider than ±5% of predicted value
      margin = first_prediction.upper_bound - first_prediction.predicted_value
      assert margin > first_prediction.predicted_value * 0.05
    end
  end
end
```

### E2E Tests
```typescript
// frontend/tests/e2e/intelligence-dashboard.spec.ts
import { test, expect } from '@playwright/test'

test.describe('Risk Intelligence Dashboard', () => {
  test('displays intelligence dashboard', async ({ page }) => {
    await page.goto('/intelligence')

    // Check emerging risks section
    await expect(page.locator('h2:has-text("Emerging Risks")')).toBeVisible()
    await expect(page.locator('[data-testid="risk-card"]').first()).toBeVisible()

    // Check regulator patterns
    await expect(page.locator('h2:has-text("Regulator Enforcement Patterns")')).toBeVisible()

    // Check forecasts
    await expect(page.locator('h2:has-text("6-Month Forecast")')).toBeVisible()
    await expect(page.locator('.forecast-chart')).toBeVisible()
  })

  test('filters work correctly', async ({ page }) => {
    await page.goto('/intelligence')

    // Select construction sector
    await page.selectOption('select[data-testid="sector-filter"]', 'construction')

    // Check that only construction risks are shown
    const riskCards = page.locator('[data-testid="risk-card"]')
    await expect(riskCards).toHaveCount(await riskCards.count())

    for (let i = 0; i < await riskCards.count(); i++) {
      const sector = await riskCards.nth(i).locator('.sector').textContent()
      expect(sector).toContain('construction')
    }
  })

  test('exports PDF report', async ({ page }) => {
    await page.goto('/intelligence')

    // Click export PDF button
    const downloadPromise = page.waitForEvent('download')
    await page.click('button:has-text("Export Report (PDF)")')

    const download = await downloadPromise
    expect(download.suggestedFilename()).toMatch(/risk-intelligence-.*\.pdf/)
  })
})
```

---

## 📊 Success Metrics

### Accuracy Metrics
- [ ] Trend detection accuracy >85% (validated by professionals)
- [ ] Forecast accuracy within 15% of actual values
- [ ] Regulator pattern identification >90% precision
- [ ] Benchmark calculations within 5% of actual averages

### Engagement Metrics
- [ ] 40%+ of premium users view intelligence dashboard weekly
- [ ] 20%+ of users export intelligence reports monthly
- [ ] 15%+ of users subscribe to risk alerts
- [ ] Average session time on dashboard >5 minutes

### Business Metrics
- [ ] Premium tier conversions increase 25% (intelligence as key feature)
- [ ] Feature referenced in 60%+ user feedback as "highly valuable"
- [ ] API usage for intelligence data grows 30% month-over-month
- [ ] Consultants use forecasts in 50%+ client proposals

---

## 🚧 Risks & Mitigations

### Risk 1: Inaccurate Forecasts
**Impact**: High - Damages credibility
**Probability**: Medium
**Mitigation**:
- Clearly display confidence intervals
- Track and publish forecast accuracy
- Conservative predictions (under-promise, over-deliver)
- Professional disclaimer ("for informational purposes only")
- Continuous model improvement based on validation

### Risk 2: Insufficient Historical Data
**Impact**: Medium - Limits forecast quality
**Probability**: Low (1000+ cases prerequisite)
**Mitigation**:
- Require minimum data threshold before forecasting
- Display data sufficiency warnings
- Use longer lookback periods
- Supplement with sector benchmarks from external sources

### Risk 3: High Compute Costs
**Impact**: Medium - Expensive to run daily
**Probability**: Medium
**Mitigation**:
- Cache intelligence for 24 hours
- Incremental updates (not full recomputation)
- Optimize SQL queries with indexes
- Use background jobs during off-peak hours
- Consider cheaper AI models for less critical analysis

---

## 📚 Resources

- [Prophet Forecasting Library](https://facebook.github.io/prophet/)
- [Nx Machine Learning for Elixir](https://hexdocs.pm/nx/)
- [D3.js Data Visualization](https://d3js.org/)
- [Time Series Forecasting Guide](https://otexts.com/fpp3/)

---

**Sprint Owner**: [Name]
**Stakeholders**: Product Manager, CTO, Chief Risk Officer
**Sprint Start Date**: [Date]
**Sprint End Date**: [Date + 3 weeks]
