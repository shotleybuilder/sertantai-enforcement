# Script to remove corrupt HSE notices with EA-pattern regulator IDs
# These 48 records were incorrectly created on 2025-07-26 with 8-digit IDs
# HSE uses 9-digit IDs, so these are data corruption
#
# Usage: mix run priv/repo/scripts/remove_corrupt_hse_notices.exs

alias EhsEnforcement.Repo
alias EhsEnforcement.Enforcement.{Notice, Agency}
import Ecto.Query

IO.puts("========================================")
IO.puts("Corrupt HSE Notice Removal Script")
IO.puts("========================================\n")

# Find HSE agency
hse_agency = Repo.one!(from a in Agency, where: a.code == :hse)

IO.puts("Target: HSE notices with 8-digit regulator IDs (EA pattern)")
IO.puts("HSE should have 9-digit regulator IDs\n")

# Find all corrupt HSE notices (8-digit regulator IDs)
corrupt_notices_query =
  from n in Notice,
    where: n.agency_id == ^hse_agency.id,
    where: fragment("LENGTH(?) = 8", n.regulator_id),
    where: fragment("? ~ '^[0-9]+$'", n.regulator_id),
    order_by: [asc: n.regulator_id]

corrupt_notices = Repo.all(corrupt_notices_query)
total_count = length(corrupt_notices)

IO.puts("Found #{total_count} corrupt HSE notices\n")

if total_count == 0 do
  IO.puts("No corrupt notices found. Exiting.")
  System.halt(0)
end

# Show sample of corrupt records
IO.puts("Sample of corrupt records:")

Enum.take(corrupt_notices, 5)
|> Enum.each(fn notice ->
  IO.puts(
    "  - ID: #{String.slice(notice.id, 0, 8)}... | Regulator ID: #{notice.regulator_id} | URL: #{inspect(notice.url)} | Created: #{notice.inserted_at}"
  )
end)

if total_count > 5 do
  IO.puts("  ... and #{total_count - 5} more")
end

IO.puts("\n")

# Check which ones are causing duplicate detection issues
duplicates_query =
  from n in Notice,
    join: a in Agency,
    on: n.agency_id == a.id,
    where: n.regulator_id in ^Enum.map(corrupt_notices, & &1.regulator_id),
    group_by: n.regulator_id,
    having: count(fragment("DISTINCT ?", a.code)) > 1,
    select: {n.regulator_id, count(fragment("DISTINCT ?", a.code))}

duplicates = Repo.all(duplicates_query)
IO.puts("#{length(duplicates)} corrupt records are causing cross-agency duplicate detection:")

Enum.each(duplicates, fn {regulator_id, agency_count} ->
  IO.puts("  - Regulator ID #{regulator_id} appears in #{agency_count} different agencies")
end)

IO.puts("\n")
IO.puts("🗑️  Deleting #{total_count} corrupt HSE notices...")
IO.puts("")

results =
  Enum.map(corrupt_notices, fn notice ->
    case Repo.delete(notice) do
      {:ok, _deleted} ->
        {:ok, notice.id}

      {:error, changeset} ->
        IO.puts(
          "  ✗ Failed to delete #{String.slice(notice.id, 0, 8)}...: #{inspect(changeset.errors)}"
        )

        {:error, notice.id}
    end
  end)

deleted_count = Enum.count(results, &match?({:ok, _}, &1))
failed_count = Enum.count(results, &match?({:error, _}, &1))

IO.puts("\n========================================")
IO.puts("Summary:")
IO.puts("  Total corrupt notices found: #{total_count}")
IO.puts("  Successfully deleted: #{deleted_count}")
IO.puts("  Failed to delete: #{failed_count}")
IO.puts("  Duplicate detection issues resolved: #{length(duplicates)}")
IO.puts("========================================\n")

if deleted_count == total_count do
  IO.puts("✅ All corrupt HSE notices successfully removed!")
else
  IO.puts("⚠️  Some deletions failed. Please review errors above.")
end
