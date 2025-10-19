# Configure ExUnit for robust concurrent testing
# See: .claude/sessions/2025-10-19-Test-Environment.md
ExUnit.start(
  # Limit concurrent test files to prevent resource exhaustion
  # With 8 CPU cores, default would be 16, but DB-heavy tests need more connections each
  # Temporarily reduced to 2 for Phase 2C verification (from 4)
  max_cases: 2,

  # Increase timeout for heavy operations (metrics refresh, complex queries)
  timeout: 120_000,  # 2 minutes

  # Exclude slow and integration tests by default for faster development cycles
  # Note: :heavy tests (like dashboard) are INCLUDED by default with limited max_cases
  # Run with: mix test --include slow --include integration
  # Or exclude heavy: mix test --exclude heavy
  exclude: [:integration, :slow]
)

Ecto.Adapters.SQL.Sandbox.mode(EhsEnforcement.Repo, :manual)

# Configure mock Airtable client for tests
Application.put_env(:ehs_enforcement, :airtable_client, EhsEnforcement.Test.AirtableMockClient)
