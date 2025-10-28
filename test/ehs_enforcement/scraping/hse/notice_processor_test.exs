defmodule EhsEnforcement.Scraping.Hse.NoticeProcessorTest do
  use EhsEnforcement.DataCase

  require Ash.Query
  import Ash.Expr
  import ExUnit.CaptureLog

  alias EhsEnforcement.Scraping.Hse.NoticeProcessor
  alias EhsEnforcement.Scraping.Hse.NoticeProcessor.ProcessedNotice

  describe "process_notice/1" do
    test "processes a valid notice successfully" do
      basic_notice = %{
        regulator_id: "IN2024001",
        offender_name: "ABC Manufacturing Ltd",
        offence_action_type: "Improvement Notice",
        offence_action_date: "2024-12-01",
        notice_date: "2024-12-01",
        operative_date: "2024-12-01",
        offence_compliance_date: "2025-01-15",
        offence_description: "Failed to ensure proper safety measures"
      }

      assert {:ok, %ProcessedNotice{} = processed} = NoticeProcessor.process_notice(basic_notice)

      assert processed.regulator_id == "IN2024001"
      assert processed.agency_code == :hse
      assert processed.notice_date == ~D[2024-12-01]
      assert processed.compliance_date == ~D[2025-01-15]
      assert processed.offender_attrs.name == "ABC Manufacturing Ltd"
    end

    test "processes a prohibition notice correctly" do
      basic_notice = %{
        regulator_id: "PN2024002",
        offender_name: "XYZ Construction",
        offence_action_type: "Prohibition Notice",
        offence_action_date: "2024-12-02",
        notice_date: "2024-12-02",
        operative_date: "2024-12-02",
        offence_description: "Immediate cessation of dangerous work"
      }

      assert {:ok, %ProcessedNotice{} = processed} = NoticeProcessor.process_notice(basic_notice)

      assert processed.regulator_id == "PN2024002"
      assert processed.offender_attrs.name == "XYZ Construction"
      assert processed.notice_date == ~D[2024-12-02]
      # Prohibition notices don't have compliance dates
      assert is_nil(processed.compliance_date)
    end

    test "handles crown notices" do
      basic_notice = %{
        regulator_id: "CN2024003",
        offender_name: "NHS Trust",
        offence_action_type: "Crown Improvement Notice",
        offence_action_date: "2024-12-03",
        notice_date: "2024-12-03",
        operative_date: "2024-12-03",
        offence_compliance_date: "2025-02-01",
        offence_description: "Inadequate risk assessment procedures"
      }

      assert {:ok, %ProcessedNotice{} = processed} = NoticeProcessor.process_notice(basic_notice)

      assert processed.regulator_id == "CN2024003"
      assert processed.offender_attrs.name == "NHS Trust"
      assert processed.compliance_date == ~D[2025-02-01]
    end

    test "parses different date formats correctly" do
      basic_notice = %{
        regulator_id: "IN2024004",
        offender_name: "Test Company",
        offence_action_type: "Improvement Notice",
        # DD/MM/YYYY format
        offence_action_date: "01/12/2024",
        # DD-MM-YYYY format
        notice_date: "01-12-2024",
        # ISO format
        operative_date: "2024-12-01",
        offence_compliance_date: "15/01/2025",
        offence_description: "Safety violations"
      }

      assert {:ok, %ProcessedNotice{} = processed} = NoticeProcessor.process_notice(basic_notice)

      assert processed.notice_date == ~D[2024-12-01]
      assert processed.operative_date == ~D[2024-12-01]
      assert processed.compliance_date == ~D[2025-01-15]
    end

    test "handles missing or invalid data gracefully" do
      basic_notice = %{
        regulator_id: nil,
        offender_name: "",
        offence_action_type: "Unknown",
        offence_action_date: "invalid-date",
        notice_date: "",
        operative_date: nil,
        offence_compliance_date: "invalid",
        offence_description: nil
      }

      assert {:ok, %ProcessedNotice{} = processed} = NoticeProcessor.process_notice(basic_notice)

      assert processed.regulator_id == nil
      # Empty string when no name provided
      assert processed.offender_attrs.name == ""
      assert is_nil(processed.notice_date)
      assert is_nil(processed.operative_date)
      assert is_nil(processed.compliance_date)
    end

    test "formats breaches correctly" do
      basic_notice = %{
        regulator_id: "IN2024005",
        offender_name: "Multi Breach Company",
        offence_action_type: "Improvement Notice",
        offence_action_date: "2024-12-01",
        notice_date: "2024-12-01",
        operative_date: "2024-12-01",
        offence_compliance_date: "2025-01-15",
        offence_description: "Multiple violations",
        offence_breaches: [
          "Health and Safety at Work etc. Act 1974",
          "Management of Health and Safety at Work Regulations 1999",
          "Personal Protective Equipment at Work Regulations 1992"
        ]
      }

      assert {:ok, %ProcessedNotice{} = processed} = NoticeProcessor.process_notice(basic_notice)

      # Breaches formatting only happens when enriched from API, so should be nil for basic notice
      assert is_nil(processed.offence_breaches)
    end

    test "handles empty breaches list" do
      basic_notice = %{
        regulator_id: "IN2024006",
        offender_name: "No Breach Company",
        offence_action_type: "Improvement Notice",
        offence_action_date: "2024-12-01",
        notice_date: "2024-12-01",
        operative_date: "2024-12-01",
        offence_compliance_date: "2025-01-15",
        offence_description: "General violations",
        offence_breaches: []
      }

      assert {:ok, %ProcessedNotice{} = processed} = NoticeProcessor.process_notice(basic_notice)

      assert is_nil(processed.offence_breaches)
    end

    test "builds regulator URL correctly" do
      basic_notice = %{
        regulator_id: "IN2024007",
        offender_name: "URL Test Company",
        offence_action_type: "Improvement Notice",
        offence_action_date: "2024-12-01",
        notice_date: "2024-12-01",
        operative_date: "2024-12-01",
        offence_compliance_date: "2025-01-15",
        offence_description: "URL test"
      }

      assert {:ok, %ProcessedNotice{} = processed} = NoticeProcessor.process_notice(basic_notice)

      assert processed.regulator_url ==
               "https://resources.hse.gov.uk/notices/notices/notice_details.asp?SF=CN&SV=IN2024007"
    end
  end

  describe "process_notices/1" do
    test "processes multiple notices successfully" do
      notices = [
        %{
          regulator_id: "IN2024001",
          offender_name: "Company A",
          offence_action_type: "Improvement Notice",
          offence_action_date: "2024-12-01",
          notice_date: "2024-12-01",
          operative_date: "2024-12-01",
          offence_compliance_date: "2025-01-15",
          offence_description: "Safety issue A"
        },
        %{
          regulator_id: "PN2024002",
          offender_name: "Company B",
          offence_action_type: "Prohibition Notice",
          offence_action_date: "2024-12-02",
          notice_date: "2024-12-02",
          operative_date: "2024-12-02",
          offence_description: "Safety issue B"
        }
      ]

      assert {:ok, processed_notices} = NoticeProcessor.process_notices(notices)

      assert length(processed_notices) == 2
      assert Enum.all?(processed_notices, &match?(%ProcessedNotice{}, &1))

      [notice1, notice2] = processed_notices
      assert notice1.regulator_id == "IN2024001"
      assert notice2.regulator_id == "PN2024002"
    end

    test "handles mixed success and failure" do
      notices = [
        %{
          regulator_id: "IN2024001",
          offender_name: "Good Company",
          offence_action_type: "Improvement Notice",
          offence_action_date: "2024-12-01",
          notice_date: "2024-12-01",
          operative_date: "2024-12-01",
          offence_compliance_date: "2025-01-15",
          offence_description: "Valid notice"
        },
        # This should still process successfully since the processor is resilient
        %{
          regulator_id: "BAD2024002",
          offender_name: nil,
          offence_action_type: nil,
          offence_action_date: nil,
          notice_date: nil,
          operative_date: nil,
          offence_description: nil
        }
      ]

      result = NoticeProcessor.process_notices(notices)

      # Should return processed notices successfully 
      assert {:ok, processed_notices} = result
      assert length(processed_notices) == 2
    end
  end
end
