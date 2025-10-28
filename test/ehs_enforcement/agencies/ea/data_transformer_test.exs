defmodule EhsEnforcement.Agencies.Ea.DataTransformerTest do
  @moduledoc """
  Unit tests for EA data transformation logic.

  Tests the transformation of raw EA data into standardized Case resource format,
  including nil safety and data normalization.
  """

  use ExUnit.Case, async: true

  alias EhsEnforcement.Agencies.Ea.DataTransformer

  # Common test data setup
  def complete_ea_record do
    %{
      ea_record_id: "test123",
      offender_name: "Test Company Ltd",
      # Test address normalization
      address: "  123 Test Street  ",
      action_date: ~D[2025-08-01],
      action_type: :court_case,
      company_registration_number: "12345678",
      industry_sector: "Manufacturing",
      town: "Test Town",
      county: "Test County",
      postcode: "TE1 2ST",
      total_fine: Decimal.new(5000),
      offence_description: "Test offence",
      offence_type: "Environmental violation",
      case_reference: "EA/CC/2025/001",
      event_reference: "EVT123",
      agency_function: "Regulation",
      water_impact: "Minor",
      land_impact: nil,
      air_impact: nil,
      act: "Environmental Protection Act",
      section: "Section 23",
      legal_reference: nil,
      detail_url: "https://example.com/test",
      scraped_at: DateTime.utc_now()
    }
  end

  def nil_heavy_ea_record do
    %{
      ea_record_id: "test789",
      # Should not crash clean_company_name/1
      offender_name: nil,
      # Should not crash normalize_address/1
      address: nil,
      action_date: ~D[2025-08-01],
      action_type: :court_case,
      company_registration_number: nil,
      industry_sector: nil,
      town: nil,
      county: nil,
      postcode: nil,
      total_fine: Decimal.new(0),
      # Required field
      offence_description: "Test offence",
      # Required field
      offence_type: "Test offence type",
      case_reference: nil,
      event_reference: nil,
      agency_function: nil,
      water_impact: nil,
      land_impact: nil,
      air_impact: nil,
      act: nil,
      section: nil,
      legal_reference: nil,
      detail_url: "https://example.com/test",
      scraped_at: DateTime.utc_now()
    }
  end

  def address_test_record do
    %{
      ea_record_id: "test_addr",
      offender_name: "Address Test Company",
      # Should be normalized
      address: "  Test Address  ",
      action_date: ~D[2025-08-01],
      action_type: :court_case,
      total_fine: Decimal.new(0),
      offence_description: "Address test",
      offence_type: "Test",
      act: "Test Act",
      section: "Test Section",
      case_reference: nil,
      event_reference: nil,
      company_registration_number: nil,
      industry_sector: nil,
      town: nil,
      county: nil,
      postcode: nil,
      agency_function: nil,
      water_impact: nil,
      land_impact: nil,
      air_impact: nil,
      legal_reference: nil,
      detail_url: nil,
      scraped_at: DateTime.utc_now()
    }
  end

  def company_name_test_record do
    %{
      ea_record_id: "test_name",
      # Should be normalized
      offender_name: "  Test Company Ltd  ",
      address: "Test Address",
      action_date: ~D[2025-08-01],
      action_type: :court_case,
      total_fine: Decimal.new(0),
      offence_description: "Company name test",
      offence_type: "Test",
      act: "Test Act",
      section: "Test Section",
      case_reference: nil,
      event_reference: nil,
      company_registration_number: nil,
      industry_sector: nil,
      town: nil,
      county: nil,
      postcode: nil,
      agency_function: nil,
      water_impact: nil,
      land_impact: nil,
      air_impact: nil,
      legal_reference: nil,
      detail_url: nil,
      scraped_at: DateTime.utc_now()
    }
  end

  describe "EA data transformation" do
    test "transform_ea_record/1 handles complete EA record" do
      transformed = DataTransformer.transform_ea_record(complete_ea_record())

      # Should successfully transform without errors
      assert is_map(transformed)
      # Uses case_reference when provided
      assert transformed[:regulator_id] == "EA/CC/2025/001"
      assert transformed[:offender_name] == "Test Company Ltd"
      # Normalized (trimmed)
      assert transformed[:address] == "123 Test Street"
      assert transformed[:agency_code] == :ea
    end

    test "transform_ea_record/1 handles nil values safely" do
      # This should NOT crash with String.trim(nil) error
      transformed = DataTransformer.transform_ea_record(nil_heavy_ea_record())

      # Verify nil values are handled correctly
      assert transformed[:offender_name] == nil
      assert transformed[:address] == nil
      # Should generate ID even with nil values
      assert is_binary(transformed[:regulator_id])
    end

    test "normalize_address/1 handles various input types" do
      # Test with valid address (should be normalized)
      address_record = address_test_record()
      result_valid = DataTransformer.transform_ea_record(address_record)
      # Trimmed spaces
      assert result_valid[:address] == "Test Address"

      # Test with nil address (should remain nil)
      nil_address_record = Map.put(address_record, :address, nil)
      result_nil = DataTransformer.transform_ea_record(nil_address_record)
      assert result_nil[:address] == nil
    end

    test "clean_company_name/1 handles various input types" do
      # Test with valid company name (should be normalized)
      name_record = company_name_test_record()
      result_valid = DataTransformer.transform_ea_record(name_record)
      # Trimmed spaces
      assert result_valid[:offender_name] == "Test Company Ltd"

      # Test with nil company name (should remain nil)
      nil_name_record = Map.put(name_record, :offender_name, nil)
      result_nil = DataTransformer.transform_ea_record(nil_name_record)
      assert result_nil[:offender_name] == nil
    end
  end
end
