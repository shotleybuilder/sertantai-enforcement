defmodule EhsEnforcement.Integrations.Airtable.AtViews do
  @doc """

  """
  def at_views(%{table_name: "UK"}) do
    "BASIC"
  end

  def at_views(%{sector: "off"}) do
    "markdown_offshore"
  end
end
