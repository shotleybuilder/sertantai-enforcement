defmodule EhsEnforcement.Repo.Migrations.AddDataValidationConstraints do
  @moduledoc """
  R4.1: Add CHECK constraints for data validation

  These constraints ensure data integrity at the database level by preventing
  invalid data from being inserted:

  1. Financial values must be non-negative
  2. Dates must follow logical ordering

  This prevents data quality issues and catches validation errors before
  they reach application logic.
  """

  use Ecto.Migration

  def up do
    # Cases table CHECK constraints
    create constraint(:cases, :offence_fine_non_negative,
             check: "offence_fine IS NULL OR offence_fine >= 0",
             comment: "Fine amount must be non-negative"
           )

    create constraint(:cases, :offence_costs_non_negative,
             check: "offence_costs IS NULL OR offence_costs >= 0",
             comment: "Costs amount must be non-negative"
           )

    create constraint(:cases, :dates_logical_order,
             check:
               "offence_hearing_date IS NULL OR offence_action_date IS NULL OR offence_hearing_date >= offence_action_date",
             comment: "Hearing date must be on or after action date"
           )

    # Notices table CHECK constraints
    create constraint(:notices, :dates_logical_order,
             check:
               "compliance_date IS NULL OR notice_date IS NULL OR compliance_date >= notice_date",
             comment: "Compliance date must be on or after notice date"
           )

    create constraint(:notices, :operative_date_after_notice,
             check:
               "operative_date IS NULL OR notice_date IS NULL OR operative_date >= notice_date",
             comment: "Operative date must be on or after notice date"
           )
  end

  def down do
    # Drop constraints in reverse order
    drop_if_exists constraint(:notices, :operative_date_after_notice)
    drop_if_exists constraint(:notices, :dates_logical_order)
    drop_if_exists constraint(:cases, :dates_logical_order)
    drop_if_exists constraint(:cases, :offence_costs_non_negative)
    drop_if_exists constraint(:cases, :offence_fine_non_negative)
  end
end
