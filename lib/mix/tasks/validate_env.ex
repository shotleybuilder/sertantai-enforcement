defmodule Mix.Tasks.ValidateEnv do
  @moduledoc """
  Validates that all required environment variables are set for production deployment.

  ## Usage

      mix validate_env

  ## Exit Codes

  - 0: All required variables are set
  - 1: One or more required variables are missing
  """

  use Mix.Task

  @required_vars [
    "GITHUB_CLIENT_ID",
    "GITHUB_CLIENT_SECRET",
    "TOKEN_SIGNING_SECRET",
    "SECRET_KEY_BASE",
    "DATABASE_URL"
  ]

  @admin_vars [
    # Method 1: Repository-based
    ["GITHUB_REPO_OWNER", "GITHUB_REPO_NAME", "GITHUB_ACCESS_TOKEN"],
    # Method 2: Allow list
    ["GITHUB_ALLOWED_USERS"]
  ]

  @optional_vars [
    "GITHUB_REDIRECT_URI",
    "PHX_HOST",
    "PORT"
  ]

  @impl Mix.Task
  def run(_args) do
    IO.puts("\n🔍 Validating Environment Configuration...\n")

    # Check required variables
    missing_required = check_required_vars()

    # Check admin configuration
    admin_configured = check_admin_vars()

    # Check optional variables
    check_optional_vars()

    # Summary
    IO.puts("\n" <> String.duplicate("=", 60))

    cond do
      missing_required != [] ->
        IO.puts("❌ VALIDATION FAILED")
        IO.puts("\nMissing required variables:")
        Enum.each(missing_required, fn var -> IO.puts("  - #{var}") end)
        System.halt(1)

      not admin_configured ->
        IO.puts("⚠️  VALIDATION WARNING")
        IO.puts("\nNo admin configuration detected. Admin features will be disabled.")
        IO.puts("Set one of the following:")
        IO.puts("  Method 1: GITHUB_REPO_OWNER, GITHUB_REPO_NAME, GITHUB_ACCESS_TOKEN")
        IO.puts("  Method 2: GITHUB_ALLOWED_USERS=user1,user2,user3")
        System.halt(0)

      true ->
        IO.puts("✅ VALIDATION PASSED")
        IO.puts("\nAll required environment variables are configured correctly.")
        System.halt(0)
    end
  end

  defp check_required_vars do
    IO.puts("📋 Required Variables:")

    missing = Enum.filter(@required_vars, fn var ->
      value = System.get_env(var)
      status = if is_nil(value) or value == "", do: "❌ MISSING", else: "✅ SET"
      display_value = if is_nil(value) or value == "", do: "", else: " (#{mask_value(value)})"
      IO.puts("  #{status} #{var}#{display_value}")

      is_nil(value) or value == ""
    end)

    missing
  end

  defp check_admin_vars do
    IO.puts("\n🔐 Admin Authorization Configuration:")

    configured = Enum.any?(@admin_vars, fn var_group ->
      all_set = Enum.all?(var_group, fn var ->
        value = System.get_env(var)
        not is_nil(value) and value != ""
      end)

      if all_set do
        method = if length(var_group) == 3, do: "Repository-based", else: "Allow list"
        IO.puts("  ✅ #{method} (#{Enum.join(var_group, ", ")})")
      end

      all_set
    end)

    if not configured do
      IO.puts("  ❌ No admin configuration detected")
    end

    configured
  end

  defp check_optional_vars do
    IO.puts("\n📝 Optional Variables:")

    Enum.each(@optional_vars, fn var ->
      value = System.get_env(var)

      case value do
        nil ->
          IO.puts("  ⚪ #{var} (not set, will use default)")
        "" ->
          IO.puts("  ⚪ #{var} (empty, will use default)")
        val ->
          IO.puts("  ✅ #{var} (#{mask_value(val)})")
      end
    end)
  end

  defp mask_value(value) when is_binary(value) do
    cond do
      String.length(value) <= 8 ->
        String.duplicate("*", String.length(value))
      String.starts_with?(value, "http") ->
        value
      true ->
        prefix = String.slice(value, 0..3)
        suffix = String.slice(value, -4..-1//1)
        "#{prefix}...#{suffix}"
    end
  end
end
