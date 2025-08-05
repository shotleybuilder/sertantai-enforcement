defmodule EhsEnforcement.Sync.Generic.RecordValidator do
  @moduledoc """
  Generic record validation utilities for sync operations.
  
  This module provides configurable validation rules that can be applied
  to records before processing. Validation rules help ensure data quality
  and prevent invalid records from being processed.
  
  ## Built-in Validation Rules
  
  - `:required_fields` - Ensure specified fields are present and non-empty
  - `:field_types` - Validate field values match expected types
  - `:field_formats` - Validate field values match regex patterns
  - `:field_lengths` - Validate string field lengths within bounds
  - `:field_ranges` - Validate numeric field values within ranges
  - `:allowed_values` - Validate field values are in allowed sets
  - `:custom_validation` - Apply custom validation function
  
  ## Configuration Examples
  
      validation_rules = [
        {:required_fields, [:name, :email, :status]},
        {:field_types, %{age: :integer, active: :boolean, score: :float}},
        {:field_formats, %{email: ~r/^[^@]+@[^@]+\.[^@]+$/}},
        {:field_lengths, %{name: %{min: 2, max: 100}}},
        {:field_ranges, %{age: %{min: 0, max: 120}, score: %{min: 0.0, max: 100.0}}},
        {:allowed_values, %{status: ["active", "inactive", "pending"]}},
        {:custom_validation, &my_custom_validator/1}
      ]
  
  ## Usage
  
      record = %{
        "fields" => %{
          "name" => "John Doe",
          "email" => "john@example.com",
          "age" => 25,
          "status" => "active"
        }
      }
      
      case RecordValidator.validate_record(record, validation_rules) do
        :ok -> 
          # Record is valid
        {:error, errors} -> 
          # Handle validation errors
      end
  """
  
  require Logger

  @type validation_rule ::
    {:required_fields, [atom()]} |
    {:field_types, %{atom() => atom()}} |
    {:field_formats, %{atom() => Regex.t()}} |
    {:field_lengths, %{atom() => %{min: non_neg_integer(), max: non_neg_integer()}}} |
    {:field_ranges, %{atom() => %{min: number(), max: number()}}} |
    {:allowed_values, %{atom() => [any()]}} |
    {:custom_validation, function()}

  @type validation_error :: %{
    field: atom() | String.t(),
    rule: atom(),
    message: String.t(),
    value: any(),
    expected: any()
  }

  @doc """
  Validate a record against a list of validation rules.
  
  ## Parameters
  
  * `record` - The record to validate
  * `validation_rules` - List of validation rule configurations
  
  ## Returns
  
  * `:ok` - Record passes all validations
  * `{:error, [validation_error()]}` - List of validation errors
  """
  @spec validate_record(map(), [validation_rule()]) :: :ok | {:error, [validation_error()]}
  def validate_record(record, validation_rules) do
    Logger.debug("🔍 Validating record against #{length(validation_rules)} rules")
    
    errors = Enum.reduce(validation_rules, [], fn rule, acc_errors ->
      case apply_validation_rule(record, rule) do
        :ok -> 
          acc_errors
        {:error, rule_errors} when is_list(rule_errors) -> 
          rule_errors ++ acc_errors
        {:error, rule_error} -> 
          [rule_error | acc_errors]
      end
    end)
    
    if length(errors) == 0 do
      :ok
    else
      {:error, Enum.reverse(errors)}
    end
  end

  @doc """
  Apply a single validation rule to a record.
  
  ## Parameters
  
  * `record` - The record to validate
  * `rule` - Single validation rule configuration
  
  ## Returns
  
  * `:ok` - Record passes the validation
  * `{:error, validation_error() | [validation_error()]}` - Validation error(s)
  """
  @spec apply_validation_rule(map(), validation_rule()) :: 
    :ok | {:error, validation_error() | [validation_error()]}
  def apply_validation_rule(record, rule) do
    try do
      case rule do
        {:required_fields, fields} ->
          validate_required_fields(record, fields)
          
        {:field_types, type_mapping} ->
          validate_field_types(record, type_mapping)
          
        {:field_formats, format_mapping} ->
          validate_field_formats(record, format_mapping)
          
        {:field_lengths, length_mapping} ->
          validate_field_lengths(record, length_mapping)
          
        {:field_ranges, range_mapping} ->
          validate_field_ranges(record, range_mapping)
          
        {:allowed_values, values_mapping} ->
          validate_allowed_values(record, values_mapping)
          
        {:custom_validation, validation_function} when is_function(validation_function, 1) ->
          case validation_function.(record) do
            :ok -> :ok
            {:error, error} -> {:error, error}
            true -> :ok
            false -> {:error, %{rule: :custom_validation, message: "Custom validation failed"}}
            other -> {:error, %{rule: :custom_validation, message: "Invalid validation result", result: other}}
          end
          
        unknown_rule ->
          Logger.warn("⚠️ Unknown validation rule: #{inspect(unknown_rule)}")
          :ok  # Skip unknown rules
      end
    rescue
      error ->
        {:error, %{
          rule: :validation_exception,
          message: "Validation rule raised exception",
          exception: error,
          stacktrace: __STACKTRACE__
        }}
    end
  end

  # Private validation functions

  defp validate_required_fields(record, fields) do
    record_fields = get_record_fields(record)
    
    missing_fields = Enum.filter(fields, fn field ->
      field_key = to_string(field)
      value = Map.get(record_fields, field_key)
      is_empty_field_value?(value)
    end)
    
    if length(missing_fields) == 0 do
      :ok
    else
      errors = Enum.map(missing_fields, fn field ->
        %{
          field: field,
          rule: :required_field,
          message: "Required field '#{field}' is missing or empty",
          value: Map.get(record_fields, to_string(field)),
          expected: "non-empty value"
        }
      end)
      
      {:error, errors}
    end
  end

  defp validate_field_types(record, type_mapping) do
    record_fields = get_record_fields(record)
    
    errors = Enum.reduce(type_mapping, [], fn {field, expected_type}, acc ->
      field_key = to_string(field)
      value = Map.get(record_fields, field_key)
      
      if value != nil and not is_type?(value, expected_type) do
        error = %{
          field: field,
          rule: :field_type,
          message: "Field '#{field}' has incorrect type",
          value: value,
          expected: expected_type,
          actual: get_value_type(value)
        }
        [error | acc]
      else
        acc
      end
    end)
    
    if length(errors) == 0 do
      :ok
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp validate_field_formats(record, format_mapping) do
    record_fields = get_record_fields(record)
    
    errors = Enum.reduce(format_mapping, [], fn {field, pattern}, acc ->
      field_key = to_string(field)
      value = Map.get(record_fields, field_key)
      
      if is_binary(value) and not Regex.match?(pattern, value) do
        error = %{
          field: field,
          rule: :field_format,
          message: "Field '#{field}' does not match required format",
          value: value,
          expected: inspect(pattern)
        }
        [error | acc]
      else
        acc
      end
    end)
    
    if length(errors) == 0 do
      :ok
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp validate_field_lengths(record, length_mapping) do
    record_fields = get_record_fields(record)
    
    errors = Enum.reduce(length_mapping, [], fn {field, constraints}, acc ->
      field_key = to_string(field)
      value = Map.get(record_fields, field_key)
      
      if is_binary(value) do
        length = String.length(value)
        min_length = Map.get(constraints, :min)
        max_length = Map.get(constraints, :max)
        
        cond do
          min_length && length < min_length ->
            error = %{
              field: field,
              rule: :field_length,
              message: "Field '#{field}' is too short (minimum: #{min_length})",
              value: value,
              actual_length: length,
              expected: constraints
            }
            [error | acc]
            
          max_length && length > max_length ->
            error = %{
              field: field,
              rule: :field_length,
              message: "Field '#{field}' is too long (maximum: #{max_length})",
              value: value,
              actual_length: length,
              expected: constraints
            }
            [error | acc]
            
          true ->
            acc
        end
      else
        acc
      end
    end)
    
    if length(errors) == 0 do
      :ok
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp validate_field_ranges(record, range_mapping) do
    record_fields = get_record_fields(record)
    
    errors = Enum.reduce(range_mapping, [], fn {field, constraints}, acc ->
      field_key = to_string(field)
      value = Map.get(record_fields, field_key)
      
      if is_number(value) do
        min_value = Map.get(constraints, :min)
        max_value = Map.get(constraints, :max)
        
        cond do
          min_value && value < min_value ->
            error = %{
              field: field,
              rule: :field_range,
              message: "Field '#{field}' is below minimum value (minimum: #{min_value})",
              value: value,
              expected: constraints
            }
            [error | acc]
            
          max_value && value > max_value ->
            error = %{
              field: field,
              rule: :field_range,
              message: "Field '#{field}' is above maximum value (maximum: #{max_value})",
              value: value,
              expected: constraints
            }
            [error | acc]
            
          true ->
            acc
        end
      else
        acc
      end
    end)
    
    if length(errors) == 0 do
      :ok
    else
      {:error, Enum.reverse(errors)}
    end
  end

  defp validate_allowed_values(record, values_mapping) do
    record_fields = get_record_fields(record)
    
    errors = Enum.reduce(values_mapping, [], fn {field, allowed_values}, acc ->
      field_key = to_string(field)
      value = Map.get(record_fields, field_key)
      
      if value != nil and value not in allowed_values do
        error = %{
          field: field,
          rule: :allowed_values,
          message: "Field '#{field}' has invalid value",
          value: value,
          expected: allowed_values
        }
        [error | acc]
      else
        acc
      end
    end)
    
    if length(errors) == 0 do
      :ok
    else
      {:error, Enum.reverse(errors)}
    end
  end

  # Utility functions

  defp get_record_fields(record) do
    case record do
      %{"fields" => fields} when is_map(fields) -> fields
      %{fields: fields} when is_map(fields) -> fields
      fields when is_map(fields) -> fields
      _ -> %{}
    end
  end

  defp is_empty_field_value?(nil), do: true
  defp is_empty_field_value?(""), do: true
  defp is_empty_field_value?(value) when is_binary(value), do: String.trim(value) == ""
  defp is_empty_field_value?([]), do: true
  defp is_empty_field_value?(%{}) when map_size(%{}) == 0, do: true
  defp is_empty_field_value?(_), do: false

  defp is_type?(value, :string), do: is_binary(value)
  defp is_type?(value, :integer), do: is_integer(value)
  defp is_type?(value, :float), do: is_float(value)
  defp is_type?(value, :number), do: is_number(value)
  defp is_type?(value, :boolean), do: is_boolean(value)
  defp is_type?(value, :list), do: is_list(value)
  defp is_type?(value, :map), do: is_map(value)
  defp is_type?(value, :atom), do: is_atom(value)
  defp is_type?(_value, _type), do: false

  defp get_value_type(value) when is_binary(value), do: :string
  defp get_value_type(value) when is_integer(value), do: :integer
  defp get_value_type(value) when is_float(value), do: :float
  defp get_value_type(value) when is_boolean(value), do: :boolean
  defp get_value_type(value) when is_list(value), do: :list
  defp get_value_type(value) when is_map(value), do: :map
  defp get_value_type(value) when is_atom(value), do: :atom
  defp get_value_type(_value), do: :unknown
end