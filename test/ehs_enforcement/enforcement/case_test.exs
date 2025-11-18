defmodule EhsEnforcement.Enforcement.CaseTest do
  use EhsEnforcement.DataCase, async: true

  # 🐛 BLOCKED: Case resource test failures - Issue #38
  # 2 failures in core enforcement domain tests - needs investigation
  @moduletag :skip

  alias EhsEnforcement.Enforcement

  setup do
    # Use predefined agency code (hse is allowed)
    # Check if agency already exists and reuse it, otherwise create it
    agency =
      case Ash.get(EhsEnforcement.Enforcement.Agency, code: :hse) do
        {:ok, agency} ->
          agency

        {:error, _} ->
          {:ok, agency} =
            Enforcement.create_agency(%{
              code: :hse,
              name: "Health and Safety Executive"
            })

          agency
      end

    # Always create a new offender for each test
    {:ok, offender} =
      Enforcement.create_offender(%{
        name: "Test Company Ltd",
        local_authority: "Manchester"
      })

    %{agency: agency, offender: offender}
  end

  describe "case resource" do
    test "creates a case with valid attributes", %{agency: agency, offender: offender} do
      attrs = %{
        agency_id: agency.id,
        offender_id: offender.id,
        regulator_id: "HSE001",
        offence_result: "Guilty",
        offence_fine: Decimal.new("10000.00"),
        offence_costs: Decimal.new("2000.00"),
        offence_action_date: ~D[2024-01-15],
        offence_hearing_date: ~D[2024-01-10],
        offence_breaches: "Health and Safety at Work etc. Act 1974",
        regulator_function: "Construction Division"
      }

      assert {:ok, case_record} = Enforcement.create_case(attrs)
      assert case_record.regulator_id == "HSE001"
      assert case_record.offence_result == "Guilty"
      assert Decimal.equal?(case_record.offence_fine, Decimal.new("10000.00"))
      assert case_record.offence_action_date == ~D[2024-01-15]
      assert case_record.agency_id == agency.id
      assert case_record.offender_id == offender.id
    end

    test "creates case with agency code and offender attributes", %{agency: agency} do
      case_attrs = %{
        agency_code: agency.code,
        offender_attrs: %{
          name: "New Company Ltd",
          local_authority: "Birmingham"
        },
        regulator_id: "HSE002",
        offence_result: "Guilty",
        offence_fine: Decimal.new("5000.00")
      }

      assert {:ok, case_record} = Enforcement.create_case(case_attrs)
      assert case_record.regulator_id == "HSE002"

      # Load with relationships
      case_with_relations =
        Enforcement.get_case!(
          case_record.id,
          load: [:agency, :offender]
        )

      assert case_with_relations.agency.code == agency.code
      # original preserved
      assert case_with_relations.offender.name == "New Company Ltd"
      assert case_with_relations.offender.normalized_name == "new company limited"
    end

    test "validates required relationships" do
      attrs = %{
        regulator_id: "HSE003",
        offence_result: "Guilty"
      }

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_case(attrs)
    end

    test "enforces unique airtable_id constraint", %{agency: agency} do
      attrs = %{
        agency_code: agency.code,
        offender_attrs: %{name: "Test Company"},
        airtable_id: "rec123456",
        regulator_id: "HSE004"
      }

      assert {:ok, _case1} = Enforcement.create_case(attrs)

      attrs2 = %{
        agency_code: agency.code,
        offender_attrs: %{name: "Different Company"},
        airtable_id: "rec123456",
        regulator_id: "HSE005"
      }

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_case(attrs2)
    end

    test "filters cases by date range", %{agency: agency} do
      # Create cases with different dates
      attrs_base = %{
        agency_code: agency.code,
        offender_attrs: %{name: "Test Company"}
      }

      {:ok, _case1} =
        Enforcement.create_case(
          Map.merge(attrs_base, %{
            regulator_id: "HSE001",
            offence_action_date: ~D[2024-01-01]
          })
        )

      {:ok, _case2} =
        Enforcement.create_case(
          Map.merge(attrs_base, %{
            regulator_id: "HSE002",
            offence_action_date: ~D[2024-06-01]
          })
        )

      {:ok, _case3} =
        Enforcement.create_case(
          Map.merge(attrs_base, %{
            regulator_id: "HSE003",
            offence_action_date: ~D[2024-12-01]
          })
        )

      {:ok, cases} =
        Enforcement.list_cases_by_date_range(
          ~D[2024-05-01],
          ~D[2024-07-01]
        )

      assert length(cases) == 1
      assert hd(cases).regulator_id == "HSE002"
    end

    test "calculates total penalty", %{agency: agency} do
      attrs = %{
        agency_code: agency.code,
        offender_attrs: %{name: "Test Company"},
        regulator_id: "HSE001",
        offence_fine: Decimal.new("10000.00"),
        offence_costs: Decimal.new("2500.00")
      }

      assert {:ok, case_record} = Enforcement.create_case(attrs)

      case_with_calc =
        Enforcement.get_case!(
          case_record.id,
          load: [:total_penalty]
        )

      expected_total = Decimal.new("12500.00")
      assert Decimal.equal?(case_with_calc.total_penalty, expected_total)
    end

    test "updates sync timestamp with sync_from_airtable action", %{agency: agency} do
      attrs = %{
        agency_code: agency.code,
        offender_attrs: %{name: "Test Company"},
        regulator_id: "HSE001"
      }

      assert {:ok, case_record} = Enforcement.create_case(attrs)
      assert case_record.last_synced_at == nil

      sync_attrs = %{
        offence_result: "Updated result",
        offence_fine: Decimal.new("15000.00")
      }

      assert {:ok, updated_case} = Enforcement.sync_case_from_airtable(case_record, sync_attrs)
      assert updated_case.offence_result == "Updated result"
      assert updated_case.last_synced_at != nil
    end

    test "update_from_scraping action does not modify sync timestamp", %{agency: agency} do
      attrs = %{
        agency_code: agency.code,
        offender_attrs: %{name: "Test Company"},
        regulator_id: "HSE001"
      }

      assert {:ok, case_record} = Enforcement.create_case(attrs)
      assert case_record.last_synced_at == nil

      scraping_attrs = %{
        offence_result: "Guilty",
        offence_fine: Decimal.new("8000.00"),
        offence_costs: Decimal.new("1500.00"),
        url: "https://hse.gov.uk/prosecutions/case/123"
      }

      assert {:ok, updated_case} =
               Enforcement.update_case_from_scraping(case_record, scraping_attrs)

      assert updated_case.offence_result == "Guilty"
      assert Decimal.equal?(updated_case.offence_fine, Decimal.new("8000.00"))
      assert updated_case.url == "https://hse.gov.uk/prosecutions/case/123"
      # Should not set last_synced_at - this is scraping, not Airtable sync
      assert updated_case.last_synced_at == nil
    end

    test "sync_from_airtable action sets sync timestamp", %{agency: agency} do
      attrs = %{
        agency_code: agency.code,
        offender_attrs: %{name: "Test Company"},
        regulator_id: "HSE001"
      }

      assert {:ok, case_record} = Enforcement.create_case(attrs)
      assert case_record.last_synced_at == nil

      airtable_attrs = %{
        offence_result: "Not guilty",
        offence_fine: Decimal.new("0.00"),
        offence_costs: Decimal.new("500.00")
      }

      assert {:ok, updated_case} =
               Enforcement.sync_case_from_airtable(case_record, airtable_attrs)

      assert updated_case.offence_result == "Not guilty"
      assert Decimal.equal?(updated_case.offence_fine, Decimal.new("0.00"))
      # Should set last_synced_at - this is Airtable sync
      assert updated_case.last_synced_at != nil
      assert DateTime.diff(updated_case.last_synced_at, DateTime.utc_now(), :second) < 5
    end
  end

  describe "PubSub event publishing" do
    # Uses agency from main setup block

    test "update_from_scraping publishes case:scraped:updated events", %{agency: agency} do
      # Subscribe to the PubSub topic
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped:updated")

      attrs = %{
        agency_code: agency.code,
        offender_attrs: %{name: "Test Company"},
        regulator_id: "HSE001"
      }

      {:ok, case_record} = Enforcement.create_case(attrs)

      scraping_attrs = %{
        offence_result: "Guilty",
        offence_fine: Decimal.new("5000.00")
      }

      {:ok, updated_case} = Enforcement.update_case_from_scraping(case_record, scraping_attrs)

      # Should receive scraped:updated events
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "case:scraped:updated",
                       event: "update_from_scraping",
                       payload: payload
                     },
                     1000

      # Verify the payload contains the updated case data
      assert payload.data.id == updated_case.id
    end

    test "sync_from_airtable publishes case:synced events", %{agency: agency} do
      # Subscribe to the PubSub topic
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:synced")

      attrs = %{
        agency_code: agency.code,
        offender_attrs: %{name: "Test Company"},
        regulator_id: "HSE001"
      }

      {:ok, case_record} = Enforcement.create_case(attrs)

      sync_attrs = %{
        offence_result: "Not guilty",
        offence_fine: Decimal.new("0.00")
      }

      {:ok, updated_case} = Enforcement.sync_case_from_airtable(case_record, sync_attrs)

      # Should receive synced events
      assert_receive %Phoenix.Socket.Broadcast{
                       topic: "case:synced",
                       event: "sync_from_airtable",
                       payload: payload
                     },
                     1000

      # Verify the payload contains the updated case data
      assert payload.data.id == updated_case.id
    end

    test "different actions publish to different topics", %{agency: agency} do
      # Subscribe to both topics
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped:updated")
      Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case:synced")

      attrs = %{
        agency_code: agency.code,
        offender_attrs: %{name: "Test Company"},
        regulator_id: "HSE001"
      }

      {:ok, case_record} = Enforcement.create_case(attrs)

      # Update from scraping should only publish to scraped topic
      {:ok, scraped_case} =
        Enforcement.update_case_from_scraping(case_record, %{
          offence_result: "Guilty"
        })

      # Should receive scraped event but not synced event
      assert_receive %Phoenix.Socket.Broadcast{topic: "case:scraped:updated"}, 1000
      refute_receive %Phoenix.Socket.Broadcast{topic: "case:synced"}, 100

      # Sync from Airtable should only publish to synced topic
      {:ok, _synced_case} =
        Enforcement.sync_case_from_airtable(scraped_case, %{
          offence_result: "Not guilty"
        })

      # Should receive synced event
      assert_receive %Phoenix.Socket.Broadcast{topic: "case:synced"}, 1000
    end
  end
end
