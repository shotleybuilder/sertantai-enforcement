defmodule EhsEnforcement.Legislation.Taxa.Options do
  @moduledoc """
  Simplified options module for EHS enforcement taxa processing
  """

  def api_update_multi_lat_taxa(opts) do
    opts
  end

  def api_update_lat_taxa_from_text_opts(opts) do
    opts
  end

  def set_workflow_opts(opts) do
    Map.merge(
      %{
        filesave?: false,
        taxa_workflow: []
      },
      Enum.into(opts, %{})
    )
  end

  def patch(opts) do
    Map.merge(
      %{
        base_id: "",
        table_id: "",
        patch?: false
      },
      opts
    )
  end
end
