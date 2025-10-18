defmodule Mix.Tasks.DebugAdmin do
  @moduledoc """
  Debug admin configuration and check if a user would be recognized as admin.

  ## Usage

      mix debug_admin <github_username>
  """

  use Mix.Task

  @impl Mix.Task
  def run(args) do
    Application.ensure_all_started(:ehs_enforcement)

    github_login = List.first(args)

    if is_nil(github_login) or github_login == "" do
      IO.puts("\nUsage: mix debug_admin <github_username>")
      IO.puts("Example: mix debug_admin shotleybuilder\n")
      System.halt(1)
    end

    IO.puts("\n🔍 Admin Configuration Debug")
    IO.puts(String.duplicate("=", 60))

    # Get the admin config
    config = Application.get_env(:ehs_enforcement, :github_admin, %{})

    IO.puts("\n📋 Configuration Type: #{inspect(is_list(config))}")

    if is_list(config) do
      owner = Keyword.get(config, :owner)
      repo = Keyword.get(config, :repo)
      access_token = Keyword.get(config, :access_token)
      allowed_users = Keyword.get(config, :allowed_users, [])

      IO.puts("\n🔧 Configuration Values:")
      IO.puts("  GITHUB_REPO_OWNER: #{inspect(owner)}")
      IO.puts("  GITHUB_REPO_NAME: #{inspect(repo)}")
      IO.puts("  GITHUB_ACCESS_TOKEN: #{if access_token, do: "[SET (#{String.length(access_token)} chars)]", else: "[NOT SET]"}")
      IO.puts("  GITHUB_ALLOWED_USERS: #{inspect(allowed_users)}")

      IO.puts("\n👤 Checking user: #{github_login}")

      result =
        cond do
          not is_nil(access_token) and not is_nil(owner) and not is_nil(repo) ->
            IO.puts("\n✓ Using repository-based admin check")
            IO.puts("  Checking if '#{github_login}' is a collaborator on #{owner}/#{repo}...")
            check_repo_access(github_login, owner, repo, access_token)

          is_list(allowed_users) and length(allowed_users) > 0 ->
            IO.puts("\n✓ Using allow list admin check")
            IO.puts("  Allowed users: #{inspect(allowed_users)}")
            is_admin = github_login in allowed_users

            if is_admin do
              IO.puts("  ✅ '#{github_login}' IS in the allow list")
            else
              IO.puts("  ❌ '#{github_login}' is NOT in the allow list")
              IO.puts("\n  💡 Tip: Check for:")
              IO.puts("     - Exact match (case sensitive)")
              IO.puts("     - Extra spaces: #{inspect(Enum.map(allowed_users, &String.trim/1))}")
              IO.puts("     - Your actual GitHub username may differ from what you think")
            end

            is_admin

          true ->
            IO.puts("\n❌ No admin configuration method is active")
            IO.puts("  You need to set either:")
            IO.puts("    - GITHUB_ALLOWED_USERS=username1,username2")
            IO.puts("    OR")
            IO.puts("    - GITHUB_REPO_OWNER + GITHUB_REPO_NAME + GITHUB_ACCESS_TOKEN")
            false
        end

      IO.puts("\n" <> String.duplicate("=", 60))
      IO.puts("🎯 Result: #{if result, do: "✅ ADMIN", else: "❌ NOT ADMIN"}")
      IO.puts(String.duplicate("=", 60) <> "\n")
    else
      IO.puts("\n❌ Admin config is not a keyword list!")
      IO.puts("  Config value: #{inspect(config)}")
      IO.puts("\n  This usually means the config is not set properly.")
    end
  end

  defp check_repo_access(username, owner, repo, access_token) do
    url = "https://api.github.com/repos/#{owner}/#{repo}/collaborators/#{username}"

    headers = [
      {"Authorization", "token #{access_token}"},
      {"Accept", "application/vnd.github.v3+json"},
      {"User-Agent", "EHS-Enforcement-App"}
    ]

    case Req.get(url, headers: headers) do
      {:ok, %{status: 204}} ->
        IO.puts("  ✅ User IS a collaborator")
        true

      {:ok, %{status: 404}} ->
        IO.puts("  ❌ User is NOT a collaborator (or repo not found)")
        false

      {:ok, %{status: status}} ->
        IO.puts("  ❌ Unexpected status: #{status}")
        false

      {:error, reason} ->
        IO.puts("  ❌ API call failed: #{inspect(reason)}")
        false
    end
  rescue
    error ->
      IO.puts("  ❌ Error: #{inspect(error)}")
      false
  end
end
