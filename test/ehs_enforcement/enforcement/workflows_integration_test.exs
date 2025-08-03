defmodule EhsEnforcement.Enforcement.WorkflowsIntegrationTest do
  @moduledoc """
  Integration tests for the separated scraping vs syncing workflows.
  
  This test suite validates that the clean separation implemented in case-pubsub-4
  works correctly and maintains the distinction between:
  
  1. Scraping workflow (HSE website → Postgres)
  2. Syncing workflow (Airtable → Postgres)
  
  Key validation points:
  - Different PubSub topics for each workflow
  - Different timestamp behavior (last_synced_at)
  - Correct action usage in each context
  - No cross-contamination between workflows
  """
  
  use EhsEnforcement.DataCase, async: true
  
  alias EhsEnforcement.Enforcement
  alias Phoenix.PubSub
  
  setup do
    # Use predefined agency code (hse is allowed)
    agency = case Ash.get(EhsEnforcement.Enforcement.Agency, code: :hse) do
      {:ok, agency} -> 
        agency
      {:error, _} ->
        {:ok, agency} = Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive"
        })
        agency
    end

    {:ok, test_case} = Enforcement.create_case(%{
      agency_code: :hse,
      offender_attrs: %{name: "Integration Test Company"},
      regulator_id: "INT_001",
      offence_result: "Under investigation"
    })

    %{agency: agency, test_case: test_case}
  end

  describe "scraping workflow (HSE website → Postgres)" do
    test "uses update_from_scraping action with correct PubSub topic", %{test_case: test_case} do
      # Subscribe to scraping events
      PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped:updated")
      
      # Should NOT receive sync events
      PubSub.subscribe(EhsEnforcement.PubSub, "case:synced")

      scraping_data = %{
        offence_result: "Guilty",
        offence_fine: Decimal.new("15000.00"),
        offence_costs: Decimal.new("3000.00"),
        offence_hearing_date: ~D[2024-06-15],
        url: "https://hse.gov.uk/prosecutions/case/int_001"
      }

      # Execute scraping workflow
      {:ok, updated_case} = Enforcement.update_case_from_scraping(test_case, scraping_data)

      # Verify case data updated correctly
      assert updated_case.offence_result == "Guilty"
      assert Decimal.equal?(updated_case.offence_fine, Decimal.new("15000.00"))
      assert updated_case.url == "https://hse.gov.uk/prosecutions/case/int_001"
      
      # Critical: Should NOT update sync timestamp (this is scraping, not Airtable sync)
      assert updated_case.last_synced_at == nil

      # Verify correct PubSub events
      assert_receive %Phoenix.Socket.Broadcast{
        topic: "case:scraped:updated",
        event: "update_from_scraping",
        payload: ^updated_case
      }, 1000

      # Should NOT receive sync events
      refute_receive %Phoenix.Socket.Broadcast{topic: "case:synced"}, 100
    end

    test "scraping workflow handles multiple updates correctly", %{test_case: test_case} do
      PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped:updated")

      # First scraping update
      {:ok, updated_case_1} = Enforcement.update_case_from_scraping(test_case, %{
        offence_result: "Guilty"
      })

      # Second scraping update
      {:ok, updated_case_2} = Enforcement.update_case_from_scraping(updated_case_1, %{
        offence_fine: Decimal.new("8000.00")
      })

      # Both should preserve no sync timestamp
      assert updated_case_1.last_synced_at == nil
      assert updated_case_2.last_synced_at == nil

      # Should receive two scraping events
      assert_receive %Phoenix.Socket.Broadcast{topic: "case:scraped:updated"}, 1000
      assert_receive %Phoenix.Socket.Broadcast{topic: "case:scraped:updated"}, 1000
    end
  end

  describe "syncing workflow (Airtable → Postgres)" do
    test "uses sync_from_airtable action with correct PubSub topic", %{test_case: test_case} do
      # Subscribe to sync events
      PubSub.subscribe(EhsEnforcement.PubSub, "case:synced")
      
      # Should NOT receive scraping events
      PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped:updated")

      airtable_data = %{
        offence_result: "Not guilty",
        offence_fine: Decimal.new("0.00"),
        offence_costs: Decimal.new("2500.00"),
        offence_hearing_date: ~D[2024-07-20]
      }

      # Execute Airtable sync workflow
      {:ok, synced_case} = Enforcement.sync_case_from_airtable(test_case, airtable_data)

      # Verify case data updated correctly
      assert synced_case.offence_result == "Not guilty"
      assert Decimal.equal?(synced_case.offence_fine, Decimal.new("0.00"))
      
      # Critical: Should update sync timestamp (this is Airtable sync)
      assert synced_case.last_synced_at != nil
      assert DateTime.diff(synced_case.last_synced_at, DateTime.utc_now(), :second) < 5

      # Verify correct PubSub events
      assert_receive %Phoenix.Socket.Broadcast{
        topic: "case:synced",
        event: "sync_from_airtable",
        payload: ^synced_case
      }, 1000

      # Should NOT receive scraping events
      refute_receive %Phoenix.Socket.Broadcast{topic: "case:scraped:updated"}, 100
    end

    test "syncing workflow updates timestamps on every sync", %{test_case: test_case} do
      # First sync
      {:ok, synced_case_1} = Enforcement.sync_case_from_airtable(test_case, %{
        offence_result: "Not guilty"
      })

      first_sync_time = synced_case_1.last_synced_at
      assert first_sync_time != nil

      # Wait a moment to ensure timestamp difference
      Process.sleep(10)

      # Second sync
      {:ok, synced_case_2} = Enforcement.sync_case_from_airtable(synced_case_1, %{
        offence_fine: Decimal.new("1000.00")
      })

      second_sync_time = synced_case_2.last_synced_at
      assert second_sync_time != nil
      assert DateTime.compare(second_sync_time, first_sync_time) == :gt
    end
  end

  describe "workflow separation and independence" do
    test "scraping and syncing workflows can be used independently", %{test_case: test_case} do
      PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped:updated")
      PubSub.subscribe(EhsEnforcement.PubSub, "case:synced")

      # Start with scraping
      {:ok, scraped_case} = Enforcement.update_case_from_scraping(test_case, %{
        offence_result: "Guilty",
        url: "https://hse.gov.uk/prosecutions/case/workflow_001"
      })

      # Verify scraping results
      assert scraped_case.offence_result == "Guilty"
      assert scraped_case.url == "https://hse.gov.uk/prosecutions/case/workflow_001"
      assert scraped_case.last_synced_at == nil

      # Then sync from Airtable (different data, simulating real workflow)
      {:ok, synced_case} = Enforcement.sync_case_from_airtable(scraped_case, %{
        offence_result: "Guilty", # Confirm from Airtable
        offence_fine: Decimal.new("12000.00") # Additional data from Airtable
      })

      # Verify sync results build on scraping results
      assert synced_case.offence_result == "Guilty"
      assert synced_case.url == "https://hse.gov.uk/prosecutions/case/workflow_001" # Preserved from scraping
      assert Decimal.equal?(synced_case.offence_fine, Decimal.new("12000.00")) # Added from sync
      assert synced_case.last_synced_at != nil # Sync timestamp set

      # Verify both event types received
      assert_receive %Phoenix.Socket.Broadcast{topic: "case:scraped:updated"}, 1000
      assert_receive %Phoenix.Socket.Broadcast{topic: "case:synced"}, 1000
    end

    test "workflows can happen in any order without interference", %{test_case: test_case} do
      # Start with Airtable sync first
      {:ok, synced_case} = Enforcement.sync_case_from_airtable(test_case, %{
        offence_result: "Not guilty",
        offence_fine: Decimal.new("0.00")
      })

      sync_timestamp = synced_case.last_synced_at
      assert sync_timestamp != nil

      # Then scrape (simulating finding more details later)
      {:ok, scraped_case} = Enforcement.update_case_from_scraping(synced_case, %{
        offence_costs: Decimal.new("1500.00"),
        url: "https://hse.gov.uk/prosecutions/case/reverse_001"
      })

      # Verify scraping preserves sync data but doesn't modify sync timestamp
      assert scraped_case.offence_result == "Not guilty" # Preserved from sync
      assert Decimal.equal?(scraped_case.offence_fine, Decimal.new("0.00")) # Preserved from sync
      assert Decimal.equal?(scraped_case.offence_costs, Decimal.new("1500.00")) # Added from scraping
      assert scraped_case.url == "https://hse.gov.uk/prosecutions/case/reverse_001" # Added from scraping
      assert scraped_case.last_synced_at == sync_timestamp # Unchanged by scraping
    end

    test "events are properly namespaced to prevent confusion", %{test_case: test_case} do
      # Set up event collection
      events = []
      
      PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped:updated")
      PubSub.subscribe(EhsEnforcement.PubSub, "case:synced")

      # Perform multiple operations
      {:ok, scraped_case} = Enforcement.update_case_from_scraping(test_case, %{
        offence_result: "Guilty"
      })

      {:ok, synced_case} = Enforcement.sync_case_from_airtable(scraped_case, %{
        offence_fine: Decimal.new("5000.00")
      })

      {:ok, _scraped_again} = Enforcement.update_case_from_scraping(synced_case, %{
        url: "https://hse.gov.uk/prosecutions/case/namespace_001"
      })

      # Verify event sequence and topics
      assert_receive %Phoenix.Socket.Broadcast{
        topic: "case:scraped:updated",
        event: "update_from_scraping"
      }, 1000

      assert_receive %Phoenix.Socket.Broadcast{
        topic: "case:synced",
        event: "sync_from_airtable"
      }, 1000

      assert_receive %Phoenix.Socket.Broadcast{
        topic: "case:scraped:updated",
        event: "update_from_scraping"
      }, 1000

      # No unexpected events
      refute_receive %Phoenix.Socket.Broadcast{}, 100
    end
  end

  describe "real-world workflow scenarios" do
    test "typical scraping session followed by Airtable migration", %{test_case: test_case} do
      # Simulate a scraping session finding and updating cases
      {:ok, scraped_case} = Enforcement.update_case_from_scraping(test_case, %{
        offence_result: "Guilty",
        offence_fine: Decimal.new("25000.00"),
        offence_costs: Decimal.new("5000.00"),
        offence_hearing_date: ~D[2024-08-01],
        url: "https://hse.gov.uk/prosecutions/case/real_world_001"
      })

      # Case found during scraping - no sync timestamp
      assert scraped_case.last_synced_at == nil
      assert scraped_case.url != nil

      # Later: 30K record Airtable migration runs
      {:ok, migrated_case} = Enforcement.sync_case_from_airtable(scraped_case, %{
        # Airtable data might have additional or corrected information
        offence_result: "Guilty", # Confirmed
        offence_fine: Decimal.new("25000.00"), # Confirmed
        offence_costs: Decimal.new("4800.00"), # Slightly different (official record)
        offence_breaches: "Health and Safety at Work etc. Act 1974 Section 2(1)"
      })

      # Verify final state combines both sources
      assert migrated_case.offence_result == "Guilty"
      assert Decimal.equal?(migrated_case.offence_fine, Decimal.new("25000.00"))
      assert Decimal.equal?(migrated_case.offence_costs, Decimal.new("4800.00")) # Airtable wins
      assert migrated_case.url == "https://hse.gov.uk/prosecutions/case/real_world_001" # Preserved from scraping
      assert migrated_case.offence_breaches != nil # Added from Airtable
      assert migrated_case.last_synced_at != nil # Migration timestamp
    end

    test "handles concurrent updates gracefully", %{test_case: test_case} do
      # This simulates what might happen if scraping and syncing run simultaneously
      
      # Scraping finds case details
      {:ok, scraped_case} = Enforcement.update_case_from_scraping(test_case, %{
        offence_result: "Guilty",
        url: "https://hse.gov.uk/prosecutions/case/concurrent_001"
      })

      # Airtable sync also updates the same case (different fields)
      {:ok, synced_case} = Enforcement.sync_case_from_airtable(scraped_case, %{
        offence_fine: Decimal.new("7500.00"),
        offence_breaches: "Multiple violations"
      })

      # Another scraping update (perhaps different page)
      {:ok, final_case} = Enforcement.update_case_from_scraping(synced_case, %{
        offence_costs: Decimal.new("2000.00"),
        related_cases: "Related to case HSE_002"
      })

      # Final state should have data from all sources
      assert final_case.offence_result == "Guilty" # From first scraping
      assert final_case.url == "https://hse.gov.uk/prosecutions/case/concurrent_001" # From first scraping
      assert Decimal.equal?(final_case.offence_fine, Decimal.new("7500.00")) # From Airtable sync
      assert final_case.offence_breaches == "Multiple violations" # From Airtable sync
      assert Decimal.equal?(final_case.offence_costs, Decimal.new("2000.00")) # From second scraping
      assert final_case.related_cases == "Related to case HSE_002" # From second scraping
      
      # Sync timestamp should be preserved from Airtable sync (not modified by scraping)
      assert final_case.last_synced_at != nil
    end
  end

  describe "edge cases and error handling" do
    test "invalid data in scraping workflow", %{test_case: test_case} do
      invalid_scraping_data = %{
        offence_fine: "not_a_number",
        url: "invalid_url_format"
      }

      # Should handle validation errors gracefully
      assert {:error, %Ash.Error.Invalid{}} = 
        Enforcement.update_case_from_scraping(test_case, invalid_scraping_data)

      # Original case should be unchanged
      unchanged_case = Enforcement.get_case!(test_case.id)
      assert unchanged_case.offence_fine == test_case.offence_fine
      assert unchanged_case.last_synced_at == test_case.last_synced_at
    end

    test "invalid data in syncing workflow", %{test_case: test_case} do
      invalid_sync_data = %{
        offence_fine: -1000, # Negative fine
        offence_hearing_date: "invalid_date"
      }

      # Should handle validation errors gracefully
      assert {:error, %Ash.Error.Invalid{}} = 
        Enforcement.sync_case_from_airtable(test_case, invalid_sync_data)

      # Original case should be unchanged
      unchanged_case = Enforcement.get_case!(test_case.id)
      assert unchanged_case.last_synced_at == test_case.last_synced_at
    end

    test "missing case for update workflows" do
      # Try to update a non-existent case
      fake_case = %EhsEnforcement.Enforcement.Case{id: "non_existent"}

      assert {:error, %Ash.Error.Invalid{}} = 
        Enforcement.update_case_from_scraping(fake_case, %{offence_result: "Guilty"})

      assert {:error, %Ash.Error.Invalid{}} = 
        Enforcement.sync_case_from_airtable(fake_case, %{offence_result: "Guilty"})
    end
  end
end