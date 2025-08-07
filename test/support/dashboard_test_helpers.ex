defmodule EhsEnforcementWeb.DashboardTestHelpers do
  @moduledoc """
  Test helpers for Dashboard LiveView tests.
  
  Provides utilities for creating test data, simulating user interactions,
  and asserting dashboard-specific behaviors.
  """

  alias EhsEnforcement.Enforcement
  
  require Ash.Query
  import Ash.Expr
  import Phoenix.LiveViewTest
  import ExUnit.Assertions

  @doc """
  Creates a complete test dataset for dashboard testing.
  
  Returns a map with agencies, offenders, cases, and useful references.
  """
  def create_dashboard_test_data do
    # Create agencies with different states
    {:ok, hse} = Enforcement.create_agency(%{
      code: :hse,
      name: "Health and Safety Executive", 
      enabled: true
    })

    {:ok, ea} = Enforcement.create_agency(%{
      code: :ea,
      name: "Environment Agency",
      enabled: true  
    })

    {:ok, onr} = Enforcement.create_agency(%{
      code: :onr,
      name: "Office for Nuclear Regulation",
      enabled: false
    })

    # Create diverse offenders
    offenders = [
      %{name: "Manufacturing Corp Ltd", local_authority: "Birmingham", postcode: "B1 1AA"},
      %{name: "Chemical Industries PLC", local_authority: "Manchester", postcode: "M1 1BB"},
      %{name: "Construction Co", local_authority: "Leeds", postcode: "LS1 1CC"},
      %{name: "Waste Management Ltd", local_authority: "Bristol", postcode: "BS1 1DD"},
      %{name: "Tech Solutions Inc", local_authority: "London", postcode: "SW1 1EE"}
    ]
    |> Enum.map(fn attrs ->
      {:ok, offender} = Enforcement.create_offender(attrs)
      offender
    end)

    # Create cases with realistic data
    base_date = ~D[2024-01-01]
    
    cases = create_test_cases([
      # Recent HSE cases
      {hse, Enum.at(offenders, 0), Date.add(base_date, 25), "15000.00", 
       "HSE-2024-001", "Failure to ensure workplace safety"},
      {hse, Enum.at(offenders, 1), Date.add(base_date, 22),  "8500.00",
       "HSE-2024-002", "Inadequate risk assessment"},
      {hse, Enum.at(offenders, 0), Date.add(base_date, 20), "22000.00",
       "HSE-2024-003", "Multiple safety violations"},
      {hse, Enum.at(offenders, 2), Date.add(base_date, 15), "12000.00",
       "HSE-2024-004", "Equipment safety breach"},
       
      # Environment Agency cases
      {ea, Enum.at(offenders, 2), Date.add(base_date, 24), "12000.00",
       "EA-2024-001", "Illegal waste disposal"},
      {ea, Enum.at(offenders, 3), Date.add(base_date, 18), "35000.00", 
       "EA-2024-002", "Water pollution incident"},
      {ea, Enum.at(offenders, 4), Date.add(base_date, 12), "8000.00",
       "EA-2024-003", "Air quality violation"},
       
      # Older cases for timeline diversity
      {hse, Enum.at(offenders, 3), Date.add(base_date, -15), "5000.00",
       "HSE-2023-099", "Historic safety breach"},
      {ea, Enum.at(offenders, 1), Date.add(base_date, -10), "7500.00",
       "EA-2023-087", "Previous environmental breach"}
    ])

    %{
      agencies: [hse, ea, onr],
      enabled_agencies: [hse, ea],
      disabled_agencies: [onr],
      offenders: offenders,
      cases: cases,
      hse: hse,
      ea: ea, 
      onr: onr,
      recent_cases: Enum.take(cases, 10) # Most recent for timeline
    }
  end

  @doc """
  Creates test cases from a list of case specifications.
  
  Each case spec is a tuple: {agency, offender, date, fine, id, breach}
  """
  def create_test_cases(case_specs) do
    case_specs
    |> Enum.map(fn {agency, offender, date, fine, regulator_id, breach} ->
      {:ok, case_record} = Enforcement.create_case(%{
        regulator_id: regulator_id,
        agency_id: agency.id,
        offender_id: offender.id,
        offence_action_date: date,
        offence_fine: Decimal.new(fine),
        offence_breaches: breach,
        last_synced_at: DateTime.utc_now()
      })
      case_record
    end)
    |> Enum.sort_by(& &1.offence_action_date, :desc)
  end

  @doc """
  Creates a minimal test dataset for basic testing.
  """
  def create_minimal_test_data do
    {:ok, agency} = Enforcement.create_agency(%{
      code: :test,
      name: "Test Agency",
      enabled: true
    })

    {:ok, offender} = Enforcement.create_offender(%{
      name: "Test Company Ltd",
      local_authority: "Test Council"
    })

    {:ok, case_record} = Enforcement.create_case(%{
      regulator_id: "TEST-001",
      agency_id: agency.id,
      offender_id: offender.id,
      offence_action_date: ~D[2024-01-15],
      offence_fine: Decimal.new("5000.00"),
      offence_breaches: "Test breach",
      last_synced_at: DateTime.utc_now()
    })

    %{agency: agency, offender: offender, case: case_record}
  end

  @doc """
  Creates performance test data with many records.
  """
  def create_performance_test_data(opts \\ []) do
    agency_count = Keyword.get(opts, :agencies, 10)
    offender_count = Keyword.get(opts, :offenders, 50)
    case_count = Keyword.get(opts, :cases, 200)

    # Create agencies
    agencies = Enum.map(1..agency_count, fn i ->
      {:ok, agency} = Enforcement.create_agency(%{
        code: String.to_atom("perf_agency_#{i}"),
        name: "Performance Agency #{i}",
        enabled: rem(i, 4) != 0 # Mix of enabled/disabled
      })
      agency
    end)

    # Create offenders
    offenders = Enum.map(1..offender_count, fn i ->
      {:ok, offender} = Enforcement.create_offender(%{
        name: "Performance Company #{i}",
        local_authority: "Council #{rem(i, 20) + 1}",
        postcode: "P#{i |> Integer.to_string() |> String.pad_leading(2, "0")} 1AA"
      })
      offender
    end)

    # Create cases
    base_date = ~D[2024-01-01]
    cases = Enum.map(1..case_count, fn i ->
      agency = Enum.at(agencies, rem(i, agency_count))
      offender = Enum.at(offenders, rem(i, offender_count))
      
      {:ok, case_record} = Enforcement.create_case(%{
        regulator_id: "PERF-#{String.pad_leading(Integer.to_string(i), 4, "0")}",
        agency_id: agency.id,
        offender_id: offender.id,
        offence_action_date: Date.add(base_date, rem(i, 365) - 100),
        offence_fine: Decimal.new("#{rem(i, 50) + 1}000.00"),
        offence_breaches: "Performance test breach #{i}",
        last_synced_at: DateTime.utc_now()
      })
      case_record
    end)

    %{
      agencies: agencies,
      offenders: offenders,
      cases: cases,
      enabled_agencies: Enum.filter(agencies, & &1.enabled),
      disabled_agencies: Enum.filter(agencies, &(not &1.enabled))
    }
  end

  @doc """
  Clears all test data from the database using proper Ash patterns.
  """
  def clear_test_data do
    # Delete cases first (they have foreign key constraints)
    {:ok, cases} = EhsEnforcement.Enforcement.Case |> Ash.read()
    Enum.each(cases, &Enforcement.destroy_case!/1)
    
    # Delete offenders (referenced by cases) - use Ash.destroy! since no code interface defined
    {:ok, offenders} = EhsEnforcement.Enforcement.Offender |> Ash.read()
    Enum.each(offenders, &Ash.destroy!/1)
    
    # Delete agencies last - use Ash.destroy! since no code interface defined
    {:ok, agencies} = EhsEnforcement.Enforcement.Agency |> Ash.read()
    Enum.each(agencies, &Ash.destroy!/1)
  end

  @doc """
  Asserts that agency statistics are displayed correctly in the dashboard.
  """
  def assert_agency_statistics(view, agency_name, expected_cases, expected_total_fines) do
    agency_card = element(view, "[data-testid='agency-card']:has(h3:fl-contains('#{agency_name}'))")
    assert has_element?(agency_card), "Agency card for '#{agency_name}' should be present"
    
    agency_content = render(agency_card)
    
    # Check case count
    assert agency_content =~ "#{expected_cases}",
      "Agency '#{agency_name}' should show #{expected_cases} cases"
    
    # Check total fines (handle both formatted and unformatted)
    fines_str = expected_total_fines |> to_string() |> String.replace(",", "")
    # Use simple formatting instead of Number.Currency
    formatted_fines = "£#{fines_str}"
    
    assert agency_content =~ fines_str or agency_content =~ formatted_fines,
      "Agency '#{agency_name}' should show correct total fines"
  end

  @doc """
  Asserts that the recent activity timeline is ordered correctly.
  """
  def assert_timeline_order(view, expected_case_ids) do
    timeline = element(view, "[data-testid='recent-cases']") |> render()
    
    # Find positions of each case ID
    positions = expected_case_ids
    |> Enum.map(fn case_id ->
      case :binary.match(timeline, case_id) do
        {pos, _} -> {case_id, pos}
        :nomatch -> {case_id, 99999}
      end
    end)
    |> Enum.filter(fn {_, pos} -> pos < 99999 end)
    |> Enum.sort_by(fn {_, pos} -> pos end)
    
    actual_order = Enum.map(positions, fn {id, _} -> id end)
    
    assert actual_order == expected_case_ids,
      "Timeline should show cases in expected order. Expected: #{inspect(expected_case_ids)}, Got: #{inspect(actual_order)}"
  end

  @doc """
  Simulates a sync operation with progress updates.
  """
  def simulate_sync_operation(view, agency_code, opts \\ []) do
    duration = Keyword.get(opts, :duration, 100) # milliseconds
    progress_steps = Keyword.get(opts, :progress_steps, [25, 50, 75, 100])
    should_fail = Keyword.get(opts, :should_fail, false)
    
    # Send sync start
    send(view.pid, {:sync_started, agency_code})
    
    # Send progress updates
    Enum.each(progress_steps, fn progress ->
      :timer.sleep(div(duration, length(progress_steps)))
      send(view.pid, {:sync_progress, agency_code, progress})
    end)
    
    # Send completion or error
    if should_fail do
      send(view.pid, {:sync_error, agency_code, "Simulated sync failure"})
    else
      send(view.pid, {:sync_complete, agency_code, DateTime.utc_now()})
    end
    
    :timer.sleep(10) # Allow message processing
  end

  @doc """
  Asserts that sync status is displayed correctly.
  """
  def assert_sync_status(view, agency_name, expected_status) do
    agency_card = element(view, "[data-testid='agency-card']:has(h3:fl-contains('#{agency_name}'))")
    status_element = element(agency_card, "[data-testid='sync-status']")
    
    assert has_element?(status_element), "Sync status should be present for #{agency_name}"
    
    status_content = render(status_element)
    
    case expected_status do
      :never -> 
        assert status_content =~ "Never" or status_content =~ "No sync"
      :in_progress ->
        assert status_content =~ "Syncing" or status_content =~ "In Progress" or status_content =~ "%"
      :complete ->
        assert status_content =~ "Complete" or status_content =~ "Success" or status_content =~ "ago"
      :error ->
        assert status_content =~ "Error" or status_content =~ "Failed" or status_content =~ "⚠"
      status_text when is_binary(status_text) ->
        assert status_content =~ status_text
    end
  end

  @doc """
  Asserts that the dashboard summary statistics are correct.
  """
  def assert_dashboard_summary(view, expected_total_cases, expected_total_agencies, expected_total_fines \\ nil) do
    html = render(view)
    
    # Check total cases
    assert html =~ "#{expected_total_cases} Total Cases" or 
           html =~ "Total: #{expected_total_cases}",
      "Dashboard should show #{expected_total_cases} total cases"
    
    # Check total agencies
    assert html =~ "#{expected_total_agencies} Agencies",
      "Dashboard should show #{expected_total_agencies} agencies"
    
    # Check total fines if provided
    if expected_total_fines do
      fines_str = expected_total_fines |> to_string() |> String.replace(",", "")
      fines_formatted = "£#{fines_str}"
      
      assert html =~ fines_str or html =~ fines_formatted,
        "Dashboard should show correct total fines"
    end
  end

  @doc """
  Creates test data and measures performance of an operation.
  """
  def measure_performance(operation, setup_data \\ nil) do
    start_time = System.monotonic_time(:microsecond)
    
    result = if setup_data do
      operation.(setup_data)
    else
      operation.()
    end
    
    end_time = System.monotonic_time(:microsecond)
    duration = end_time - start_time
    
    {result, duration}
  end

  @doc """
  Asserts that an operation completes within the specified time limit.
  """
  def assert_performance(operation, max_time_ms, message \\ "Operation should complete within time limit") do
    {result, duration_microseconds} = measure_performance(operation)
    duration_ms = div(duration_microseconds, 1000)
    
    assert duration_ms <= max_time_ms, 
      "#{message}. Expected: <= #{max_time_ms}ms, Got: #{duration_ms}ms"
    
    result
  end

  @doc """
  Creates a mock sync event for testing PubSub behavior.
  """
  def create_sync_event(type, agency_code, data \\ %{}) do
    case type do
      :started -> {:sync_started, agency_code}
      :progress -> {:sync_progress, agency_code, Map.get(data, :progress, 50)}
      :complete -> {:sync_complete, agency_code, Map.get(data, :timestamp, DateTime.utc_now())}
      :error -> {:sync_error, agency_code, Map.get(data, :error, "Test error")}
      :data_updated -> {:data_updated, agency_code}
    end
  end

  @doc """
  Verifies that required HTML accessibility attributes are present.
  """
  def assert_accessibility_attributes(view) do
    html = render(view)
    
    # Check for semantic HTML
    assert html =~ "<main>" or html =~ ~s(role="main"), 
      "Dashboard should have semantic main content area"
    
    # Check for proper heading hierarchy
    assert html =~ "<h1>" or html =~ "<h2>",
      "Dashboard should have proper heading structure"
    
    # Check for ARIA attributes
    assert html =~ "aria-label" or html =~ "aria-describedby",
      "Dashboard should include ARIA attributes for accessibility"
    
    # Check that interactive elements are properly labeled
    sync_buttons = element(view, "[phx-click='sync']", :all) |> render()
    assert sync_buttons =~ "aria-label" or sync_buttons =~ "title",
      "Sync buttons should have accessible labels"
  end

  @doc """
  Verifies responsive design CSS classes are present.
  """
  def assert_responsive_design(view) do
    html = render(view)
    
    # Check for responsive breakpoint classes
    assert html =~ "sm:" or html =~ "md:" or html =~ "lg:" or html =~ "xl:",
      "Dashboard should include responsive breakpoint classes"
    
    # Check for flexible layout classes
    assert html =~ "grid" or html =~ "flex",
      "Dashboard should use flexible layout systems"
    
    # Check for responsive spacing
    assert html =~ "p-" or html =~ "m-" or html =~ "space-",
      "Dashboard should include responsive spacing classes"
  end

  @doc """
  Simulates user interaction with error handling.
  """
  def safe_click(view, event, params \\ %{}) do
    try do
      render_click(view, event, params)
    rescue
      error ->
        {:error, error}
    else
      result -> {:ok, result}
    end
  end

  @doc """
  Creates test data for edge case scenarios.
  """
  def create_edge_case_data do
    # Agency with very long name
    {:ok, long_name_agency} = Enforcement.create_agency(%{
      code: :long,
      name: "This is an Extremely Long Agency Name That Might Cause Layout Issues in the User Interface",
      enabled: true
    })

    # Offender with edge case data
    {:ok, edge_offender} = Enforcement.create_offender(%{
      name: "Company with Special Characters & Symbols Ltd. (UK)",
      local_authority: "Council-with-Hyphens & Symbols",
      postcode: "SW1A 1AA"
    })

    # Case with extreme values
    {:ok, edge_case} = Enforcement.create_case(%{
      regulator_id: "EDGE-CASE-WITH-VERY-LONG-ID-2024-001",
      agency_id: long_name_agency.id,
      offender_id: edge_offender.id,
      offence_action_date: ~D[2024-01-01],
      offence_fine: Decimal.new("999999.99"), # Very large fine
      offence_breaches: "This is a very long breach description that might cause display issues when rendered in the user interface. It contains multiple sentences and detailed information about the violation that occurred.",
      last_synced_at: DateTime.utc_now()
    })

    # Case with minimal data
    {:ok, minimal_offender} = Enforcement.create_offender(%{name: "Co"})
    
    {:ok, minimal_case} = Enforcement.create_case(%{
      regulator_id: "MIN",
      agency_id: long_name_agency.id,
      offender_id: minimal_offender.id,
      offence_action_date: ~D[2024-01-01],
      offence_fine: Decimal.new("1.00"), # Minimal fine
      offence_breaches: "X",
      last_synced_at: DateTime.utc_now()
    })

    %{
      long_name_agency: long_name_agency,
      edge_offender: edge_offender,
      minimal_offender: minimal_offender,
      edge_case: edge_case,
      minimal_case: minimal_case
    }
  end
end