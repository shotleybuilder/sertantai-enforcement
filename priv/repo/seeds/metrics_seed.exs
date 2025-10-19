# Metrics Seed Script
# Creates initial metrics data for dashboard performance testing
# Generates 9 rows: 3 periods (week/month/year) × 3 agency configurations (all/HSE/EA)

alias EhsEnforcement.Enforcement.Metrics

IO.puts("\n=== Starting Metrics Seed ===\n")
IO.puts("This will generate 9 materialized metrics rows:")
IO.puts("  - Tier 1: 3 rows (all agencies × week/month/year)")
IO.puts("  - Tier 2: 6 rows (HSE/EA × week/month/year)")
IO.puts("")

# Check if metrics table exists and has data
case Metrics.get_current_metrics() do
  {:ok, existing_metrics} when is_list(existing_metrics) and length(existing_metrics) > 0 ->
    IO.puts("⚠️  Found #{length(existing_metrics)} existing metrics rows")
    IO.puts("    Proceeding will refresh all metrics with current data...")
    IO.puts("")

  {:ok, []} ->
    IO.puts("✓ Metrics table is empty - ready for initial seed")
    IO.puts("")

  {:error, _error} ->
    IO.puts("⚠️  Could not read metrics table - may need to run migrations")
    IO.puts("    Run: mix ecto.migrate")
    IO.puts("")
end

# Seed/refresh all metrics
IO.puts("🔄 Refreshing all metrics combinations...")
start_time = System.monotonic_time(:millisecond)

case Metrics.refresh_all_metrics(:admin) do
  {:ok, results} ->
    end_time = System.monotonic_time(:millisecond)
    duration = end_time - start_time

    IO.puts("✅ Metrics refresh completed in #{duration}ms")
    IO.puts("")

    # Display results summary
    case Metrics.get_current_metrics() do
      {:ok, metrics} when is_list(metrics) ->
        IO.puts("📊 Created #{length(metrics)} metrics rows:")
        IO.puts("")

        # Group by period and agency
        Enum.each([:week, :month, :year], fn period ->
          period_metrics = Enum.filter(metrics, fn m -> m.period == period end)

          if length(period_metrics) > 0 do
            IO.puts("  #{String.upcase(to_string(period))}:")

            Enum.each(period_metrics, fn metric ->
              agency_label =
                if metric.agency_id do
                  # Load agency name if needed
                  "Agency ID #{metric.agency_id}"
                else
                  "All Agencies"
                end

              recent_activity_count =
                if is_map(metric.recent_activity) do
                  metric.recent_activity |> Map.get("items", []) |> length()
                else
                  0
                end

              IO.puts(
                "    - #{agency_label}: #{metric.total_cases_count} cases, #{metric.total_notices_count} notices, #{recent_activity_count} recent items"
              )
            end)

            IO.puts("")
          end
        end)

        IO.puts("✅ Seed complete! Dashboard ready for performance testing.")
        IO.puts("   Open: http://localhost:4002/")
        IO.puts("")

      {:error, error} ->
        IO.puts("⚠️  Could not verify created metrics: #{inspect(error)}")
    end

  {:error, error} ->
    IO.puts("❌ Metrics refresh failed: #{inspect(error)}")
    IO.puts("")
    IO.puts("Troubleshooting:")
    IO.puts("  1. Verify database is running: mix ecto.migrate")
    IO.puts("  2. Check that metrics table exists")
    IO.puts("  3. Verify there's data in cases/notices tables to aggregate")
    IO.puts("")
end

IO.puts("=== Seed Complete ===\n")
