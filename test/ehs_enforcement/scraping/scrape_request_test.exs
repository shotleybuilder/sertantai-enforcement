defmodule EhsEnforcement.Scraping.ScrapeRequestTest do
  @moduledoc """
  Tests for ScrapeRequest resource to ensure form parameters are properly accepted.

  This test suite specifically covers the bug fix where the Start Page control
  was not being respected due to improper action configuration.
  """

  use EhsEnforcement.DataCase, async: true

  alias EhsEnforcement.Scraping.ScrapeRequest
  alias AshPhoenix.Form

  describe "ScrapeRequest resource" do
    test "accepts start_page parameter in create action" do
      # Test that we can create a ScrapeRequest with custom start_page
      assert {:ok, request} =
               Ash.create(ScrapeRequest, %{
                 start_page: 5,
                 max_pages: 10,
                 database: "convictions"
               })

      assert request.start_page == 5
      assert request.max_pages == 10
      assert request.database == "convictions"
    end

    test "accepts max_pages parameter in create action" do
      # Test that we can create a ScrapeRequest with custom max_pages
      assert {:ok, request} =
               Ash.create(ScrapeRequest, %{
                 start_page: 1,
                 max_pages: 25,
                 database: "notices"
               })

      assert request.start_page == 1
      assert request.max_pages == 25
      assert request.database == "notices"
    end

    test "accepts database parameter in create action" do
      # Test that we can create a ScrapeRequest with different database
      assert {:ok, request} =
               Ash.create(ScrapeRequest, %{
                 start_page: 1,
                 max_pages: 10,
                 database: "notices"
               })

      assert request.database == "notices"
    end

    test "validates start_page must be greater than 0" do
      # Test that validation works for start_page
      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(ScrapeRequest, %{
                 start_page: 0,
                 max_pages: 10,
                 database: "convictions"
               })

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(ScrapeRequest, %{
                 start_page: -1,
                 max_pages: 10,
                 database: "convictions"
               })
    end

    test "validates max_pages must be greater than 0 and less than or equal to 100" do
      # Test that validation works for max_pages
      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(ScrapeRequest, %{
                 start_page: 1,
                 max_pages: 0,
                 database: "convictions"
               })

      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(ScrapeRequest, %{
                 start_page: 1,
                 max_pages: 101,
                 database: "convictions"
               })
    end

    test "validates database must be valid option" do
      # Test that validation works for database
      assert {:error, %Ash.Error.Invalid{}} =
               Ash.create(ScrapeRequest, %{
                 start_page: 1,
                 max_pages: 10,
                 database: "invalid_database"
               })
    end

    test "uses default values when not provided" do
      # Test that default values work when attributes are not provided
      assert {:ok, request} = Ash.create(ScrapeRequest, %{})

      assert request.start_page == 1
      assert request.max_pages == 10
      assert request.database == "convictions"
    end
  end

  describe "AshPhoenix.Form integration" do
    test "form validates and submits with custom start_page" do
      # This test specifically covers the bug that was fixed:
      # Form validation and submission should respect user input values

      # Create form
      form = Form.for_create(ScrapeRequest, :create, as: "scrape_request", forms: [auto?: false])

      # Test params like those coming from the UI
      test_params = %{
        "start_page" => "7",
        "max_pages" => "15",
        "database" => "notices"
      }

      # Validate form
      validated_form = Form.validate(form, test_params)
      assert validated_form.valid?

      # Submit form - this is where the bug was occurring
      assert {:ok, request} = Form.submit(validated_form, params: test_params)

      # Critical assertion: start_page should be 7, not 1 (the default)
      assert request.start_page == 7
      assert request.max_pages == 15
      assert request.database == "notices"
    end

    test "form validation catches invalid start_page values" do
      form = Form.for_create(ScrapeRequest, :create, as: "scrape_request", forms: [auto?: false])

      # Test with invalid start_page
      invalid_params = %{
        "start_page" => "0",
        "max_pages" => "10",
        "database" => "convictions"
      }

      validated_form = Form.validate(form, invalid_params)

      # Form submission should fail with validation error
      assert {:error, form_with_errors} = Form.submit(validated_form, params: invalid_params)
      refute form_with_errors.valid?
    end

    test "form validation catches invalid max_pages values" do
      form = Form.for_create(ScrapeRequest, :create, as: "scrape_request", forms: [auto?: false])

      # Test with invalid max_pages (too high)
      invalid_params = %{
        "start_page" => "1",
        "max_pages" => "150",
        "database" => "convictions"
      }

      validated_form = Form.validate(form, invalid_params)

      # Form submission should fail with validation error
      assert {:error, form_with_errors} = Form.submit(validated_form, params: invalid_params)
      refute form_with_errors.valid?
    end

    test "form handles string to integer conversion properly" do
      # Test that form properly converts string inputs to integers
      form = Form.for_create(ScrapeRequest, :create, as: "scrape_request", forms: [auto?: false])

      string_params = %{
        "start_page" => "42",
        "max_pages" => "99",
        "database" => "convictions"
      }

      validated_form = Form.validate(form, string_params)
      assert {:ok, request} = Form.submit(validated_form, params: string_params)

      # Should be converted to integers
      assert request.start_page == 42
      assert request.max_pages == 99
      assert is_integer(request.start_page)
      assert is_integer(request.max_pages)
    end
  end

  describe "regression test for Start Page bug" do
    test "start page value is preserved through form validation and submission" do
      # This is the specific regression test for the bug that was fixed
      # where Start Page always reverted to 1 regardless of user input

      form = Form.for_create(ScrapeRequest, :create, as: "scrape_request", forms: [auto?: false])

      # Test various start page values that should be preserved
      test_cases = [
        {"5", 5},
        {"10", 10},
        {"25", 25},
        {"1", 1}
      ]

      Enum.each(test_cases, fn {input_value, expected_value} ->
        params = %{
          "start_page" => input_value,
          "max_pages" => "10",
          "database" => "convictions"
        }

        validated_form = Form.validate(form, params)
        assert {:ok, request} = Form.submit(validated_form, params: params)

        # The critical assertion: start_page should match user input, not default to 1
        assert request.start_page == expected_value,
               "Expected start_page to be #{expected_value} but got #{request.start_page}"
      end)
    end
  end
end
