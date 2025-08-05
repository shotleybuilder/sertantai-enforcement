defmodule EhsEnforcement.Sync.RecordProcessor do
  @moduledoc """
  Enhanced record processing for sync operations with detailed status tracking.
  
  This module provides create/update/exists detection and reporting for sync operations,
  designed to be package-ready for future extraction as `airtable_sync_phoenix`.
  """
  
  alias EhsEnforcement.Enforcement
  alias EhsEnforcement.Sync.EventBroadcaster
  require Ash.Query
  require Logger

  @doc """
  Process a single case record with enhanced status tracking.
  
  Returns detailed status information:
  - `{:created, case}` - New case was created
  - `{:updated, case}` - Existing case was updated
  - `{:exists, case}` - Case already exists with same data (no update needed)
  - `{:error, reason}` - Processing failed
  
  ## Options
  
  * `:actor` - The user performing the operation (for authorization)
  * `:session_id` - Optional session ID for event broadcasting
  * `:force_update` - Force update even if data is identical (default: false)
  """
  def process_case_record(record, opts \\ []) do
    fields = record["fields"] || %{}
    regulator_id = to_string(fields["regulator_id"])
    actor = Keyword.get(opts, :actor)
    session_id = Keyword.get(opts, :session_id)
    force_update = Keyword.get(opts, :force_update, false)
    
    attrs = build_case_attrs(fields)
    
    # Try to find existing case by regulator_id
    case find_existing_case(regulator_id) do
      {:ok, nil} ->
        # No existing case - create new one
        case Enforcement.create_case(attrs, actor: actor) do
          {:ok, case_record} ->
            broadcast_record_event(:record_created, case_record, :case, session_id)
            Logger.debug("✅ Created new case: #{regulator_id}")
            {:created, case_record}
            
          {:error, error} ->
            broadcast_record_event(:record_error, %{regulator_id: regulator_id, error: error}, :case, session_id)
            Logger.error("❌ Failed to create case #{regulator_id}: #{inspect(error)}")
            {:error, error}
        end
        
      {:ok, existing_case} ->
        # Build update attributes with only fields accepted by :sync_from_airtable action
        update_attrs = build_case_update_attrs(fields)
        
        # Case exists - check if update is needed
        if needs_update?(existing_case, update_attrs) || force_update do
          case Enforcement.sync_case_from_airtable(existing_case, update_attrs, actor: actor) do
            {:ok, updated_case} ->
              broadcast_record_event(:record_updated, updated_case, :case, session_id)
              Logger.debug("🔄 Updated existing case: #{regulator_id}")
              {:updated, updated_case}
              
            {:error, error} ->
              broadcast_record_event(:record_error, %{regulator_id: regulator_id, error: error}, :case, session_id)
              Logger.error("❌ Failed to update case #{regulator_id}: #{inspect(error)}")
              {:error, error}
          end
        else
          # Case exists and no update needed
          broadcast_record_event(:record_exists, existing_case, :case, session_id)
          Logger.debug("⏭️ Case already exists with same data: #{regulator_id}")
          {:exists, existing_case}
        end
        
      {:error, error} ->
        Logger.error("❌ Error finding existing case #{regulator_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  @doc """
  Process a single notice record with enhanced status tracking.
  
  Returns detailed status information:
  - `{:created, notice}` - New notice was created
  - `{:updated, notice}` - Existing notice was updated
  - `{:exists, notice}` - Notice already exists with same data (no update needed)
  - `{:error, reason}` - Processing failed
  """
  def process_notice_record(record, opts \\ []) do
    fields = record["fields"] || %{}
    regulator_id = to_string(fields["regulator_id"])
    actor = Keyword.get(opts, :actor)
    session_id = Keyword.get(opts, :session_id)
    force_update = Keyword.get(opts, :force_update, false)
    
    attrs = build_notice_attrs(fields)
    
    # Try to find existing notice by regulator_id
    case find_existing_notice(regulator_id) do
      {:ok, nil} ->
        # No existing notice - create new one
        case Enforcement.create_notice(attrs, actor: actor) do
          {:ok, notice_record} ->
            broadcast_record_event(:record_created, notice_record, :notice, session_id)
            Logger.debug("✅ Created new notice: #{regulator_id}")
            {:created, notice_record}
            
          {:error, error} ->
            broadcast_record_event(:record_error, %{regulator_id: regulator_id, error: error}, :notice, session_id)
            Logger.error("❌ Failed to create notice #{regulator_id}: #{inspect(error)}")
            {:error, error}
        end
        
      {:ok, existing_notice} ->
        # Notice exists - check if update is needed
        if needs_update?(existing_notice, attrs) || force_update do
          case Enforcement.update_notice(existing_notice, attrs, actor: actor) do
            {:ok, updated_notice} ->
              broadcast_record_event(:record_updated, updated_notice, :notice, session_id)
              Logger.debug("🔄 Updated existing notice: #{regulator_id}")
              {:updated, updated_notice}
              
            {:error, error} ->
              broadcast_record_event(:record_error, %{regulator_id: regulator_id, error: error}, :notice, session_id)
              Logger.error("❌ Failed to update notice #{regulator_id}: #{inspect(error)}")
              {:error, error}
          end
        else
          # Notice exists and no update needed
          broadcast_record_event(:record_exists, existing_notice, :notice, session_id)
          Logger.debug("⏭️ Notice already exists with same data: #{regulator_id}")
          {:exists, existing_notice}
        end
        
      {:error, error} ->
        Logger.error("❌ Error finding existing notice #{regulator_id}: #{inspect(error)}")
        {:error, error}
    end
  end

  # Private helper functions

  defp find_existing_case(regulator_id) do
    # Use Ash.Query to build a proper filter
    query = EhsEnforcement.Enforcement.Case
    |> Ash.Query.filter(regulator_id == ^regulator_id)
    |> Ash.Query.limit(1)
    
    case Ash.read(query) do
      {:ok, []} -> {:ok, nil}
      {:ok, [case | _]} -> {:ok, case}
      {:error, error} -> {:error, error}
    end
  end

  defp find_existing_notice(regulator_id) do
    # Use Ash.Query to build a proper filter
    query = EhsEnforcement.Enforcement.Notice
    |> Ash.Query.filter(regulator_id == ^regulator_id)
    |> Ash.Query.limit(1)
    
    case Ash.read(query) do
      {:ok, []} -> {:ok, nil}
      {:ok, [notice | _]} -> {:ok, notice}
      {:error, error} -> {:error, error}
    end
  end

  defp needs_update?(existing_record, new_attrs) do
    # Compare key fields to determine if update is needed
    # For cases, only compare fields that can be updated via :sync_from_airtable action
    
    significant_fields = case existing_record.__struct__ do
      EhsEnforcement.Enforcement.Case ->
        # Only fields that :sync_from_airtable action accepts
        [:offence_result, :offence_fine, :offence_costs, :offence_hearing_date, :url, :related_cases]
      EhsEnforcement.Enforcement.Notice ->
        [:notice_date, :operative_date, :compliance_date, :notice_body, :offence_breaches]
      _ ->
        []
    end
    
    Enum.any?(significant_fields, fn field ->
      existing_value = Map.get(existing_record, field)
      new_value = Map.get(new_attrs, field)
      
      # Handle different data types and nil values
      normalize_value(existing_value) != normalize_value(new_value)
    end)
  end

  defp normalize_value(nil), do: nil
  defp normalize_value(value) when is_binary(value), do: String.trim(value)
  defp normalize_value(%Decimal{} = decimal), do: Decimal.to_string(decimal)
  defp normalize_value(%Date{} = date), do: Date.to_string(date)
  defp normalize_value(value), do: value

  defp build_case_attrs(fields) do
    %{
      agency_code: String.to_atom(fields["agency_code"] || "hse"),
      regulator_id: to_string(fields["regulator_id"]),
      offender_attrs: %{
        name: fields["offender_name"],
        postcode: fields["offender_postcode"],
        local_authority: fields["offender_local_authority"],
        main_activity: fields["offender_main_activity"]
      },
      offence_action_type: fields["offence_action_type"],
      offence_action_date: parse_date(fields["offence_action_date"]),
      offence_hearing_date: parse_date(fields["offence_hearing_date"]),
      offence_result: fields["offence_result"],
      offence_fine: parse_decimal(fields["offence_fine"]),
      offence_costs: parse_decimal(fields["offence_costs"]),
      offence_breaches: fields["offence_breaches"],
      offence_breaches_clean: fields["offence_breaches_clean"],
      regulator_function: fields["regulator_function"],
      regulator_url: fields["regulator_url"],
      related_cases: fields["related_cases"]
    }
  end

  defp build_case_update_attrs(fields) do
    # Only fields accepted by :sync_from_airtable action
    %{
      offence_result: fields["offence_result"],
      offence_fine: parse_decimal(fields["offence_fine"]),
      offence_costs: parse_decimal(fields["offence_costs"]),
      offence_hearing_date: parse_date(fields["offence_hearing_date"]),
      url: fields["regulator_url"],
      related_cases: fields["related_cases"]
    }
  end

  defp build_notice_attrs(fields) do
    %{
      agency_code: String.to_atom(fields["agency_code"] || "hse"),
      regulator_id: to_string(fields["regulator_id"]),
      offender_attrs: %{
        name: fields["offender_name"],
        postcode: fields["offender_postcode"],
        local_authority: fields["offender_local_authority"],
        main_activity: fields["offender_main_activity"]
      },
      offence_action_type: fields["offence_action_type"],
      offence_action_date: parse_date(fields["offence_action_date"]),
      notice_date: parse_date(fields["notice_date"]),
      operative_date: parse_date(fields["operative_date"]),
      compliance_date: parse_date(fields["compliance_date"]),
      notice_body: fields["notice_body"],
      offence_breaches: fields["offence_breaches"]
    }
  end

  defp parse_date(nil), do: nil
  defp parse_date(date_string) when is_binary(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      _ -> nil
    end
  end
  defp parse_date(_), do: nil

  defp parse_decimal(nil), do: nil
  defp parse_decimal(value) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, _} -> decimal
      _ -> nil
    end
  end
  defp parse_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp parse_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp parse_decimal(_), do: nil

  defp broadcast_record_event(event_type, record_data, resource_type, session_id) do
    event_data = %{
      resource_type: resource_type,
      record_data: record_data,
      session_id: session_id,
      timestamp: DateTime.utc_now()
    }
    
    EventBroadcaster.broadcast(event_type, event_data, topic: "sync_records")
  end
end