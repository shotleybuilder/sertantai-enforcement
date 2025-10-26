defmodule EhsEnforcement.Scraping.Strategies.Hse.CaseStrategyTest do
  use ExUnit.Case, async: true

  alias EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy
  alias EhsEnforcement.Scraping.ScrapeSession

  describe "validate_params/1" do
    test "validates correct parameters with all fields" do
      params = %{start_page: 1, max_pages: 10, database: "convictions"}
      assert {:ok, validated} = CaseStrategy.validate_params(params)
      assert validated.start_page == 1
      assert validated.max_pages == 10
      assert validated.database == "convictions"
    end

    test "validates parameters with string values" do
      params = %{"start_page" => "5", "max_pages" => "20", "database" => "convictions"}
      assert {:ok, validated} = CaseStrategy.validate_params(params)
      assert validated.start_page == 5
      assert validated.max_pages == 20
      assert validated.database == "convictions"
    end

    test "applies default values for missing parameters" do
      params = %{}
      assert {:ok, validated} = CaseStrategy.validate_params(params)
      assert validated.start_page == 1
      assert validated.max_pages == 10
      assert validated.database == "convictions"
    end

    test "applies default start_page when only max_pages provided" do
      params = %{max_pages: 5}
      assert {:ok, validated} = CaseStrategy.validate_params(params)
      assert validated.start_page == 1
      assert validated.max_pages == 5
    end

    test "validates appeals database" do
      params = %{start_page: 1, max_pages: 10, database: "appeals"}
      assert {:ok, validated} = CaseStrategy.validate_params(params)
      assert validated.database == "appeals"
    end

    test "returns error for invalid start_page (negative)" do
      params = %{start_page: -1, max_pages: 10}
      assert {:error, message} = CaseStrategy.validate_params(params)
      assert message =~ "start_page must be a positive integer"
    end

    test "returns error for invalid start_page (zero)" do
      params = %{start_page: 0, max_pages: 10}
      assert {:error, message} = CaseStrategy.validate_params(params)
      assert message =~ "start_page must be a positive integer"
    end

    test "returns error for invalid start_page (non-integer)" do
      params = %{start_page: "invalid", max_pages: 10}
      assert {:error, message} = CaseStrategy.validate_params(params)
      assert message =~ "start_page must be a positive integer"
    end

    test "returns error for invalid max_pages (negative)" do
      params = %{start_page: 1, max_pages: -5}
      assert {:error, message} = CaseStrategy.validate_params(params)
      assert message =~ "max_pages must be a positive integer"
    end

    test "returns error for invalid max_pages (zero)" do
      params = %{start_page: 1, max_pages: 0}
      assert {:error, message} = CaseStrategy.validate_params(params)
      assert message =~ "max_pages must be a positive integer"
    end

    test "returns error for invalid database" do
      params = %{start_page: 1, max_pages: 10, database: "invalid_database"}
      assert {:error, message} = CaseStrategy.validate_params(params)
      assert message =~ "database must be one of"
    end

    test "returns error for notices database (wrong strategy)" do
      params = %{start_page: 1, max_pages: 10, database: "notices"}
      assert {:error, message} = CaseStrategy.validate_params(params)
      assert message =~ "database must be one of"
    end
  end

  describe "calculate_progress/1" do
    test "calculates 0% progress at start" do
      session = %ScrapeSession{current_page: 0, max_pages: 10}
      assert CaseStrategy.calculate_progress(session) == 0.0
    end

    test "calculates 50% progress at midpoint" do
      session = %ScrapeSession{current_page: 5, max_pages: 10}
      assert CaseStrategy.calculate_progress(session) == 50.0
    end

    test "calculates 100% progress at completion" do
      session = %ScrapeSession{current_page: 10, max_pages: 10}
      assert CaseStrategy.calculate_progress(session) == 100.0
    end

    test "handles edge case: total_pages = 0" do
      session = %ScrapeSession{current_page: 0, max_pages: 0}
      assert CaseStrategy.calculate_progress(session) == 0.0
    end

    test "handles nil current_page" do
      session = %ScrapeSession{current_page: nil, max_pages: 10}
      assert CaseStrategy.calculate_progress(session) == 0.0
    end

    test "calculates progress with map (non-struct)" do
      session = %{current_page: 3, max_pages: 10}
      assert CaseStrategy.calculate_progress(session) == 30.0
    end

    test "handles empty map" do
      session = %{}
      assert CaseStrategy.calculate_progress(session) == 0.0
    end
  end

  describe "format_progress_display/1" do
    test "formats all required fields from ScrapeSession" do
      session = %ScrapeSession{
        current_page: 5,
        max_pages: 10,
        cases_found: 42,
        cases_created: 15,
        cases_exist_total: 27,
        status: :running
      }

      display = CaseStrategy.format_progress_display(session)

      assert display.percentage == 50.0
      assert display.current_page == 5
      assert display.total_pages == 10
      assert display.cases_found == 42
      assert display.cases_created == 15
      assert display.cases_exist_total == 27
      assert display.status == :running
    end

    test "formats display with default values for missing fields" do
      session = %ScrapeSession{
        current_page: nil,
        max_pages: 10,
        cases_found: 0,
        cases_created: 0,
        cases_exist_total: 0,
        status: :idle
      }

      display = CaseStrategy.format_progress_display(session)

      assert display.percentage == 0.0
      assert display.current_page == 0
      assert display.total_pages == 10
      assert display.cases_found == 0
      assert display.cases_created == 0
      assert display.cases_exist_total == 0
      assert display.status == :idle
    end

    test "formats display from map (non-struct)" do
      session = %{
        current_page: 2,
        max_pages: 5,
        cases_found: 10,
        cases_created: 3,
        cases_exist_total: 7,
        status: :completed
      }

      display = CaseStrategy.format_progress_display(session)

      assert display.percentage == 40.0
      assert display.current_page == 2
      assert display.total_pages == 5
    end
  end

  describe "static callback functions" do
    test "strategy_name/0 returns correct name" do
      assert CaseStrategy.strategy_name() == "HSE Case Scraping"
    end

    test "agency_identifier/0 returns :hse" do
      assert CaseStrategy.agency_identifier() == :hse
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
      session = %ScrapeSession{current_page: 1, max_pages: 2}
      result = CaseStrategy.calculate_progress(session)
      assert is_float(result)
      assert result >= 0.0 and result <= 100.0
    end

    test "format_progress_display/1 returns map" do
      session = %ScrapeSession{current_page: 1, max_pages: 2}
      result = CaseStrategy.format_progress_display(session)
      assert is_map(result)
      assert Map.has_key?(result, :percentage)
    end
  end
end
