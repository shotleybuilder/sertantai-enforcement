defmodule EhsEnforcementWeb.CaseController do
  use EhsEnforcementWeb, :controller

  alias EhsEnforcementWeb.CaseLive.CSVExport

  def export_csv(conn, params) do
    # Parse query parameters for filters, sorting, etc.
    case parse_and_validate_params(params) do
      {:ok, {filters, sort_by, sort_dir}} ->
        case CSVExport.export_cases(filters, sort_by, sort_dir) do
          {:ok, csv_content} ->
            filename = CSVExport.generate_filename(:filtered)

            conn
            |> put_resp_content_type("text/csv")
            |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
            |> send_resp(200, csv_content)

          {:error, reason} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(500, Jason.encode!(%{error: "Failed to export cases: #{reason}"}))
        end

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: reason}))
    end
  end

  def export_detailed_csv(conn, params) do
    # Export with detailed data including related notices
    case parse_and_validate_params(params) do
      {:ok, {filters, sort_by, sort_dir}} ->
        case CSVExport.export_detailed_cases(filters, sort_by, sort_dir) do
          {:ok, csv_content} ->
            filename =
              CSVExport.generate_filename(:filtered)
              |> String.replace(".csv", "_detailed.csv")

            conn
            |> put_resp_content_type("text/csv")
            |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
            |> send_resp(200, csv_content)

          {:error, reason} ->
            conn
            |> put_resp_content_type("application/json")
            |> send_resp(
              500,
              Jason.encode!(%{error: "Failed to export detailed cases: #{reason}"})
            )
        end

      {:error, reason} ->
        conn
        |> put_resp_content_type("application/json")
        |> send_resp(400, Jason.encode!(%{error: reason}))
    end
  end

  def export_excel(conn, params) do
    # Export in Excel format (currently CSV with Excel content type)
    filters = parse_filters(params)
    sort_by = parse_sort_field(params["sort_by"])
    sort_dir = parse_sort_direction(params["sort_dir"])

    case CSVExport.export_cases(filters, sort_by, sort_dir) do
      {:ok, csv_content} ->
        filename =
          CSVExport.generate_filename(:filtered)
          |> String.replace(".csv", ".xlsx")

        conn
        |> put_resp_content_type(
          "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )
        |> put_resp_header("content-disposition", "attachment; filename=\"#{filename}\"")
        |> send_resp(200, csv_content)

      {:error, reason} ->
        conn
        |> put_flash(:error, "Failed to export cases: #{reason}")
        |> redirect(to: ~p"/cases")
    end
  end

  # Private helper functions

  defp parse_and_validate_params(params) do
    try do
      filters = parse_filters(params)
      sort_by = parse_sort_field(params["sort_by"])
      sort_dir = parse_sort_direction(params["sort_dir"])

      # Validate agency_id if provided
      case params["agency_id"] do
        nil ->
          :ok

        "" ->
          :ok

        agency_id when is_binary(agency_id) ->
          case Ecto.UUID.cast(agency_id) do
            {:ok, _} -> :ok
            :error -> throw({:error, "Invalid agency_id format"})
          end

        _ ->
          throw({:error, "Invalid agency_id parameter"})
      end

      # Validate date parameters
      for {key, date_str} <- [{"date_from", params["date_from"]}, {"date_to", params["date_to"]}] do
        case date_str do
          nil ->
            :ok

          "" ->
            :ok

          date when is_binary(date) ->
            case Date.from_iso8601(date) do
              {:ok, _} -> :ok
              {:error, _} -> throw({:error, "Invalid #{key} date format"})
            end

          _ ->
            throw({:error, "Invalid #{key} parameter"})
        end
      end

      {:ok, {filters, sort_by, sort_dir}}
    rescue
      _ -> {:error, "Invalid request parameters"}
    catch
      {:error, reason} -> {:error, reason}
    end
  end

  defp parse_filters(params) do
    %{}
    |> add_filter(:agency_id, params["agency_id"])
    |> add_filter(:date_from, params["date_from"])
    |> add_filter(:date_to, params["date_to"])
    |> add_filter(:min_fine, params["min_fine"])
    |> add_filter(:max_fine, params["max_fine"])
    |> add_filter(:search, params["search"])
  end

  defp add_filter(filters, _key, nil), do: filters
  defp add_filter(filters, _key, ""), do: filters
  defp add_filter(filters, key, value), do: Map.put(filters, key, value)

  defp parse_sort_field(nil), do: :offence_action_date
  defp parse_sort_field(""), do: :offence_action_date
  defp parse_sort_field("offender_name"), do: :offender_name
  defp parse_sort_field("agency_name"), do: :agency_name
  defp parse_sort_field("offence_fine"), do: :offence_fine
  defp parse_sort_field("regulator_id"), do: :regulator_id
  defp parse_sort_field(_), do: :offence_action_date

  defp parse_sort_direction(nil), do: :desc
  defp parse_sort_direction(""), do: :desc
  defp parse_sort_direction("asc"), do: :asc
  defp parse_sort_direction("desc"), do: :desc
  defp parse_sort_direction(_), do: :desc
end
