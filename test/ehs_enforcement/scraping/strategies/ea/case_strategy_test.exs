defmodule EhsEnforcement.Scraping.Strategies.Ea.CaseStrategyTest do
  use ExUnit.Case, async: true

  alias EhsEnforcement.Scraping.Strategies.EA.CaseStrategy
  alias EhsEnforcement.Scraping.ScrapeSession

  describe "validate_params/1" do
    test "validates correct parameters with all fields" do
      params = %{
        date_from: ~D[2024-01-01],
        date_to: ~D[2024-12-31],
        action_types: [:court_case]
      }

      assert {:ok, validated} = CaseStrategy.validate_params(params)
      assert validated.date_from == ~D[2024-01-01]
      assert validated.date_to == ~D[2024-12-31]
      assert validated.action_types == [:court_case]
    end

    test "validates parameters with string dates" do
      params = %{
        "date_from" => "2024-01-01",
        "date_to" => "2024-12-31",
        "action_types" => [:court_case]
      }

      assert {:ok, validated} = CaseStrategy.validate_params(params)
      assert validated.date_from == ~D[2024-01-01]
      assert validated.date_to == ~D[2024-12-31]
    end

    test "applies default values for missing parameters" do
      params = %{}
      assert {:ok, validated} = CaseStrategy.validate_params(params)
      assert %Date{} = validated.date_from
      assert %Date{} = validated.date_to
      assert validated.action_types == [:court_case]
    end

    test "validates multiple action types" do
      params = %{
        date_from: ~D[2024-01-01],
        date_to: ~D[2024-12-31],
        action_types: [:court_case, :caution]
      }

      assert {:ok, validated} = CaseStrategy.validate_params(params)
      assert validated.action_types == [:court_case, :caution]
    end

    test "returns error for invalid date_from format" do
      params = %{date_from: "invalid", date_to: ~D[2024-12-31]}
      assert {:error, message} = CaseStrategy.validate_params(params)
      assert message =~ "date_from must be a valid date"
    end

    test "returns error for date_to before date_from" do
      params = %{
        date_from: ~D[2024-12-31],
        date_to: ~D[2024-01-01]
      }

      assert {:error, message} = CaseStrategy.validate_params(params)
      assert message =~ "date_to must be on or after date_from"
    end

    test "returns error for invalid action type" do
      params = %{
        date_from: ~D[2024-01-01],
        date_to: ~D[2024-12-31],
        action_types: [:invalid_type]
      }

      assert {:error, message} = CaseStrategy.validate_params(params)
      assert message =~ "Invalid action types"
    end

    test "returns error for enforcement_notice action type (wrong strategy)" do
      params = %{
        date_from: ~D[2024-01-01],
        date_to: ~D[2024-12-31],
        action_types: [:enforcement_notice]
      }

      assert {:error, message} = CaseStrategy.validate_params(params)
      assert message =~ "Invalid action types"
    end
  end

  describe "calculate_progress/1" do
    test "calculates 0% progress at start" do
      session = %ScrapeSession{cases_found: 100, cases_processed: 0}
      assert CaseStrategy.calculate_progress(session) == 0.0
    end

    test "calculates 50% progress at midpoint" do
      session = %ScrapeSession{cases_found: 100, cases_processed: 50}
      assert CaseStrategy.calculate_progress(session) == 50.0
    end

    test "calculates 100% progress at completion" do
      session = %ScrapeSession{cases_found: 100, cases_processed: 100}
      assert CaseStrategy.calculate_progress(session) == 100.0
    end

    test "handles edge case: cases_found = 0" do
      session = %ScrapeSession{cases_found: 0, cases_processed: 0}
      assert CaseStrategy.calculate_progress(session) == 0.0
    end

    test "handles nil cases_processed" do
      session = %ScrapeSession{cases_found: 100, cases_processed: nil}
      # Should treat nil as 0
      assert CaseStrategy.calculate_progress(session) == 0.0
    end

    test "calculates progress with map (non-struct)" do
      session = %{cases_found: 100, cases_processed: 25}
      assert CaseStrategy.calculate_progress(session) == 25.0
    end

    test "handles empty map" do
      session = %{}
      assert CaseStrategy.calculate_progress(session) == 0.0
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
        action_types: [:court_case],
        status: :running
      }

      display = CaseStrategy.format_progress_display(session)

      assert display.percentage == 50.0
      assert display.cases_found == 100
      assert display.cases_processed == 50
      assert display.cases_created == 20
      assert display.cases_exist_total == 30
      assert display.date_from == ~D[2024-01-01]
      assert display.date_to == ~D[2024-12-31]
      assert display.action_types == [:court_case]
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

      display = CaseStrategy.format_progress_display(session)

      assert display.percentage == 0.0
      assert display.cases_found == 0
      assert display.cases_processed == 0
      assert display.cases_created == 0
      assert display.cases_exist_total == 0
      assert display.status == :idle
    end

    test "formats display from map (non-struct)" do
      session = %{
        cases_found: 200,
        cases_processed: 100,
        cases_created: 40,
        cases_exist_total: 60,
        date_from: ~D[2024-01-01],
        date_to: ~D[2024-12-31],
        action_types: [:court_case, :caution],
        status: :completed
      }

      display = CaseStrategy.format_progress_display(session)

      assert display.percentage == 50.0
      assert display.cases_found == 200
      assert display.action_types == [:court_case, :caution]
    end
  end

  describe "static callback functions" do
    test "strategy_name/0 returns correct name" do
      assert CaseStrategy.strategy_name() == "Environment Agency Case Scraping"
    end

    test "agency_identifier/0 returns :ea" do
      assert CaseStrategy.agency_identifier() == :ea
    end

    test "enforcement_type/0 returns :case" do
      assert CaseStrategy.enforcement_type() == :case
    end
  end

  describe "behavior compliance" do
    test "implements all required callbacks" do
      # Verify module implements the behavior
      assert CaseStrategy.__info__(:attributes)[:behaviour] == [
               EhsEnforcement.Scraping.ScrapeStrategy
             ]
    end

    test "validate_params/1 returns expected tuple format" do
      result = CaseStrategy.validate_params(%{})
      assert match?({:ok, _}, result) or match?({:error, _}, result)
    end

    test "calculate_progress/1 returns float" do
      session = %ScrapeSession{cases_found: 100, cases_processed: 50}
      result = CaseStrategy.calculate_progress(session)
      assert is_float(result)
      assert result >= 0.0 and result <= 100.0
    end

    test "format_progress_display/1 returns map" do
      session = %ScrapeSession{cases_found: 100, cases_processed: 50}
      result = CaseStrategy.format_progress_display(session)
      assert is_map(result)
      assert Map.has_key?(result, :percentage)
    end
  end
end
