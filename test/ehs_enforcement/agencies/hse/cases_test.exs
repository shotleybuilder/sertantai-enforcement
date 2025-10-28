defmodule EhsEnforcement.Agencies.Hse.CasesTest do
  # mix test test/ehs_enforcement/agencies/hse/cases_test.exs
  use ExUnit.Case, async: true
  alias EhsEnforcement.Agencies.Hse.Cases

  setup do
    # Ensure the module is loaded before testing
    Code.ensure_loaded(Cases)
    :ok
  end

  test "api_get_hse_cases/1" do
    # Test that the api function exists and accepts options
    # Function has default arguments so can be called with arity 0 or 1
    assert function_exported?(Cases, :api_get_hse_cases, 0)
    assert function_exported?(Cases, :api_get_hse_cases, 1)
  end

  test "api_get_hse_case_by_id/1" do
    # Test that the api function exists and accepts options
    # Function has default arguments so can be called with arity 0 or 1
    assert function_exported?(Cases, :api_get_hse_case_by_id, 0)
    assert function_exported?(Cases, :api_get_hse_case_by_id, 1)
  end
end
