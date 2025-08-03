defmodule EhsEnforcement.Utility do
  @moduledoc false

  alias EhsEnforcement.Legislation.LegalRegister

  @doc """
  Utility function to time the parser.
  Arose when rm_header was taking 5 seconds!  Faster now :)
  """
  def parse_timer() do
    # {:ok, binary} = File.read(Path.absname(Legl.original())) # TODO: Fix this reference
    # {t, binary} = :timer.tc(UK, :rm_header, [binary])
    # display_time("rm_header", t)
    # {t, _binary} = :timer.tc(UK, :rm_explanatory_note, [binary])
    # display_time("rm_explanatory_note", t)
  end

  def parser_timer(arg, func, name) do
    {t, binary} = :timer.tc(func, [arg])
    display_time(name, t)
    binary
  end

  defp display_time(f, t) do
    IO.puts("#{f} takes #{t} microseconds or #{t / 1_000_000} seconds")
  end

  def todays_date() do
    DateTime.utc_now()
    |> (&"#{&1.day}/#{&1.month}/#{&1.year}").()
  end

  def csv_header_row(fields, at_csv) do
    Enum.join(fields, ",")
    |> EhsEnforcement.Utility.write_to_csv(at_csv)
  end

  def quote_list(list) when is_list(list) do
    Enum.map(list, fn string ->
      cond do
        String.contains?(string, ",") -> ~s/"#{string}"/
        true -> string
      end
    end)
  end

  def csv_quote_enclosure(list) when is_list(list) do
    Enum.map(list, &csv_quote_enclosure/1)
  end

  def csv_quote_enclosure(string) do
    string = string |> to_string() |> String.trim()

    if "" != string do
      ~s/"#{string}"/
    else
      string
    end
  end

  def csv_list_quote_enclosure(string) do
    ~s/[#{string}]/
  end

  def append_to_csv(binary, filename) do
    {:ok, file} =
      "lib/#{filename}.csv"
      |> Path.absname()
      |> File.open([:utf8, :append])

    IO.puts(file, binary)
    File.close(file)
    :ok
  end

  def write_to_csv(binary, "lib" <> _rest = path) do
    {:ok, file} =
      path
      |> Path.absname()
      |> File.open([:utf8, :write])

    IO.puts(file, binary)
    File.close(file)
    :ok
  end

  def write_to_csv(binary, filename) do
    {:ok, file} =
      "lib/#{filename}.csv"
      |> Path.absname()
      |> File.open([:utf8, :write])

    IO.puts(file, binary)
    File.close(file)
    :ok
  end

  @doc """
  Receives a path as string and returns atom keyed map
  """
  @spec read_json_records(binary()) :: list(map())
  def read_json_records(path) do
    %{records: records} = open_and_parse_json_file(path)
    records
  end

  @spec open_and_parse_json_file(binary()) :: map()
  defp open_and_parse_json_file(path) do
    path
    |> Path.absname()
    |> File.read()
    |> elem(1)
    |> Jason.decode!(keys: :atoms)
  end

  @doc """
  Function to save records as .json
  """
  @spec save_json(list(), binary()) :: :ok
  def save_json(records, path) do
    json = Map.put(%{}, "records", records) |> Jason.encode!(pretty: true)
    save_at_records_to_file(~s/#{json}/, path)
  end

  @spec save_json_returning(list(), binary()) :: {:ok, list()}
  def save_json_returning(records, path) do
    json = Map.put(%{}, "records", records) |> Jason.encode!(pretty: true)
    {save_at_records_to_file(~s/#{json}/, path), records}
  end

  @spec save_structs_as_json(list(struct() | map()), path :: binary(), map()) :: :ok
  def save_structs_as_json(records, path, %{filesave?: true} = _opts) do
    save_structs_as_json(records, path)
  end

  def save_structs_as_json(_, _, _), do: :ok

  @spec save_structs_as_json(list(struct() | map()), binary()) :: :ok
  def save_structs_as_json(records, path) when is_list(records) do
    maps_from_structs(records)
    |> (&Map.put(%{}, "records", &1)).()
    |> Jason.encode!(pretty: true)
    |> save_at_records_to_file(path)
  end

  def save_structs_as_json(_, _), do: :ok

  @spec save_structs_as_json_returning(list(), path :: binary(), map()) :: list()
  def save_structs_as_json_returning(records, path, %{filesave?: true} = _opts) do
    save_structs_as_json(records, path)
    records
  end

  @doc """

  """
  def save_at_records_to_file(records),
    do: save_at_records_to_file(records, "lib/legl/data_files/txt/airtable.txt")

  def save_at_records_to_file(records, path) when is_list(records) do
    case File.open(path |> Path.absname(), [:utf8, :write]) do
      {:ok, file} ->
        IO.puts(file, inspect(records, limit: :infinity))
        File.close(file)
        :ok

      {:error, :enoent} ->
        IO.puts("ERROR: :enoent #{path}")
        :ok
    end
  end

  def save_at_records_to_file(records, path) when is_binary(records) do
    case File.open(path |> Path.absname(), [:utf8, :write]) do
      {:ok, file} ->
        IO.puts(file, records)
        File.close(file)
        :ok

      {:error, :enoent} ->
        IO.puts("ERROR: :enoent #{path}")
        :ok
    end
  end

  def append_records_to_file(records, path) when is_binary(records) do
    {:ok, file} =
      path
      |> Path.absname()
      |> File.open([:utf8, :append])

    IO.puts(file, records)
    File.close(file)
    :ok
  end

  def count_csv_rows(filename) do
    binary =
      ("lib/" <> filename <> ".csv")
      |> Path.absname()
      |> File.read!()

    binary |> String.graphemes() |> Enum.count(&(&1 == "\n"))
  end

  def legislation_gov_uk_id_url(
        %LegalRegister{type_code: type_code, Number: number, Year: year} = record
      )
      when is_struct(record) do
    legislation_gov_uk_id_url(number, type_code, year)
  end

  def legislation_gov_uk_id_url(%{type_code: type_code, Number: number, Year: year} = record)
      when is_map(record) do
    legislation_gov_uk_id_url(number, type_code, year)
  end

  def legislation_gov_uk_id_url(number, type_code, year) do
    ~s[https://legislation.gov.uk/id/#{type_code}/#{year}/#{number}]
  end

  def resource_path(url) do
    case Regex.run(~r"^https:\/\/(?:www\.)?legislation\.gov\.uk(.*)", url) do
      [_, path] -> {:ok, path}
      _ -> {:error, "Problem getting path from url: #{url}"}
    end
  end

  @spec type_number_year(binary()) ::
          {UK.law_type_code(), UK.law_year(), UK.law_number()} | {:error, :no_match}
  def type_number_year("/id" <> path) do
    type_number_year(path)
  end

  # https://webarchive.nationalarchives.gov.uk/eu-exit/20201210174128/https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:12003TN02/16/C
  def type_number_year("https://webarchive.nationalarchives.gov.uk" <> _path) do
    {"eua"}
  end

  def type_number_year(path) do
    case Regex.run(~r/\/([a-z]*?)\/(\d{4})\/(\d+)/, path) do
      [_match, type, year, number] ->
        {type, number, year}

      nil ->
        IO.puts(~s/ERROR: No match for type_code, year & number for this #{path}/)
        {:error, :no_match}
    end
  end

  @spec split_name(String.t()) :: tuple()
  def split_name(name) do
    # UK_TLA_type-code_year_number
    case Regex.run(~r/([a-z]*?)_(\d{4})_(.*)$/, name) do
      [_, type, year, number] ->
        {type, year, number}

      _ ->
        # UK_RSA_ukpga_1960_Eliz2/8-9/34
        case Regex.run(~r/([a-z]*?)_(\d{4})_(.*)$/, name) do
          [_, type, year, number] ->
            {type, year, number}

          nil ->
            {:error, ~s/no match for #{name}/}
        end
    end
  end

  def iso_date(date) do
    date = String.trim(date)

    case String.split(date, "/") do
      [day, month, year] ->
        "#{year}-#{month}-#{day}"

      [date] ->
        case String.split(date, "-") do
          [day, month, year] ->
            "#{year}-#{month}-#{day}"

          _ ->
            date
        end
    end
  end

  def yyyy_mm_dd(date) do
    [_, year, month, day] = Regex.run(~r/(\d{4})-(\d{2})-(\d{2})/, date)
    "#{day}/#{month}/#{year}"
  end

  def get_date_from_at_date_field(date) when is_binary(date) do
  end

  def duplicate_records(list) do
    list
    |> Enum.group_by(& &1)
    |> Enum.filter(fn
      {_, [_, _ | _]} -> true
      _ -> false
    end)
    |> Enum.map(fn {x, _} -> x end)
    |> Enum.sort()
  end

  @doc """
  Removes duped spaces in a line as captured by the marker
  e.g. "\\[::annex::\\]"
  """
  def rm_dupe_spaces(binary, regex) do
    # remove double, triple and quadruple spaces
    Regex.replace(
      ~r/^(#{regex}.*)/m,
      binary,
      fn _, x -> String.replace(x, ~r/[ ]{2,4}/m, " ") end
    )
  end

  @doc """
  %{"1": "A", "2": "B", ...}
  """
  def alphabet_map() do
    Enum.reduce(
      Enum.zip(1..24, String.split("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "", trim: true)),
      %{},
      fn {x, y}, acc -> Map.put(acc, :"#{x}", y) end
    )
  end

  @doc """
  %{"A": 1, "B": 2, ...}
  """
  def alphabet_to_numeric_map_base() do
    Enum.reduce(
      Enum.zip(String.split("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "", trim: true), 1..26),
      %{},
      fn {x, y}, acc -> Map.put(acc, :"#{x}", y) end
    )
  end

  @doc """
  %{"A" => 65, "B" => 66, ...}
  """
  def alphabet_to_numeric_map() do
    Enum.reduce(
      Enum.zip(String.split("ABCDEFGHIJKLMNOPQRSTUVWXYZ", "", trim: true), 65..(65 + 25)),
      %{},
      fn {x, y}, acc -> Map.put(acc, "#{x}", y) end
    )
    |> Map.put("", 64)
  end

  @doc """
  Columns on screen
  """
  def cols() do
    {_, cols} = :io.columns()
    cols
  end

  def upcaseFirst(<<first::utf8, rest::binary>>), do: String.upcase(<<first::utf8>>) <> rest

  def upcase_first_from_upcase_phrase(string),
    do: string |> String.split(" ") |> Enum.map(&upcase_first_from_upcase/1) |> Enum.join(" ")

  def upcase_first_from_upcase(<<first::utf8, rest::binary>>),
    do: <<first::utf8>> <> String.downcase(rest)

  def numericalise_ordinal(value) do
    ordinals = %{
      "first" => "1",
      "second" => "2",
      "third" => "3",
      "fourth" => "4",
      "fifth" => "5",
      "sixth" => "6",
      "seventh" => "7",
      "eighth" => "8",
      "ninth" => "9",
      "tenth" => "10",
      "eleventh" => "11",
      "twelfth" => "12",
      "thirteenth" => "13",
      "fourteenth" => "14",
      "fifteenth" => "15",
      "sixteenth" => "16",
      "seventeenth" => "17",
      "eighteenth" => "18",
      "nineteenth" => "19",
      "twentieth" => "20"
    }

    search = String.downcase(value)

    case Map.get(ordinals, search) do
      nil -> value
      x -> x
    end
  end

  @spec map_filter_out_empty_members(list()) :: list()
  def map_filter_out_empty_members(records) when is_list(records),
    do: Enum.map(records, &map_filter_out_empty_members(&1))

  @spec map_filter_out_empty_members(map()) :: map()
  def map_filter_out_empty_members(record) when is_map(record) do
    Map.filter(record, fn {_k, v} -> v not in [nil, "", []] end)
  end

  @spec maps_from_structs([]) :: []
  def maps_from_structs([]), do: []

  @spec maps_from_structs(list()) :: list()
  def maps_from_structs(records) when is_list(records) do
    Enum.map(records, &map_from_struct/1)
  end

  @spec map_from_struct(struct() | map()) :: map()
  def map_from_struct(record) when is_struct(record), do: Map.from_struct(record)
  def map_from_struct(record) when is_map(record), do: record

  @doc """
  Function to return the members
  """
  def delta_lists() do
    x = ExPrompt.get("Old List")
    y = ExPrompt.get("New List")

    delta_lists(String.split(x, ","), String.split(y, ","))
    |> Enum.sort(:desc)
    |> Enum.join(",")
  end

  @spec delta_lists(list(), list()) :: list()
  def delta_lists(old, new) do
    old = convert_to_mapset(old)
    new = convert_to_mapset(new)

    MapSet.difference(new, old)
    |> MapSet.to_list()
  end

  def convert_to_mapset(list) when list in [nil, ""], do: MapSet.new()

  def convert_to_mapset(csv) when is_binary(csv) do
    csv
    |> String.split(",")
    |> Enum.map(&String.trim(&1))
    |> MapSet.new()
  end

  def convert_to_mapset(list) when is_list(list) do
    Enum.map(list, &String.trim(&1))
    |> MapSet.new()
  end

  def year_as_integer(year) when is_integer(year), do: year
  def year_as_integer(year) when is_binary(year), do: String.to_integer(year)

  @spec to_utf8(binary()) :: String.t()
  def to_utf8(binary), do: to_utf8(binary, "")

  defp to_utf8(<<codepoint::utf8, rest::binary>>, acc) do
    to_utf8(rest, <<acc::binary, codepoint::utf8>>)
  end

  defp to_utf8("", acc), do: acc

  defp to_utf8(_, acc), do: acc
end
