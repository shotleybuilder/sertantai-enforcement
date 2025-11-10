defmodule EhsEnforcement.Integrations.Airtable.Headers do
  def headers do
    [
      {:accept, "application/json"},
      {:Authorization, "Bearer #{token()}"}
    ]
  end

  defp token, do: System.get_env("AT_UK_E_API_KEY")
end
