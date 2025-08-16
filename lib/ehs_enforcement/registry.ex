defmodule EhsEnforcement.Registry do
  @moduledoc """
  Registry stub for EHS Enforcement application.
  In Ash 3.x, resources are managed by domains, not registries.
  This module provides compatibility for tests.
  """
  
  def entries do
    [
      {EhsEnforcement.Enforcement.Agency, %{}},
      {EhsEnforcement.Enforcement.Offender, %{}},
      {EhsEnforcement.Enforcement.Case, %{}},
      {EhsEnforcement.Enforcement.Notice, %{}},
      {EhsEnforcement.Enforcement.Legislation, %{}},
      {EhsEnforcement.Enforcement.Offence, %{}}
    ]
  end
end