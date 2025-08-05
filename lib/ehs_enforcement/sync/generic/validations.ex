defmodule EhsEnforcement.Sync.Generic.Validations do
  @moduledoc """
  Generic validation functions for sync resources.
  
  This module provides validation functions used by the generic sync resources
  to ensure data consistency and integrity. These validations are designed to
  be domain-agnostic and reusable across different applications.
  """

  @doc """
  Validates that a session_id follows the expected format.
  
  Session IDs should start with 'sync_' followed by alphanumeric characters.
  """
  def validate_session_id_format(changeset) do
    session_id = Ash.Changeset.get_attribute(changeset, :session_id)
    
    if session_id do
      if Regex.match?(~r/^sync_[a-zA-Z0-9_-]+$/, session_id) do
        changeset
      else
        Ash.Changeset.add_error(changeset, :session_id, "must start with 'sync_' followed by alphanumeric characters")
      end
    else
      changeset
    end
  end

  @doc """
  Validates that a target_resource follows the expected module name format.
  
  Target resource should be a valid Elixir module name.
  """
  def validate_target_resource_format(changeset) do
    target_resource = Ash.Changeset.get_attribute(changeset, :target_resource)
    
    if target_resource do
      if Regex.match?(~r/^[A-Z][a-zA-Z0-9_]*(\.[A-Z][a-zA-Z0-9_]*)*$/, target_resource) do
        changeset
      else
        Ash.Changeset.add_error(changeset, :target_resource, "must be a valid module name (e.g., 'MyApp.Resource')")
      end
    else
      changeset
    end
  end

  @doc """
  Validates that progress statistics are consistent and non-negative.
  
  Ensures that all progress fields are non-negative integers and that
  derived calculations make sense.
  """
  def validate_progress_consistency(changeset) do
    progress_stats = Ash.Changeset.get_attribute(changeset, :progress_stats)
    
    if progress_stats && is_map(progress_stats) do
      errors = []
      
      # Check that all numeric fields are non-negative
      numeric_fields = [:processed, :created, :updated, :existing, :errors, :failed]
      errors = Enum.reduce(numeric_fields, errors, fn field, acc ->
        case Map.get(progress_stats, field) do
          value when is_integer(value) and value < 0 ->
            ["#{field} cannot be negative" | acc]
          _ ->
            acc
        end
      end)
      
      # Check that processed >= sum of individual results (if all fields present)
      processed = Map.get(progress_stats, :processed, 0)
      created = Map.get(progress_stats, :created, 0)
      updated = Map.get(progress_stats, :updated, 0)
      existing = Map.get(progress_stats, :existing, 0)
      failed = Map.get(progress_stats, :errors, 0) || Map.get(progress_stats, :failed, 0)
      
      total_accounted = created + updated + existing + failed
      
      errors = if processed > 0 and total_accounted > processed do
        ["sum of results (#{total_accounted}) cannot exceed processed count (#{processed})" | errors]
      else
        errors
      end
      
      # Add errors to changeset
      Enum.reduce(errors, changeset, fn error, acc ->
        Ash.Changeset.add_error(acc, :progress_stats, error)
      end)
    else
      changeset
    end
  end

  @doc """
  Validates that batch statistics are consistent.
  
  Ensures that records_processed equals the sum of created, updated, existing, and failed.
  """
  def validate_batch_statistics_consistency(changeset) do
    processed = Ash.Changeset.get_attribute(changeset, :records_processed) || 0
    created = Ash.Changeset.get_attribute(changeset, :records_created) || 0
    updated = Ash.Changeset.get_attribute(changeset, :records_updated) || 0
    existing = Ash.Changeset.get_attribute(changeset, :records_existing) || 0
    failed = Ash.Changeset.get_attribute(changeset, :records_failed) || 0
    
    expected_total = created + updated + existing + failed
    
    if processed != expected_total do
      Ash.Changeset.add_error(
        changeset,
        :records_processed,
        "must equal sum of created (#{created}) + updated (#{updated}) + existing (#{existing}) + failed (#{failed}) = #{expected_total}, got #{processed}"
      )
    else
      changeset
    end
  end

  @doc """
  Validates that batch_size is consistent with source_ids count when provided.
  """
  def validate_batch_size_consistency(changeset) do
    batch_size = Ash.Changeset.get_attribute(changeset, :batch_size)
    source_ids = Ash.Changeset.get_attribute(changeset, :source_ids)
    
    if batch_size && source_ids && is_list(source_ids) do
      actual_count = length(source_ids)
      
      if batch_size != actual_count do
        Ash.Changeset.add_error(
          changeset,
          :batch_size,
          "batch_size (#{batch_size}) should match the number of source_ids (#{actual_count})"
        )
      else
        changeset
      end
    else
      changeset
    end
  end

  @doc """
  Validates that error_details are provided for error-level log entries.
  """
  def validate_error_details_for_error_level(changeset) do
    level = Ash.Changeset.get_attribute(changeset, :level)
    error_details = Ash.Changeset.get_attribute(changeset, :error_details)
    
    if level == :error and (is_nil(error_details) or error_details == %{}) do
      Ash.Changeset.add_error(
        changeset,
        :error_details,
        "error_details should be provided for error-level log entries"
      )
    else
      changeset
    end
  end

  @doc """
  Validates that log message length is appropriate.
  """
  def validate_message_length(changeset) do
    message = Ash.Changeset.get_attribute(changeset, :message)
    
    if message do
      length = String.length(message)
      
      cond do
        length < 5 ->
          Ash.Changeset.add_error(changeset, :message, "message should be at least 5 characters long")
        
        length > 2000 ->
          Ash.Changeset.add_error(changeset, :message, "message should not exceed 2000 characters")
        
        String.trim(message) == "" ->
          Ash.Changeset.add_error(changeset, :message, "message should not be empty or only whitespace")
        
        true ->
          changeset
      end
    else
      changeset
    end
  end

  @doc """
  Validates that a sync session is in a valid state transition.
  
  Ensures that status changes follow the allowed state machine transitions.
  """
  def validate_session_state_transition(changeset) do
    current_status = Ash.Changeset.get_data(changeset, :status)
    new_status = Ash.Changeset.get_attribute(changeset, :status)
    
    if current_status && new_status && current_status != new_status do
      if valid_status_transition?(current_status, new_status) do
        changeset
      else
        Ash.Changeset.add_error(
          changeset,
          :status,
          "invalid status transition from #{current_status} to #{new_status}"
        )
      end
    else
      changeset
    end
  end

  @doc """
  Validates that batch status transitions are valid.
  """
  def validate_batch_state_transition(changeset) do
    current_status = Ash.Changeset.get_data(changeset, :status)
    new_status = Ash.Changeset.get_attribute(changeset, :status)
    
    if current_status && new_status && current_status != new_status do
      if valid_batch_status_transition?(current_status, new_status) do
        changeset
      else
        Ash.Changeset.add_error(
          changeset,
          :status,
          "invalid batch status transition from #{current_status} to #{new_status}"
        )
      end
    else
      changeset
    end
  end

  # Private helper functions

  defp valid_status_transition?(current, new) do
    case {current, new} do
      # From pending
      {:pending, :running} -> true
      {:pending, :cancelled} -> true
      
      # From running
      {:running, :completed} -> true
      {:running, :failed} -> true
      {:running, :cancelled} -> true
      {:running, :paused} -> true
      
      # From paused
      {:paused, :running} -> true
      {:paused, :cancelled} -> true
      {:paused, :failed} -> true
      
      # From failed (allow retry)
      {:failed, :pending} -> true
      {:failed, :running} -> true
      
      # Other transitions are invalid
      _ -> false
    end
  end

  defp valid_batch_status_transition?(current, new) do
    case {current, new} do
      # From pending
      {:pending, :processing} -> true
      {:pending, :cancelled} -> true
      
      # From processing
      {:processing, :completed} -> true
      {:processing, :failed} -> true
      {:processing, :cancelled} -> true
      
      # From failed (allow retry)
      {:failed, :retrying} -> true
      {:failed, :cancelled} -> true
      
      # From retrying
      {:retrying, :completed} -> true
      {:retrying, :failed} -> true
      {:retrying, :cancelled} -> true
      
      # Other transitions are invalid
      _ -> false
    end
  end
end