defmodule EhsEnforcement.Sync.Generic.RecordTransformer do
  @moduledoc """
  Generic record transformation utilities for sync operations.
  
  This module provides a set of configurable transformations that can be
  applied to records during sync processing. Transformations are applied
  in sequence and can be chained together for complex data processing.
  
  ## Built-in Transformations
  
  - `:normalize_dates` - Convert date strings to standardized formats
  - `:normalize_booleans` - Convert various boolean representations to true/false
  - `:normalize_numbers` - Convert string numbers to numeric types
  - `:trim_strings` - Remove leading/trailing whitespace from strings
  - `:normalize_case` - Convert string case (upper, lower, title)
  - `:remove_empty_fields` - Remove fields with empty/nil values
  - `:rename_fields` - Rename fields according to mapping
  - `:extract_nested` - Extract nested field values to top level
  - `:custom_transform` - Apply custom transformation function
  
  ## Configuration Examples
  
      transformations = [
        {:normalize_dates, [:created_at, :updated_at]},
        {:normalize_booleans, [:active, :deleted]},
        {:trim_strings, :all},
        {:remove_empty_fields, []},
        {:rename_fields, %{"old_name" => "new_name"}},
        {:custom_transform, &my_custom_function/1}
      ]
  
  ## Usage
  
      record = %{
        "fields" => %{
          "created_at" => "2023-01-01T10:00:00.000Z",
          "active" => "true",
          "name" => "  John Doe  ",
          "empty_field" => "",
          "old_name" => "value"
        }
      }
      
      {:ok, transformed} = RecordTransformer.apply_transformations(record, transformations)
  """
  
  require Logger

  @type transformation :: 
    {:normalize_dates, [atom()] | :all} |
    {:normalize_booleans, [atom()] | :all} |
    {:normalize_numbers, [atom()] | :all} |
    {:trim_strings, [atom()] | :all} |
    {:normalize_case, [atom()] | :all, :upper | :lower | :title} |
    {:remove_empty_fields, []} |
    {:rename_fields, %{String.t() => String.t()}} |
    {:extract_nested, %{String.t() => [String.t()]}} |
    {:custom_transform, function()}

  @doc """
  Apply a list of transformations to a record.
  
  Transformations are applied in sequence, with each transformation
  receiving the output of the previous transformation.
  
  ## Parameters
  
  * `record` - The record to transform
  * `transformations` - List of transformation configurations
  
  ## Returns
  
  * `{:ok, transformed_record}` - All transformations applied successfully
  * `{:error, reason}` - Transformation failed
  """
  @spec apply_transformations(map(), [transformation()]) :: {:ok, map()} | {:error, any()}
  def apply_transformations(record, transformations) do
    Logger.debug("🔄 Applying #{length(transformations)} transformations")
    
    Enum.reduce_while(transformations, {:ok, record}, fn transformation, {:ok, current_record} ->
      case apply_single_transformation(current_record, transformation) do
        {:ok, transformed_record} ->
          {:cont, {:ok, transformed_record}}
          
        {:error, error} ->
          Logger.warn("⚠️ Transformation failed: #{inspect(transformation)} - #{inspect(error)}")
          {:halt, {:error, {:transformation_failed, transformation, error}}}
      end
    end)
  end

  @doc """
  Apply a single transformation to a record.
  
  ## Parameters
  
  * `record` - The record to transform
  * `transformation` - Single transformation configuration
  
  ## Returns
  
  * `{:ok, transformed_record}` - Transformation applied successfully
  * `{:error, reason}` - Transformation failed
  """
  @spec apply_single_transformation(map(), transformation()) :: {:ok, map()} | {:error, any()}
  def apply_single_transformation(record, transformation) do
    try do
      case transformation do
        {:normalize_dates, fields} ->
          {:ok, normalize_dates(record, fields)}
          
        {:normalize_booleans, fields} ->
          {:ok, normalize_booleans(record, fields)}
          
        {:normalize_numbers, fields} ->
          {:ok, normalize_numbers(record, fields)}
          
        {:trim_strings, fields} ->
          {:ok, trim_strings(record, fields)}
          
        {:normalize_case, fields, case_type} ->
          {:ok, normalize_case(record, fields, case_type)}
          
        {:remove_empty_fields, _opts} ->
          {:ok, remove_empty_fields(record)}
          
        {:rename_fields, field_mapping} ->
          {:ok, rename_fields(record, field_mapping)}
          
        {:extract_nested, extraction_mapping} ->
          {:ok, extract_nested_fields(record, extraction_mapping)}
          
        {:custom_transform, transform_function} when is_function(transform_function, 1) ->
          case transform_function.(record) do
            {:ok, transformed} -> {:ok, transformed}
            {:error, error} -> {:error, error}
            transformed when is_map(transformed) -> {:ok, transformed}
            other -> {:error, {:invalid_transform_result, other}}
          end
          
        unknown_transformation ->
          Logger.warn("⚠️ Unknown transformation: #{inspect(unknown_transformation)}")
          {:ok, record}  # Skip unknown transformations
      end
    rescue
      error ->
        {:error, {:transformation_exception, error, __STACKTRACE__}}
    end
  end

  # Private transformation functions

  defp normalize_dates(record, fields) do
    apply_field_transformation(record, fields, &normalize_date_value/1)
  end

  defp normalize_date_value(value) when is_binary(value) do
    case DateTime.from_iso8601(value) do
      {:ok, datetime, _offset} -> 
        DateTime.to_iso8601(datetime)
      {:error, _} ->
        # Try parsing with NaiveDateTime
        case NaiveDateTime.from_iso8601(value) do
          {:ok, naive_datetime} ->
            naive_datetime
            |> DateTime.from_naive!("Etc/UTC")
            |> DateTime.to_iso8601()
          {:error, _} ->
            # Return original value if parsing fails
            value
        end
    end
  end
  defp normalize_date_value(value), do: value

  defp normalize_booleans(record, fields) do
    apply_field_transformation(record, fields, &normalize_boolean_value/1)
  end

  defp normalize_boolean_value(value) when is_boolean(value), do: value
  defp normalize_boolean_value(value) when is_binary(value) do
    case String.downcase(String.trim(value)) do
      v when v in ["true", "yes", "1", "on", "enabled"] -> true
      v when v in ["false", "no", "0", "off", "disabled", ""] -> false
      _ -> value  # Return original if not recognized
    end
  end
  defp normalize_boolean_value(value) when is_integer(value) do
    value != 0
  end
  defp normalize_boolean_value(value), do: value

  defp normalize_numbers(record, fields) do
    apply_field_transformation(record, fields, &normalize_number_value/1)
  end

  defp normalize_number_value(value) when is_number(value), do: value
  defp normalize_number_value(value) when is_binary(value) do
    value = String.trim(value)
    
    cond do
      value == "" -> nil
      String.contains?(value, ".") ->
        case Float.parse(value) do
          {float_val, ""} -> float_val
          _ -> value
        end
      true ->
        case Integer.parse(value) do
          {int_val, ""} -> int_val
          _ -> value
        end
    end
  end
  defp normalize_number_value(value), do: value

  defp trim_strings(record, fields) do
    apply_field_transformation(record, fields, &trim_string_value/1)
  end

  defp trim_string_value(value) when is_binary(value), do: String.trim(value)
  defp trim_string_value(value), do: value

  defp normalize_case(record, fields, case_type) do
    transform_func = case case_type do
      :upper -> &String.upcase/1
      :lower -> &String.downcase/1
      :title -> &title_case/1
      _ -> &(&1)
    end
    
    apply_field_transformation(record, fields, fn
      value when is_binary(value) -> transform_func.(value)
      value -> value
    end)
  end

  defp title_case(string) when is_binary(string) do
    string
    |> String.split()
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
  end

  defp remove_empty_fields(record) do
    if Map.has_key?(record, "fields") do
      cleaned_fields = record["fields"]
      |> Enum.reject(fn {_key, value} ->
        is_empty_value?(value)
      end)
      |> Map.new()
      
      Map.put(record, "fields", cleaned_fields)
    else
      # Apply to entire record if no "fields" key
      record
      |> Enum.reject(fn {_key, value} ->
        is_empty_value?(value)
      end)
      |> Map.new()
    end
  end

  defp is_empty_value?(nil), do: true
  defp is_empty_value?(""), do: true
  defp is_empty_value?(value) when is_binary(value), do: String.trim(value) == ""
  defp is_empty_value?([]), do: true
  defp is_empty_value?(%{}) when map_size(%{}) == 0, do: true
  defp is_empty_value?(_), do: false

  defp rename_fields(record, field_mapping) do
    if Map.has_key?(record, "fields") do
      renamed_fields = Enum.reduce(field_mapping, record["fields"], fn {old_name, new_name}, acc ->
        case Map.pop(acc, old_name) do
          {nil, acc} -> acc  # Field doesn't exist
          {value, acc} -> Map.put(acc, new_name, value)
        end
      end)
      
      Map.put(record, "fields", renamed_fields)
    else
      # Apply to entire record if no "fields" key
      Enum.reduce(field_mapping, record, fn {old_name, new_name}, acc ->
        case Map.pop(acc, old_name) do
          {nil, acc} -> acc  # Field doesn't exist
          {value, acc} -> Map.put(acc, new_name, value)
        end
      end)
    end
  end

  defp extract_nested_fields(record, extraction_mapping) do
    extracted_fields = Enum.reduce(extraction_mapping, %{}, fn {target_field, source_path}, acc ->
      case get_nested_value(record, source_path) do
        nil -> acc
        value -> Map.put(acc, target_field, value)
      end
    end)
    
    # Merge extracted fields into the record's fields
    if Map.has_key?(record, "fields") do
      updated_fields = Map.merge(record["fields"], extracted_fields)
      Map.put(record, "fields", updated_fields)
    else
      Map.merge(record, extracted_fields)
    end
  end

  defp get_nested_value(data, path) when is_list(path) do
    get_in(data, path)
  end
  defp get_nested_value(data, path) when is_binary(path) do
    Map.get(data, path)
  end
  defp get_nested_value(data, path) when is_atom(path) do
    Map.get(data, path) || Map.get(data, to_string(path))
  end

  defp apply_field_transformation(record, :all, transform_func) do
    if Map.has_key?(record, "fields") do
      transformed_fields = Enum.reduce(record["fields"], %{}, fn {key, value}, acc ->
        Map.put(acc, key, transform_func.(value))
      end)
      
      Map.put(record, "fields", transformed_fields)
    else
      # Apply to all fields in the record
      Enum.reduce(record, %{}, fn {key, value}, acc ->
        Map.put(acc, key, transform_func.(value))
      end)
    end
  end

  defp apply_field_transformation(record, fields, transform_func) when is_list(fields) do
    if Map.has_key?(record, "fields") do
      transformed_fields = Enum.reduce(fields, record["fields"], fn field, acc ->
        field_key = to_string(field)
        case Map.get(acc, field_key) do
          nil -> acc
          value -> Map.put(acc, field_key, transform_func.(value))
        end
      end)
      
      Map.put(record, "fields", transformed_fields)
    else
      # Apply to specified fields in the record
      Enum.reduce(fields, record, fn field, acc ->
        field_key = to_string(field)
        case Map.get(acc, field_key) do
          nil -> 
            # Try atom key if string key doesn't exist
            atom_key = try do
              String.to_existing_atom(field_key)
            rescue
              ArgumentError -> nil
            end
            
            if atom_key && Map.has_key?(acc, atom_key) do
              Map.put(acc, atom_key, transform_func.(Map.get(acc, atom_key)))
            else
              acc
            end
          value -> 
            Map.put(acc, field_key, transform_func.(value))
        end
      end)
    end
  end
end