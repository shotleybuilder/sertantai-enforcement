defmodule EhsEnforcement.Configuration.Validations do
  @moduledoc """
  Custom validation functions for configuration resources.
  """

  @doc """
  Validates the daily scrape cron expression.
  """
  def validate_daily_cron(changeset) do
    validate_cron_expression(changeset, :daily_scrape_cron)
  end

  @doc """
  Validates the weekly scrape cron expression.
  """
  def validate_weekly_cron(changeset) do
    validate_cron_expression(changeset, :weekly_scrape_cron)
  end

  @doc """
  Validates that a cron expression is syntactically correct.

  Accepts standard cron format: "minute hour day month weekday"
  Example: "0 2 * * *" (every day at 2 AM)
  """
  def validate_cron_expression(changeset, attribute) do
    case Ash.Changeset.get_attribute(changeset, attribute) do
      nil ->
        changeset

      cron_expr when is_binary(cron_expr) ->
        case parse_cron_expression(cron_expr) do
          :ok ->
            changeset

          {:error, message} ->
            Ash.Changeset.add_error(changeset, field: attribute, message: message)
        end

      _ ->
        Ash.Changeset.add_error(changeset, field: attribute, message: "must be a string")
    end
  end

  @doc """
  Parses and validates a cron expression.

  Returns :ok if valid, {:error, message} if invalid.
  """
  def parse_cron_expression(cron_expr) when is_binary(cron_expr) do
    cron_expr
    |> String.trim()
    |> String.split(~r/\s+/)
    |> case do
      [minute, hour, day, month, weekday] ->
        with :ok <- validate_cron_field(minute, :minute),
             :ok <- validate_cron_field(hour, :hour),
             :ok <- validate_cron_field(day, :day),
             :ok <- validate_cron_field(month, :month),
             :ok <- validate_cron_field(weekday, :weekday) do
          :ok
        else
          {:error, message} -> {:error, message}
        end

      parts when length(parts) != 5 ->
        {:error, "cron expression must have exactly 5 fields (minute hour day month weekday)"}

      _ ->
        {:error, "invalid cron expression format"}
    end
  end

  def parse_cron_expression(_), do: {:error, "cron expression must be a string"}

  # Private helper functions for cron field validation

  defp validate_cron_field("*", _field), do: :ok
  defp validate_cron_field("*/1", _field), do: :ok

  defp validate_cron_field(field, field_type) when is_binary(field) do
    cond do
      String.contains?(field, "/") ->
        validate_step_expression(field, field_type)

      String.contains?(field, "-") ->
        validate_range_expression(field, field_type)

      String.contains?(field, ",") ->
        validate_list_expression(field, field_type)

      true ->
        validate_single_value(field, field_type)
    end
  end

  defp validate_step_expression(field, field_type) do
    case String.split(field, "/") do
      [base, step] ->
        with :ok <- validate_cron_field(base, field_type),
             {step_val, ""} <- Integer.parse(step),
             true <- step_val > 0 do
          :ok
        else
          _ -> {:error, "invalid step expression: #{field}"}
        end

      _ ->
        {:error, "invalid step expression: #{field}"}
    end
  end

  defp validate_range_expression(field, field_type) do
    case String.split(field, "-") do
      [start_str, end_str] ->
        with {start_val, ""} <- Integer.parse(start_str),
             {end_val, ""} <- Integer.parse(end_str),
             :ok <- validate_field_value(start_val, field_type),
             :ok <- validate_field_value(end_val, field_type),
             true <- start_val <= end_val do
          :ok
        else
          _ -> {:error, "invalid range expression: #{field}"}
        end

      _ ->
        {:error, "invalid range expression: #{field}"}
    end
  end

  defp validate_list_expression(field, field_type) do
    field
    |> String.split(",")
    |> Enum.reduce_while(:ok, fn value, :ok ->
      case validate_cron_field(String.trim(value), field_type) do
        :ok -> {:cont, :ok}
        error -> {:halt, error}
      end
    end)
  end

  defp validate_single_value(field, field_type) do
    case Integer.parse(field) do
      {value, ""} ->
        validate_field_value(value, field_type)

      _ ->
        {:error, "invalid #{field_type} value: #{field}"}
    end
  end

  defp validate_field_value(value, :minute) when value >= 0 and value <= 59, do: :ok
  defp validate_field_value(value, :hour) when value >= 0 and value <= 23, do: :ok
  defp validate_field_value(value, :day) when value >= 1 and value <= 31, do: :ok
  defp validate_field_value(value, :month) when value >= 1 and value <= 12, do: :ok
  defp validate_field_value(value, :weekday) when value >= 0 and value <= 7, do: :ok

  defp validate_field_value(value, field_type) do
    ranges = %{
      minute: "0-59",
      hour: "0-23",
      day: "1-31",
      month: "1-12",
      weekday: "0-7 (0 and 7 are Sunday)"
    }

    {:error, "#{field_type} value #{value} out of range (valid: #{ranges[field_type]})"}
  end
end
