defmodule EhsEnforcement.Scraping.Strategies.Ea.NoticeStrategyTest do
  use ExUnit.Case, async: true

  alias EhsEnforcement.Scraping.Strategies.EA.NoticeStrategy
  alias EhsEnforcement.Scraping.ScrapeSession

  describe "validate_params/1" do
    test "validates correct parameters with all fields" do
      params = %{
        date_from: ~D[2024-01-01],
        date_to: ~D[2024-12-31]
      }

      assert {:ok, validated} = NoticeStrategy.validate_params(params)
      assert validated.date_from == ~D[2024-01-01]
      assert validated.date_to == ~D[2024-12-31]
      assert validated.action_types == [:enforcement_notice]
    end

    test "validates parameters with string dates" do
      params = %{
        "date_from" => "2024-01-01",
        "date_to" => "2024-12-31"
      }

      assert {:ok, validated} = NoticeStrategy.validate_params(params)
      assert validated.date_from == ~D[2024-01-01]
      assert validated.date_to == ~D[2024-12-31]
    end

    test "applies default values for missing parameters" do
      params = %{}
      assert {:ok, validated} = NoticeStrategy.validate_params(params)
      assert %Date{} = validated.date_from
      assert %Date{} = validated.date_to
      assert validated.action_types == [:enforcement_notice]
    end

    test "always sets action_types to enforcement_notice" do
      # Action types parameter should be ignored for notice strategy
      params = %{
        date_from: ~D[2024-01-01],
        date_to: ~D[2024-12-31],
        action_types: [:court_case]
      }

      assert {:ok, validated} = NoticeStrategy.validate_params(params)
      assert validated.action_types == [:enforcement_notice]
    end

    test "returns error for invalid date_from format" do
      params = %{date_from: "invalid", date_to: ~D[2024-12-31]}
      assert {:error, message} = NoticeStrategy.validate_params(params)
      assert message =~ "date_from must be a valid date"
    end

    test "returns error for date_to before date_from" do
      params = %{
        date_from: ~D[2024-12-31],
        date_to: ~D[2024-01-01]
      }

      assert {:error, message} = NoticeStrategy.validate_params(params)
      assert message =~ "date_to must be on or after date_from"
    end
  end

  describe "calculate_progress/1" do
    test "calculates 0% progress at start" do
      # Note: Session uses "cases_*" fields for both cases and notices
      session = %ScrapeSession{cases_found: 100, cases_processed: 0}
      assert NoticeStrategy.calculate_progress(session) == 0.0
    end

    test "calculates 50% progress at midpoint" do
      session = %ScrapeSession{cases_found: 100, cases_processed: 50}
      assert NoticeStrategy.calculate_progress(session) == 50.0
    end

    test "calculates 100% progress at completion" do
      session = %ScrapeSession{cases_found: 100, cases_processed: 100}
      assert NoticeStrategy.calculate_progress(session) == 100.0
    end

    test "handles edge case: cases_found = 0" do
      session = %ScrapeSession{cases_found: 0, cases_processed: 0}
      assert NoticeStrategy.calculate_progress(session) == 0.0
    end

    test "calculates progress with map (non-struct)" do
      session = %{cases_found: 100, cases_processed: 75}
      assert NoticeStrategy.calculate_progress(session) == 75.0
    end

    test "handles empty map" do
      session = %{}
      assert NoticeStrategy.calculate_progress(session) == 0.0
    end
  end

  describe "format_progress_display/1" do
    test "formats all required fields from ScrapeSession" do
      session = %ScrapeSession{
        cases_found: 100,
        cases_processed: 50,
        cases_created: 20,
        cases_exist_total: 30,
        date_from: ~D[2024-01-01],
        date_to: ~D[2024-12-31],
        action_types: [:enforcement_notice],
        status: :running
      }

      display = NoticeStrategy.format_progress_display(session)

      # Note: Maps "cases_*" to "notices_*" for UI display
      assert display.percentage == 50.0
      assert display.notices_found == 100
      assert display.notices_processed == 50
      assert display.notices_created == 20
      assert display.notices_exist_total == 30
      assert display.date_from == ~D[2024-01-01]
      assert display.date_to == ~D[2024-12-31]
      assert display.action_types == [:enforcement_notice]
      assert display.status == :running
    end

    test "formats display with default values for missing fields" do
      session = %ScrapeSession{
        cases_found: 0,
        cases_processed: 0,
        cases_created: 0,
        cases_exist_total: 0,
        status: :idle
      }

      display = NoticeStrategy.format_progress_display(session)

      assert display.percentage == 0.0
      assert display.notices_found == 0
      assert display.notices_processed == 0
      assert display.notices_created == 0
      assert display.notices_exist_total == 0
      assert display.status == :idle
    end

    test "formats display from map (non-struct)" do
      session = %{
        cases_found: 200,
        cases_processed: 150,
        cases_created: 60,
        cases_exist_total: 90,
        date_from: ~D[2024-01-01],
        date_to: ~D[2024-12-31],
        status: :completed
      }

      display = NoticeStrategy.format_progress_display(session)

      assert display.percentage == 75.0
      assert display.notices_found == 200
      assert display.notices_processed == 150
    end
  end

  describe "static callback functions" do
    test "strategy_name/0 returns correct name" do
      assert NoticeStrategy.strategy_name() == "Environment Agency Notice Scraping"
    end

    test "agency_identifier/0 returns :environment_agency" do
      assert NoticeStrategy.agency_identifier() == :environment_agency
    end

    test "enforcement_type/0 returns :notice" do
      assert NoticeStrategy.enforcement_type() == :notice
    end
  end

  describe "behavior compliance" do
    test "implements all required callbacks" do
      # Verify module implements the behavior
      assert NoticeStrategy.__info__(:attributes)[:behaviour] == [
               EhsEnforcement.Scraping.ScrapeStrategy
             ]
    end

    test "validate_params/1 returns expected tuple format" do
      result = NoticeStrategy.validate_params(%{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "calculate_progress/1 returns float" do
      session = %ScrapeSession{cases_found: 100, cases_processed: 50}
      result = NoticeStrategy.calculate_progress(session)
      assert is_float(result)
      assert result >= 0.0 and result <= 100.0
    end

    test "format_progress_display/1 returns map" do
      session = %ScrapeSession{cases_found: 100, cases_processed: 50}
      result = NoticeStrategy.format_progress_display(session)
      assert is_map(result)
      assert Map.has_key?(result, :percentage)
      assert Map.has_key?(result, :notices_found)
    end
  end

  describe "progress tracking fix validation" do
    test "calculates non-zero progress when notices are processed" do
      # This test validates the fix for the EA Notice progress bug
      session = %ScrapeSession{
        cases_found: 50,
        cases_processed: 25
      }

      progress = NoticeStrategy.calculate_progress(session)

      # Should be 50%, not 0% (the bug)
      assert progress == 50.0
      assert progress > 0.0
    end

    test "progress increases as more notices are processed" do
      session_25 = %ScrapeSession{cases_found: 100, cases_processed: 25}
      session_50 = %ScrapeSession{cases_found: 100, cases_processed: 50}
      session_75 = %ScrapeSession{cases_found: 100, cases_processed: 75}

      assert NoticeStrategy.calculate_progress(session_25) == 25.0
      assert NoticeStrategy.calculate_progress(session_50) == 50.0
      assert NoticeStrategy.calculate_progress(session_75) == 75.0
    end
  end
end
