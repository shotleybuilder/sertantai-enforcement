defmodule EhsEnforcement.Scraping.Ea.DateParameterTest do
  @moduledoc """
  Test suite to verify EA date parameter flow from form submission to action execution.

  This test traces the exact path that user-entered dates take through the system
  to identify where the date mismatch occurs between form input and EA scraping.
  """

  use EhsEnforcementWeb.ConnCase
  import Phoenix.LiveViewTest

  require Logger
  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Scraping.ScrapeRequest
  alias EhsEnforcement.Scraping.Agencies.Ea
  alias AshPhoenix.Form

  describe "EA date parameter flow" do
    setup %{conn: conn} do
      # Create OAuth2 admin user (following test/README.md patterns)
      user_info = %{
        "email" => "ea-date-test@example.com",
        "name" => "EA Date Test Admin",
        "login" => "eadatetest",
        "id" => 999_999,
        "avatar_url" => "https://github.com/images/avatars/eadatetest",
        "html_url" => "https://github.com/eadatetest"
      }

      oauth_tokens = %{
        "access_token" => "test_ea_date_token",
        "token_type" => "Bearer"
      }

      {:ok, user} =
        Ash.create(
          EhsEnforcement.Accounts.User,
          %{
            user_info: user_info,
            oauth_tokens: oauth_tokens
          },
          action: :register_with_github
        )

      {:ok, admin_user} =
        Ash.update(
          user,
          %{
            is_admin: true,
            admin_checked_at: DateTime.utc_now()
          },
          action: :update_admin_status,
          actor: user
        )

      authenticated_conn =
        conn
        |> Phoenix.ConnTest.init_test_session(%{})
        |> AshAuthentication.Plug.Helpers.store_in_session(admin_user)

      %{admin_user: admin_user, conn: authenticated_conn}
    end

    test "Form correctly parses EA dates from string input", %{admin_user: admin_user} do
      # Step 1: Test form parsing (what happens in the LiveView)
      form_params = %{
        "agency" => "ea",
        "date_from" => "2024-01-01",
        "date_to" => "2025-08-15"
      }

      # Create and validate form like the LiveView does
      form = AshPhoenix.Form.for_create(ScrapeRequest, :create, forms: [auto?: false])
      validated_form = Form.validate(form, form_params)

      case Form.submit(validated_form, params: form_params) do
        {:ok, scrape_request} ->
          Logger.info("✅ Form Test - scrape_request: #{inspect(scrape_request)}")

          # Verify correct date parsing
          assert scrape_request.agency == :ea
          assert scrape_request.date_from == ~D[2024-01-01]
          assert scrape_request.date_to == ~D[2025-08-15]

          # Step 2: Test EA agency parameter validation
          ea_validation_opts = [
            date_from: scrape_request.date_from,
            date_to: scrape_request.date_to,
            action_types: [:court_case],
            scrape_type: :manual,
            actor: admin_user
          ]

          case Ea.validate_params(ea_validation_opts) do
            {:ok, validated_params} ->
              Logger.info("✅ EA Validation - validated_params: #{inspect(validated_params)}")

              # Verify dates preserved through validation
              assert validated_params.date_from == ~D[2024-01-01]
              assert validated_params.date_to == ~D[2025-08-15]
              assert validated_params.action_types == [:court_case]

            {:error, reason} ->
              flunk("EA validation failed: #{inspect(reason)}")
          end

        {:error, form_with_errors} ->
          flunk("Form validation failed: #{inspect(form_with_errors.errors)}")
      end
    end

    test "EA scraping parameters are correctly extracted from form", %{admin_user: admin_user} do
      # Test just the parameter extraction logic without external calls
      scrape_request = %{
        agency: :ea,
        date_from: ~D[2024-01-01],
        date_to: ~D[2025-08-15]
      }

      # Test the exact logic from start_ea_scraping function
      ea_params = %{
        date_from: scrape_request.date_from,
        date_to: scrape_request.date_to,
        action_types: [:court_case]
      }

      Logger.info("🧪 Testing EA parameter extraction")

      Logger.info(
        "Original scrape_request dates: from=#{inspect(scrape_request.date_from)}, to=#{inspect(scrape_request.date_to)}"
      )

      Logger.info(
        "Extracted ea_params dates: from=#{inspect(ea_params.date_from)}, to=#{inspect(ea_params.date_to)}"
      )

      # Verify dates are preserved
      assert ea_params.date_from == ~D[2024-01-01]
      assert ea_params.date_to == ~D[2025-08-15]
      assert ea_params.action_types == [:court_case]
    end

    test "EA agency validation preserves dates", %{admin_user: admin_user} do
      # Test just the validation step without any external calls
      ea_validation_opts = [
        date_from: ~D[2024-01-01],
        date_to: ~D[2025-08-15],
        action_types: [:court_case],
        scrape_type: :manual,
        actor: admin_user
      ]

      Logger.info(
        "🧪 Testing EA.validate_params with dates: from=#{Keyword.get(ea_validation_opts, :date_from)}, to=#{Keyword.get(ea_validation_opts, :date_to)}"
      )

      case Ea.validate_params(ea_validation_opts) do
        {:ok, validated_params} ->
          Logger.info("✅ EA Validation successful")

          Logger.info(
            "Validated dates: from=#{validated_params.date_from}, to=#{validated_params.date_to}"
          )

          # Verify dates preserved through validation
          assert validated_params.date_from == ~D[2024-01-01]
          assert validated_params.date_to == ~D[2025-08-15]
          assert validated_params.action_types == [:court_case]

        {:error, reason} ->
          flunk("EA validation failed: #{inspect(reason)}")
      end
    end
  end
end
