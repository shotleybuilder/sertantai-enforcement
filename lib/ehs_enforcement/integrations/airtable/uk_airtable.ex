defmodule EhsEnforcement.Integrations.Airtable.UkAirtable do
  alias EhsEnforcement.Integrations.Airtable.AtBasesTables
  alias EhsEnforcement.Integrations.Airtable.Records
  alias EhsEnforcement.Legislation.LegalRegister
  alias EhsEnforcement.Legislation.Taxa.LATTaxa

  @type opts :: %{
          base_id: String.t(),
          table: String.t(),
          view: String.t(),
          fields: list(String.t()),
          formula: String.t()
        }

  @spec get_legal_register_records(opts()) :: list(LegalRegister.legal_register())
  def get_legal_register_records(opts) do
    get_records_from_at(opts)
    |> elem(1)
    |> Jason.encode!()
    |> Jason.decode!(keys: :atoms)
    |> strip_id_and_createdtime_fields()
    |> make_records_into_legal_register_structs()
  end

  @spec get_legal_article_taxa_records(opts()) :: list(LegalRegister.legal_register())
  def get_legal_article_taxa_records(opts) do
    get_records_from_at(opts)
    |> elem(1)
    |> Jason.encode!()
    |> Jason.decode!(keys: :atoms)
    |> strip_id_and_createdtime_fields()
    |> make_records_into_legal_article_taxa_structs()
  end

  @spec get_legal_interpretation_records(opts()) :: list()
  def get_legal_interpretation_records(opts) do
    get_records_from_at(opts)
    |> elem(1)
    |> Jason.encode!()
    |> Jason.decode!(keys: :atoms)
    |> move_id_and_drop_createdtime_field()
  end

  @doc """

  """
  @spec get_records_from_at({:params, opts()}) :: {:ok, list()} | :ok
  def get_records_from_at({:params, params}) do
    with(
      # IO.inspect(params),
      {:ok, {_, recordset}} <- Records.get_records({[], []}, params)
    ) do
      IO.puts("\n#{Enum.count(recordset)} Records returned from Airtable")
      {:ok, recordset}
    else
      {:error, error} ->
        IO.inspect(error)
    end
  end

  @spec get_records_from_at(opts()) :: {:ok, list()} | :ok
  def get_records_from_at(%{base_id: _} = opts) do
    with(
      params = %{
        base: opts.base_id,
        table: opts.table_id,
        options: %{
          view: opts.view,
          fields: opts.fields,
          formula: opts.formula
        }
      },
      # IO.inspect(params),
      {:ok, {_, recordset}} <- Records.get_records({[], []}, params)
    ) do
      IO.puts("\n#{Enum.count(recordset)} Records returned from Airtable")
      {:ok, recordset}
    else
      {:error, error} ->
        IO.inspect(error)
    end
  end

  def get_records_from_at(%{base_name: base_name} = opts) do
    {:ok, {base_id, table_id}} = AtBasesTables.get_base_table_id(base_name)
    opts = Map.merge(opts, %{base_id: base_id, table_id: table_id})
    get_records_from_at(opts)
  end

  @doc """
  Receives the records returned from an Airtable GET request
  Returns a list of maps with :id, :createdtime and :fields members removed
  """
  @spec strip_id_and_createdtime_fields(list()) :: list()
  def strip_id_and_createdtime_fields(records) do
    Enum.map(records, fn %{fields: fields} = _record -> fields end)
  end

  @doc """
  Receives the records returned from an Airtable GET request
  Returns a list of maps with :id in fields, :createdtime and :fields members removed
  """
  @spec move_id_and_drop_createdtime_field(list()) :: list()
  def move_id_and_drop_createdtime_field(records) do
    Enum.map(records, fn %{id: id, fields: fields} = _record ->
      Map.put(fields, :record_id, id)
    end)
  end

  @spec make_records_into_legal_register_structs(list()) :: list(LegalRegister.legal_register())
  def make_records_into_legal_register_structs(records) do
    Enum.map(records, &Kernel.struct(%LegalRegister{}, &1))
  end

  @spec make_records_into_legal_article_taxa_structs(list()) :: list(LATTaxa.legal_register())
  def make_records_into_legal_article_taxa_structs(records) do
    Enum.map(records, &Kernel.struct(%LATTaxa{}, &1))
  end

  def enumerate_at_records({file, records}, func) do
    Enum.each(records, fn x ->
      fields = Map.get(x, "fields")
      IO.puts("#{fields["Title_EN"]}")

      with(:ok <- func.(file, fields)) do
        :ok
      end
    end)

    {:ok, "records saved to .csv"}
  end

  def enumerate_at_records(records, opts, func) do
    # IO.inspect(records, limit: :infinity)
    Enum.each(records, fn %{"fields" => fields} = _record ->
      %{"Name" => name, "Title_EN" => title} = fields
      IO.puts("#{title}")
      [_, _, field] = opts.fields_source
      {:ok, path} = EhsEnforcement.Utility.resource_path(Map.get(fields, field))

      with(:ok <- func.(name, path, opts)) do
        :ok
      else
        {:error, :html} ->
          IO.puts(".html from #{fields["Title_EN"]}")

        {:error, error} ->
          IO.puts("ERROR #{error} with #{fields["Title_EN"]}")
      end
    end)

    {:ok, "metadata properties saved to csv"}
  end
end
