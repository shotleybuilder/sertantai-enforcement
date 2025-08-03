#!/usr/bin/env elixir

# Quick script to check if case 4823792 was scraped successfully
Mix.install([])

# Set up the environment
Application.put_env(:phoenix, :json_library, Jason)

# Load the application
Code.require_file("mix.exs")
Mix.Task.run("app.start")

require Ash.Query
import Ash.Expr

# Check for case 4823792
case_id = "4823792"

case Ash.read(EhsEnforcement.Enforcement.Case, action: :read) do
  {:ok, cases} ->
    IO.puts("Total cases in database: #{length(cases)}")
    
    # Look for the specific case
    target_case = Enum.find(cases, fn case -> case.regulator_id == case_id end)
    
    if target_case do
      IO.puts("\n✅ SUCCESS: Case #{case_id} found in database!")
      IO.puts("Offender: #{target_case.offender_name}")
      IO.puts("Decision Date: #{target_case.decision_date}")
      IO.puts("Fine Amount: #{target_case.fine_amount}")
    else
      IO.puts("\n❌ Case #{case_id} NOT found in database")
      
      # Show some examples of what IS in the database
      IO.puts("\nFirst 5 cases in database:")
      cases
      |> Enum.take(5)
      |> Enum.each(fn case ->
        IO.puts("- #{case.regulator_id}: #{case.offender_name}")
      end)
    end
    
  {:error, error} ->
    IO.puts("Error reading cases: #{inspect(error)}")
end