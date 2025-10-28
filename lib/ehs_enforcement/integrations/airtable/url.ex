defmodule EhsEnforcement.Integrations.Airtable.Url do
  @moduledoc """

  Airtable standard api shape
  curl https://api.airtable.com/v0/appq5OQW9bTHC1zO5/tblJW0DMpRs74CJux \
  -H "Authorization: Bearer API_KEY"


  """

  @spec url(binary, binary, any) :: {:ok, nonempty_binary}
  @doc """
  Builds the url to get records from Airtable
  """
  def url(base, table, %{record: record} = options) when is_binary(record) do
    url(%{path: "/#{base}/#{table}/#{record}", options: ""}, options)
  end

  def url(base, table, options) do
    url(%{path: "/#{base}/#{table}", options: ""}, options)
  end

  def url(collector, options) do
    Enum.reduce(options, collector, fn {key, value}, acc ->
      case key do
        :max_records ->
          update_params(acc, "maxRecords=" <> value)

        :view ->
          update_params(acc, ~s/view=#{URI.encode(value)}/)

        :fields ->
          update_params(acc, fields(value))

        :formula ->
          encode_formula(value)
          |> (&update_params(acc, "filterByFormula=" <> &1)).()

        :offset ->
          update_params(acc, "offset=" <> value)

        _ ->
          acc
      end
    end)
    |> remove_trailing_ampasand()
    |> (&(Map.get(&1, :path) <> "?" <> Map.get(&1, :options))).()
    # |> IO.inspect()
    |> (&{:ok, &1}).()
  end

  defp update_params(%{options: options} = acc, option) do
    options = "#{options}#{option}&"
    Map.put(acc, :options, options)
  end

  defp remove_trailing_ampasand(%{options: options} = acc) do
    Map.put(acc, :options, String.replace(options, ~r/&$/, ""))
  end

  def fields(fields) do
    # fields%5B%5D=FAQ%20-%20EN%20%E2%9D%8C&fields%5B%5D=Risk%20Model
    Enum.reduce(fields, "", fn x, acc ->
      acc <> encode_field("fields[]=" <> x) <> "&"
    end)
    |> String.replace(~r/&$/, "")
  end

  def encode_field(field) do
    field
    |> URI.encode()
    |> URI.encode(&(&1 != ?[ && &1 != ?] && &1 != ?& && &1 != ?.))
  end

  def encode_formula(formula) do
    formula
    |> URI.encode()
    |> URI.encode(&(&1 != ?=))
    |> URI.encode(&(&1 != ?'))
    |> URI.encode(&(&1 != ?#))
    |> URI.encode(&(&1 != ?,))
    |> URI.encode(&(&1 != ?&))
  end
end
