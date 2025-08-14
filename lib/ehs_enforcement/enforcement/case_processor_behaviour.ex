defmodule EhsEnforcement.Enforcement.CaseProcessorBehaviour do
  @moduledoc """
  Unified behavior for processing enforcement cases from different agencies.
  
  This behavior defines a standard interface for creating, updating, or returning
  existing cases based on scraped data, ensuring consistent UI status display
  across all agencies.
  
  The key insight is that UI status should be based on case timestamps:
  - "Created": inserted_at is today
  - "Updated": updated_at is today (but inserted_at is not today)  
  - "Exists": neither inserted_at nor updated_at is today
  """
  
  @type case_status :: :created | :updated | :existing
  @type processed_case :: any()
  @type case_record :: any()
  @type actor :: any()
  
  @doc """
  Process and save a case, returning the appropriate status for UI display.
  
  Returns:
  - `{:ok, case_record, :created}` - New case was created today
  - `{:ok, case_record, :updated}` - Existing case was updated today with new data
  - `{:ok, case_record, :existing}` - Existing case with identical data (no update needed)
  - `{:error, reason}` - Case processing failed
  """
  @callback process_and_create_case_with_status(processed_case, actor) :: 
    {:ok, case_record, case_status} | {:error, any()}
end