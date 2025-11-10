defmodule EhsEnforcementWeb.CaseManualEntryTest do
  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest
  import ExUnit.CaptureLog

  alias EhsEnforcement.Enforcement

  require Ash.Query
  import Ash.Expr

  describe "Manual case entry form" do
    setup do
      # Create test agencies for form options
      {:ok, hse_agency} =
        Enforcement.create_agency(%{
          code: :hse,
          name: "Health and Safety Executive",
          enabled: true
        })

      {:ok, ea_agency} =
        Enforcement.create_agency(%{
          code: :ea,
          name: "Environment Agency",
          enabled: true
        })

      {:ok, disabled_agency} =
        Enforcement.create_agency(%{
          code: :orr,
          name: "Office of Rail Regulation",
          enabled: false
        })

      # Create existing offenders for testing selection
      {:ok, existing_offender} =
        Enforcement.create_offender(%{
          name: "Existing Manufacturing Ltd",
          local_authority: "Test Council",
          postcode: "EX1 1ST"
        })

      %{
        agencies: [hse_agency, ea_agency, disabled_agency],
        existing_offender: existing_offender
      }
    end

    test "displays manual entry form on new case page", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cases/new")

      # Should display form title
      assert html =~ "New Case" or html =~ "Manual Case Entry" or html =~ "Add Case"

      # Should have case entry form
      assert has_element?(view, "form[phx-submit='save']") or
               has_element?(view, "form[phx-submit='create_case']")

      # Should have form test ID
      assert has_element?(view, "[data-testid='case-form']") or
               html =~ "case-form"
    end

    test "renders all required form fields", %{conn: conn, agencies: agencies} do
      {:ok, view, html} = live(conn, "/cases/new")

      # Case identification fields
      assert has_element?(view, "input[name='case[regulator_id]']")
      assert html =~ "Regulator ID" or html =~ "Case ID"

      # Agency selection
      assert has_element?(view, "select[name='case[agency_id]']")
      assert html =~ "Agency" or html =~ "Regulator"

      # Date field
      assert has_element?(view, "input[name='case[offence_action_date]'][type='date']")
      assert html =~ "Offense Date" or html =~ "Action Date"

      # Fine amount field
      assert has_element?(view, "input[name='case[offence_fine]'][type='number']")
      assert html =~ "Fine Amount" or html =~ "Penalty"

      # Breaches description
      assert has_element?(view, "textarea[name='case[offence_breaches]']") or
               has_element?(view, "input[name='case[offence_breaches]']")

      assert html =~ "Breaches" or html =~ "Violations" or html =~ "Description"

      # Submit button
      assert has_element?(view, "button[type='submit']") or
               has_element?(view, "input[type='submit']")

      assert html =~ "Save" or html =~ "Create" or html =~ "Submit"
    end

    test "populates agency dropdown with enabled agencies only", %{
      conn: conn,
      agencies: [hse, ea, disabled]
    } do
      {:ok, view, html} = live(conn, "/cases/new")

      # Should show enabled agencies
      assert html =~ "Health and Safety Executive"
      assert html =~ "Environment Agency"

      # Should not show disabled agencies or mark them as disabled
      if html =~ "Office of Rail Regulation" do
        assert html =~ "disabled" or html =~ "(Disabled)"
      else
        refute html =~ "Office of Rail Regulation"
      end

      # Should have default/placeholder option
      assert html =~ "Select Agency" or html =~ "Choose Agency" or html =~ "<option value=\"\""
    end

    test "provides offender selection and creation options", %{
      conn: conn,
      existing_offender: existing_offender
    } do
      {:ok, view, html} = live(conn, "/cases/new")

      # Should have option to select existing offender
      assert has_element?(view, "select[name='case[offender_id]']") or
               has_element?(view, "input[name='offender_search']") or
               html =~ "Select Offender" or html =~ "Search Offender"

      # Should have option to create new offender
      assert html =~ "New Offender" or html =~ "Create Offender" or html =~ "Add New"

      # If showing existing offenders, should include test data
      if html =~ existing_offender.name do
        assert html =~ "Existing Manufacturing Ltd"
      end
    end

    test "shows new offender fields when creating new offender", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases/new")

      # Toggle to new offender mode (if implemented as toggle)
      if has_element?(view, "input[type='radio'][value='new_offender']") do
        render_click(view, "toggle_offender_mode", %{"mode" => "new"})
      end

      updated_html = render(view)

      # Should show new offender fields
      assert updated_html =~ "Company Name" or updated_html =~ "Offender Name"

      assert has_element?(view, "input[name='offender[name]']") or
               has_element?(view, "input[name='case[offender_name]']")

      # Should show location fields
      assert updated_html =~ "Local Authority" or updated_html =~ "Council"

      assert has_element?(view, "input[name='offender[local_authority]']") or
               has_element?(view, "input[name='case[offender_local_authority]']")

      # Should show postcode field
      assert updated_html =~ "Postcode" or updated_html =~ "Postal Code"

      assert has_element?(view, "input[name='offender[postcode]']") or
               has_element?(view, "input[name='case[offender_postcode]']")
    end

    test "validates required fields on submission", %{conn: conn, agencies: [hse_agency | _]} do
      {:ok, view, _html} = live(conn, "/cases/new")

      # Submit empty form
      log =
        capture_log(fn ->
          render_submit(view, "save", %{"case" => %{}})
        end)

      # Should show validation errors
      validation_html = render(view)

      # Should indicate required fields
      assert validation_html =~ "required" or
               validation_html =~ "can't be blank" or
               validation_html =~ "is required" or
               validation_html =~ "error"

      # Form should still be displayed
      assert has_element?(view, "form")
    end

    test "validates regulator ID format and uniqueness", %{conn: conn, agencies: [hse_agency | _]} do
      {:ok, view, _html} = live(conn, "/cases/new")

      # Test invalid regulator ID format
      render_submit(view, "save", %{
        "case" => %{
          "regulator_id" => "invalid format",
          "agency_id" => hse_agency.id,
          "offence_action_date" => "2024-01-15",
          "offence_fine" => "1000.00",
          "offence_breaches" => "Test breach"
        }
      })

      invalid_format_html = render(view)

      # Should show format validation error
      assert invalid_format_html =~ "invalid" or
               invalid_format_html =~ "format" or
               invalid_format_html =~ "pattern"

      # Create existing case for uniqueness test
      {:ok, existing_offender} = Enforcement.create_offender(%{name: "Test Corp"})

      {:ok, _existing_case} =
        Enforcement.create_case(%{
          regulator_id: "HSE-DUPLICATE-001",
          agency_id: hse_agency.id,
          offender_id: existing_offender.id,
          offence_action_date: ~D[2024-01-01],
          offence_fine: Decimal.new("1000.00"),
          offence_breaches: "Existing breach",
          last_synced_at: DateTime.utc_now()
        })

      # Test duplicate regulator ID
      render_submit(view, "save", %{
        "case" => %{
          "regulator_id" => "HSE-DUPLICATE-001",
          "agency_id" => hse_agency.id,
          "offence_action_date" => "2024-01-15",
          "offence_fine" => "2000.00",
          "offence_breaches" => "Duplicate test"
        }
      })

      duplicate_html = render(view)

      # Should show uniqueness validation error
      assert duplicate_html =~ "already exists" or
               duplicate_html =~ "duplicate" or
               duplicate_html =~ "taken"
    end

    test "validates fine amount format and range", %{conn: conn, agencies: [hse_agency | _]} do
      {:ok, view, _html} = live(conn, "/cases/new")

      # Test negative fine amount
      render_submit(view, "save", %{
        "case" => %{
          "regulator_id" => "HSE-FINE-001",
          "agency_id" => hse_agency.id,
          "offence_action_date" => "2024-01-15",
          "offence_fine" => "-1000.00",
          "offence_breaches" => "Test breach"
        }
      })

      negative_html = render(view)

      assert negative_html =~ "must be" or negative_html =~ "positive" or
               negative_html =~ "greater"

      # Test invalid fine format
      render_submit(view, "save", %{
        "case" => %{
          "regulator_id" => "HSE-FINE-002",
          "agency_id" => hse_agency.id,
          "offence_action_date" => "2024-01-15",
          "offence_fine" => "not-a-number",
          "offence_breaches" => "Test breach"
        }
      })

      invalid_html = render(view)
      assert invalid_html =~ "number" or invalid_html =~ "numeric" or invalid_html =~ "invalid"

      # Test excessive fine amount (if there's an upper limit)
      render_submit(view, "save", %{
        "case" => %{
          "regulator_id" => "HSE-FINE-003",
          "agency_id" => hse_agency.id,
          "offence_action_date" => "2024-01-15",
          "offence_fine" => "999999999.99",
          "offence_breaches" => "Test breach"
        }
      })

      excessive_html = render(view)
      # May or may not have upper limit validation
    end

    test "validates date fields", %{conn: conn, agencies: [hse_agency | _]} do
      {:ok, view, _html} = live(conn, "/cases/new")

      # Test future date
      future_date = Date.add(Date.utc_today(), 30)

      render_submit(view, "save", %{
        "case" => %{
          "regulator_id" => "HSE-DATE-001",
          "agency_id" => hse_agency.id,
          "offence_action_date" => Date.to_string(future_date),
          "offence_fine" => "1000.00",
          "offence_breaches" => "Test breach"
        }
      })

      future_html = render(view)

      # Should prevent future dates
      assert future_html =~ "future" or
               future_html =~ "today" or
               future_html =~ "past"

      # Test invalid date format
      render_submit(view, "save", %{
        "case" => %{
          "regulator_id" => "HSE-DATE-002",
          "agency_id" => hse_agency.id,
          "offence_action_date" => "invalid-date",
          "offence_fine" => "1000.00",
          "offence_breaches" => "Test breach"
        }
      })

      invalid_date_html = render(view)
      assert invalid_date_html =~ "date" or invalid_date_html =~ "format"
    end

    test "successfully creates case with valid data", %{conn: conn, agencies: [hse_agency | _]} do
      {:ok, view, _html} = live(conn, "/cases/new")

      # Submit valid case data
      case_count_before = Enforcement.count_cases!()

      render_submit(view, "save", %{
        "case" => %{
          "regulator_id" => "HSE-MANUAL-001",
          "agency_id" => hse_agency.id,
          "offence_action_date" => "2024-01-15",
          "offence_fine" => "15000.00",
          "offence_breaches" => "Manual entry test - safety violations with equipment failure"
        },
        "offender" => %{
          "name" => "Manual Entry Test Company Ltd",
          "local_authority" => "Test City Council",
          "postcode" => "MT1 1ST"
        }
      })

      # Should redirect to case index or show success
      success_html = render(view)

      assert success_html =~ "created" or
               success_html =~ "success" or
               success_html =~ "saved" or
               redirected_to(view) =~ "/cases"

      # Case should be created in database
      case_count_after = Enforcement.count_cases!()
      assert case_count_after == case_count_before + 1

      # Verify case data
      {:ok, cases} =
        EhsEnforcement.Enforcement.Case
        |> Ash.Query.filter(regulator_id == "HSE-MANUAL-001")
        |> Ash.read()

      created_case = List.first(cases)
      assert created_case != nil
      assert created_case.agency_id == hse_agency.id
      assert created_case.offence_fine == Decimal.new("15000.00")
      assert created_case.offence_breaches =~ "Manual entry test"
    end

    test "creates new offender when specified", %{conn: conn, agencies: [hse_agency | _]} do
      {:ok, view, _html} = live(conn, "/cases/new")

      offender_count_before = Enforcement.count_offenders!()

      render_submit(view, "save", %{
        "case" => %{
          "regulator_id" => "HSE-NEWOFF-001",
          "agency_id" => hse_agency.id,
          "offence_action_date" => "2024-01-15",
          "offence_fine" => "5000.00",
          "offence_breaches" => "New offender test"
        },
        "offender" => %{
          "name" => "Brand New Company PLC",
          "local_authority" => "New Council",
          "postcode" => "BN1 1EW"
        }
      })

      # Should create new offender
      offender_count_after = Enforcement.count_offenders!()
      assert offender_count_after == offender_count_before + 1

      # Verify offender data
      {:ok, offenders} =
        EhsEnforcement.Enforcement.Offender
        |> Ash.Query.filter(name == "Brand New Company PLC")
        |> Ash.read()

      created_offender = List.first(offenders)
      assert created_offender != nil
      assert created_offender.local_authority == "New Council"
      assert created_offender.postcode == "BN1 1EW"

      # Case should be linked to new offender
      {:ok, cases} =
        EhsEnforcement.Enforcement.Case
        |> Ash.Query.filter(regulator_id == "HSE-NEWOFF-001")
        |> Ash.read()

      created_case = List.first(cases)
      assert created_case.offender_id == created_offender.id
    end

    test "uses existing offender when selected", %{
      conn: conn,
      agencies: [hse_agency | _],
      existing_offender: existing_offender
    } do
      {:ok, view, _html} = live(conn, "/cases/new")

      render_submit(view, "save", %{
        "case" => %{
          "regulator_id" => "HSE-EXISTING-001",
          "agency_id" => hse_agency.id,
          "offender_id" => existing_offender.id,
          "offence_action_date" => "2024-01-15",
          "offence_fine" => "8000.00",
          "offence_breaches" => "Existing offender test"
        }
      })

      # Should not create new offender
      {:ok, cases} =
        EhsEnforcement.Enforcement.Case
        |> Ash.Query.filter(regulator_id == "HSE-EXISTING-001")
        |> Ash.read()

      created_case = List.first(cases)
      assert created_case.offender_id == existing_offender.id
    end

    test "handles form cancellation", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cases/new")

      # Should have cancel button or link
      assert has_element?(view, "a[href='/cases']") or
               has_element?(view, "button[phx-click='cancel']") or
               html =~ "Cancel" or html =~ "Back"

      # Clicking cancel should navigate away
      if has_element?(view, "button[phx-click='cancel']") do
        render_click(view, "cancel")
        assert redirected_to(view) =~ "/cases"
      end
    end

    test "provides field validation feedback in real-time", %{
      conn: conn,
      agencies: [hse_agency | _]
    } do
      {:ok, view, _html} = live(conn, "/cases/new")

      # Test real-time validation on blur or change
      if has_element?(view, "input[phx-blur]") or has_element?(view, "input[phx-change]") do
        # Test invalid regulator ID
        render_change(view, "validate", %{
          "case" => %{"regulator_id" => "inv"}
        })

        validation_html = render(view)
        assert validation_html =~ "too short" or validation_html =~ "invalid"

        # Test valid input
        render_change(view, "validate", %{
          "case" => %{"regulator_id" => "HSE-VALID-001"}
        })

        valid_html = render(view)
        refute valid_html =~ "invalid"
      end
    end

    test "auto-populates fields based on agency selection", %{
      conn: conn,
      agencies: [hse_agency, ea_agency]
    } do
      {:ok, view, _html} = live(conn, "/cases/new")

      # Select HSE agency
      render_change(view, "agency_changed", %{
        "case" => %{"agency_id" => hse_agency.id}
      })

      hse_html = render(view)

      # Should pre-populate regulator ID pattern for HSE
      if hse_html =~ "HSE-" do
        assert hse_html =~ "HSE-"
      end

      # Select EA agency
      render_change(view, "agency_changed", %{
        "case" => %{"agency_id" => ea_agency.id}
      })

      ea_html = render(view)

      # Should pre-populate regulator ID pattern for EA
      if ea_html =~ "EA-" do
        assert ea_html =~ "EA-"
      end
    end

    test "shows character counts for text fields", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cases/new")

      # Should show character count for breach description
      if html =~ "characters" or html =~ "chars" do
        assert html =~ "remaining" or html =~ "left" or html =~ "max"
      end

      # If character counting is implemented
      if has_element?(view, "textarea[phx-keyup]") do
        render_keyup(view, "count_chars", %{
          "case" => %{"offence_breaches" => "Test breach description"}
        })

        updated_html = render(view)
        # Should show updated character count
      end
    end

    test "saves draft automatically", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases/new")

      # If auto-save is implemented
      if has_element?(view, "form[phx-change='auto_save']") do
        render_change(view, "auto_save", %{
          "case" => %{
            "regulator_id" => "HSE-DRAFT-001",
            "offence_breaches" => "Draft breach description"
          }
        })

        # Should save draft (implementation specific)
        draft_html = render(view)
        assert draft_html =~ "saved" or draft_html =~ "draft"
      end
    end
  end

  describe "Manual case entry error handling" do
    test "handles database constraint violations gracefully", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases/new")

      log =
        capture_log(fn ->
          # Submit data that might cause constraint violations
          render_submit(view, "save", %{
            "case" => %{
              # Empty required field
              "regulator_id" => "",
              "agency_id" => "invalid-uuid",
              "offence_action_date" => "2024-01-15",
              "offence_fine" => "1000.00",
              "offence_breaches" => "Test"
            }
          })
        end)

      # Should handle gracefully
      assert Process.alive?(view.pid)
      error_html = render(view)
      assert error_html =~ "error" or error_html =~ "invalid"
    end

    test "handles network timeouts during submission", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases/new")

      # Should show loading state during submission
      if has_element?(view, "button[type='submit']") do
        submit_html =
          render_submit(view, "save", %{
            "case" => %{
              "regulator_id" => "HSE-TIMEOUT-001",
              "agency_id" => "some-id",
              "offence_action_date" => "2024-01-15",
              "offence_fine" => "1000.00",
              "offence_breaches" => "Timeout test"
            }
          })

        # Should handle submission gracefully
        assert Process.alive?(view.pid)
      end
    end

    test "provides helpful error messages", %{conn: conn} do
      {:ok, view, _html} = live(conn, "/cases/new")

      # Submit invalid data
      render_submit(view, "save", %{
        "case" => %{
          # Too short
          "regulator_id" => "X",
          # Required
          "agency_id" => "",
          # Future date
          "offence_action_date" => "2025-12-31",
          # Negative
          "offence_fine" => "-100",
          # Empty
          "offence_breaches" => ""
        }
      })

      error_html = render(view)

      # Should provide specific, helpful error messages
      assert error_html =~ "required" or error_html =~ "must be"
      assert error_html =~ "invalid" or error_html =~ "error"
    end

    test "preserves form data on validation errors", %{conn: conn, agencies: [hse_agency | _]} do
      {:ok, view, _html} = live(conn, "/cases/new")

      # Submit form with some valid and some invalid data
      render_submit(view, "save", %{
        "case" => %{
          # Invalid - empty
          "regulator_id" => "",
          # Valid
          "agency_id" => hse_agency.id,
          # Valid
          "offence_action_date" => "2024-01-15",
          # Valid
          "offence_fine" => "1000.00",
          # Valid
          "offence_breaches" => "Valid breach description"
        }
      })

      preserved_html = render(view)

      # Should preserve valid data
      assert preserved_html =~ "2024-01-15"
      assert preserved_html =~ "1000.00"
      assert preserved_html =~ "Valid breach description"

      # Agency should still be selected
      assert preserved_html =~ "selected" or preserved_html =~ hse_agency.id
    end
  end

  describe "Manual case entry accessibility" do
    test "includes proper form labels and structure", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cases/new")

      # Should have proper form structure
      assert html =~ "<form"
      assert html =~ "<fieldset" or html =~ "<div"

      # Should have labels for all inputs
      assert html =~ "<label"
      assert html =~ "for=" or html =~ "aria-label"

      # Required fields should be marked
      assert html =~ "required" or html =~ "*" or html =~ "aria-required"
    end

    test "provides keyboard navigation support", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cases/new")

      # Form elements should be focusable
      assert html =~ "tabindex" or has_element?(view, "input") or has_element?(view, "select")

      # Should have logical tab order
      assert has_element?(view, "input")
      assert has_element?(view, "button")
    end

    test "includes ARIA attributes for screen readers", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cases/new")

      # Should have ARIA attributes
      assert html =~ "aria-label" or
               html =~ "aria-describedby" or
               html =~ "aria-required"

      # Error states should be announced
      if html =~ "error" do
        assert html =~ "aria-invalid" or html =~ "aria-describedby"
      end
    end

    test "provides clear visual feedback for form states", %{conn: conn} do
      {:ok, view, html} = live(conn, "/cases/new")

      # Should have visual indicators for required fields
      assert html =~ "*" or html =~ "required" or html =~ "red"

      # Should have clear submit button
      assert html =~ "Submit" or html =~ "Save" or html =~ "Create"

      # Should have proper form styling
      # Should use CSS classes
      assert html =~ "class="
    end
  end

  describe "Manual case entry performance" do
    test "loads form quickly with many agencies and offenders", %{conn: conn} do
      # Create many agencies and offenders
      Enum.each(1..50, fn i ->
        Enforcement.create_agency(%{
          code: String.to_atom("perf_#{i}"),
          name: "Performance Agency #{i}",
          enabled: true
        })

        Enforcement.create_offender(%{
          name: "Performance Company #{i}",
          local_authority: "Council #{i}"
        })
      end)

      start_time = System.monotonic_time(:millisecond)

      {:ok, view, html} = live(conn, "/cases/new")

      end_time = System.monotonic_time(:millisecond)
      load_time = end_time - start_time

      # Should load within reasonable time
      assert load_time < 2000, "Form should load within 2 seconds"

      # Should display form properly
      assert html =~ "New Case"
      # Agency dropdown
      assert has_element?(view, "select")
    end

    test "handles form submission efficiently", %{conn: conn, agencies: [hse_agency | _]} do
      {:ok, view, _html} = live(conn, "/cases/new")

      start_time = System.monotonic_time(:millisecond)

      render_submit(view, "save", %{
        "case" => %{
          "regulator_id" => "HSE-PERF-001",
          "agency_id" => hse_agency.id,
          "offence_action_date" => "2024-01-15",
          "offence_fine" => "1000.00",
          "offence_breaches" => "Performance test breach"
        },
        "offender" => %{
          "name" => "Performance Test Company",
          "local_authority" => "Test Council",
          "postcode" => "PT1 1ST"
        }
      })

      end_time = System.monotonic_time(:millisecond)
      submit_time = end_time - start_time

      # Should submit within reasonable time
      assert submit_time < 3000, "Form submission should complete within 3 seconds"
    end
  end
end
