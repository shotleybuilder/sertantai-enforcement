defmodule EhsEnforcementWeb.ConsentController do
  @moduledoc """
  Handles cookie consent form submissions.
  """
  use EhsEnforcementWeb, :controller
  alias EhsEnforcement.Consent.Storage

  @doc """
  Handles consent form submission from the consent modal.

  Saves consent to cookie and session, then redirects back to the referrer.
  """
  def create(conn, params) do
    # Parse consent groups from JSON
    groups = parse_groups(params)

    # Build consent data with expiration
    consent = build_consent(groups, params)

    # Save to cookie and database (for authenticated users)
    storage_opts = [
      resource: EhsEnforcement.Consent.ConsentSettings,
      user_id_key: :current_user
    ]

    conn = Storage.put_consent(conn, consent, storage_opts)

    # Redirect back to the referring page or home
    redirect_url = get_redirect_url(conn, params)

    conn
    |> put_flash(:info, "Your cookie preferences have been saved.")
    |> redirect(to: redirect_url)
  end

  defp parse_groups(%{"groups" => groups}) when is_list(groups), do: groups

  defp parse_groups(%{"groups" => json}) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, groups} when is_list(groups) -> groups
      _ -> ["essential"]
    end
  end

  defp parse_groups(_), do: ["essential"]

  defp build_consent(groups, params) do
    now = DateTime.utc_now() |> DateTime.truncate(:second)
    expires = DateTime.add(now, 365, :day) |> DateTime.truncate(:second)

    %{
      "terms" => Map.get(params, "terms", "v1.0"),
      "groups" => groups,
      "consented_at" => now,
      "expires_at" => expires
    }
  end

  defp get_redirect_url(conn, params) do
    # Try params first, then referer header, then fallback to "/"
    case Map.get(params, "redirect_to") do
      nil ->
        # Extract path from referer header (it returns full URL, we need just the path)
        case get_req_header(conn, "referer") |> List.first() do
          nil ->
            "/"

          referer_url ->
            case URI.parse(referer_url) do
              %URI{path: path} when is_binary(path) -> path
              _ -> "/"
            end
        end

      redirect_to ->
        redirect_to
    end
  end
end
