defmodule EhsEnforcement.Integrations.CompaniesHouse do
  @moduledoc """
  Client for the Companies House API.

  Provides functions to lookup company information by registration number,
  validate company names, and retrieve registered office addresses.

  ## Configuration

  Requires `COMPANIES_HOUSE_API_KEY` environment variable to be set.

  ## API Documentation

  - Base URL: https://api.company-information.service.gov.uk
  - Rate Limit: 600 requests per 5 minutes (2/second) - free tier
  - Authentication: Basic auth with API key as username, empty password
  - Docs: https://developer.company-information.service.gov.uk/

  ## Examples

      iex> CompaniesHouse.lookup_company("03353423")
      {:ok, %{
        "company_name" => "SUNDORNE PRODUCTS (LLANIDLOES) LIMITED",
        "company_number" => "03353423",
        "company_status" => "active",
        "registered_office_address" => %{
          "address_line_1" => "...",
          "locality" => "...",
          "postal_code" => "..."
        }
      }}

      iex> CompaniesHouse.validate_company("03353423", "Sundorne Products")
      {:ok, %{valid: true, similarity: 0.92, canonical_name: "SUNDORNE PRODUCTS (LLANIDLOES) LIMITED"}}
  """

  require Logger

  @base_url "https://api.company-information.service.gov.uk"
  @timeout 10_000

  @doc """
  Lookup company information by registration number.

  Returns company profile including name, status, and registered office address.

  ## Parameters

  - `company_number` - Company registration number (will be cleaned automatically)

  ## Returns

  - `{:ok, company_profile}` - Company information map
  - `{:error, :not_found}` - Company number not found
  - `{:error, :unauthorized}` - API key missing or invalid
  - `{:error, :rate_limited}` - Rate limit exceeded
  - `{:error, reason}` - Other error
  """
  def lookup_company(company_number) when is_binary(company_number) do
    cleaned_number = clean_company_number(company_number)

    if cleaned_number == nil or cleaned_number == "" do
      {:error, :invalid_company_number}
    else
      url = "#{@base_url}/company/#{cleaned_number}"

      case make_request(url) do
        {:ok, %{status: 200, body: body}} ->
          {:ok, body}

        {:ok, %{status: 401}} ->
          Logger.error("Companies House API: Unauthorized - check API key")
          {:error, :unauthorized}

        {:ok, %{status: 404}} ->
          Logger.debug("Companies House API: Company #{cleaned_number} not found")
          {:error, :not_found}

        {:ok, %{status: 429}} ->
          Logger.warning("Companies House API: Rate limit exceeded")
          {:error, :rate_limited}

        {:ok, %{status: status}} ->
          Logger.error("Companies House API: Unexpected status #{status}")
          {:error, {:http_error, status}}

        {:error, reason} = error ->
          Logger.error("Companies House API request failed: #{inspect(reason)}")
          error
      end
    end
  end

  def lookup_company(nil), do: {:error, :invalid_company_number}
  def lookup_company(_), do: {:error, :invalid_company_number}

  @doc """
  Search for companies by name.

  Returns a list of matching companies with their registration numbers.

  ## Parameters

  - `company_name` - Company name to search for
  - `opts` - Options:
    - `:items_per_page` - Number of results (default: 5)
    - `:start_index` - Starting index (default: 0)

  ## Returns

  - `{:ok, [%{company_name: string, company_number: string, company_status: string, address_snippet: string}]}`
  - `{:error, reason}`

  ## Examples

      iex> search_companies("SUNDORNE PRODUCTS")
      {:ok, [
        %{
          company_name: "SUNDORNE PRODUCTS (LLANIDLOES) LIMITED",
          company_number: "03353423",
          company_status: "active",
          address_snippet: "..."
        }
      ]}
  """
  def search_companies(company_name, opts \\ [])

  def search_companies(company_name, opts) when is_binary(company_name) do
    items_per_page = Keyword.get(opts, :items_per_page, 5)
    start_index = Keyword.get(opts, :start_index, 0)

    url = "#{@base_url}/search/companies"

    query_params = [
      q: company_name,
      items_per_page: items_per_page,
      start_index: start_index
    ]

    case make_request_with_params(url, query_params) do
      {:ok, %{status: 200, body: body}} ->
        companies =
          body["items"]
          |> List.wrap()
          |> Enum.map(fn item ->
            %{
              company_name: item["company_name"],
              company_number: item["company_number"],
              company_status: item["company_status"],
              address_snippet: item["address_snippet"],
              company_type: item["company_type"]
            }
          end)

        {:ok, companies}

      {:ok, %{status: 401}} ->
        Logger.error("Companies House API: Unauthorized - check API key")
        {:error, :unauthorized}

      {:ok, %{status: 429}} ->
        Logger.warning("Companies House API: Rate limit exceeded")
        {:error, :rate_limited}

      {:ok, %{status: status}} ->
        Logger.error("Companies House API search: Unexpected status #{status}")
        {:error, {:http_error, status}}

      {:error, reason} = error ->
        Logger.error("Companies House API search failed: #{inspect(reason)}")
        error
    end
  end

  def search_companies(nil, _opts), do: {:error, :invalid_company_name}
  def search_companies("", _opts), do: {:error, :invalid_company_name}

  @doc """
  Validate that a company number matches an expected name.

  Uses fuzzy matching (Jaro-Winkler distance) to compare scraped name
  against the canonical name from Companies House.

  ## Parameters

  - `company_number` - Company registration number
  - `expected_name` - Name to validate against (from scraped data)
  - `opts` - Options:
    - `:threshold` - Minimum similarity score (default: 0.85)

  ## Returns

  - `{:ok, %{valid: true, similarity: float, canonical_name: string}}` - Name matches
  - `{:ok, %{valid: false, similarity: float, canonical_name: string}}` - Name doesn't match
  - `{:error, reason}` - Lookup failed
  """
  def validate_company(company_number, expected_name, opts \\ []) do
    threshold = Keyword.get(opts, :threshold, 0.85)

    case lookup_company(company_number) do
      {:ok, company} ->
        canonical_name = company["company_name"]
        similarity = calculate_similarity(expected_name, canonical_name)
        valid = similarity >= threshold

        if not valid do
          Logger.warning(
            "Company name mismatch: expected '#{expected_name}', " <>
              "got '#{canonical_name}' (similarity: #{Float.round(similarity, 2)})"
          )
        end

        {:ok,
         %{
           valid: valid,
           similarity: similarity,
           canonical_name: canonical_name,
           company_status: company["company_status"],
           registered_office_address: company["registered_office_address"]
         }}

      {:error, reason} = error ->
        Logger.error("Company validation failed for #{company_number}: #{inspect(reason)}")
        error
    end
  end

  @doc """
  Extract registered office address from company profile.

  Returns a formatted address string suitable for the Offender resource.
  """
  def format_registered_office(company_profile) when is_map(company_profile) do
    case company_profile["registered_office_address"] do
      nil ->
        nil

      address ->
        [
          address["address_line_1"],
          address["address_line_2"],
          address["locality"],
          address["region"],
          address["postal_code"]
        ]
        |> Enum.filter(&(&1 != nil and &1 != ""))
        |> Enum.join(", ")
    end
  end

  def format_registered_office(_), do: nil

  @doc """
  Extract address components from company profile for Offender fields.

  Returns a map with `:address`, `:town`, `:county`, `:postcode` keys.
  """
  def extract_address_components(company_profile) when is_map(company_profile) do
    case company_profile["registered_office_address"] do
      nil ->
        %{}

      address ->
        %{
          address: address["address_line_1"],
          town: address["locality"],
          county: address["region"],
          postcode: address["postal_code"]
        }
        |> Enum.reject(fn {_k, v} -> v == nil or v == "" end)
        |> Map.new()
    end
  end

  def extract_address_components(_), do: %{}

  @doc """
  Clean and normalize company registration number.

  Removes:
  - "(opens in new tab)" suffix from scraped EA data
  - Whitespace
  - Normalizes 7-digit legacy numbers to 8 digits with leading zero

  ## Format Rules
  - Standard (England/Wales): 8 digits (e.g., "03353423")
  - Legacy: 7 digits, normalized to 8 (e.g., "3523081" -> "03523081")
  - Scotland: "SC" + 6 digits (e.g., "SC123456")
  - Northern Ireland: "NI" + 6 digits (e.g., "NI123456")
  - LLP/Other: May have prefixes like "OC", "SO", "NC"

  ## Examples

      iex> clean_company_number("03353423 (opens in new tab)")
      "03353423"

      iex> clean_company_number("  00988844  ")
      "00988844"

      iex> clean_company_number("3523081")
      "03523081"

      iex> clean_company_number("SC123456")
      "SC123456"
  """
  def clean_company_number(nil), do: nil

  def clean_company_number(number) when is_binary(number) do
    cleaned =
      number
      |> String.replace(~r/\s*\(opens in new tab\)/i, "")
      |> String.trim()
      |> String.upcase()

    case cleaned do
      "" ->
        nil

      # Normalize 7-digit numbers to 8 digits with leading zero
      # Only for pure numeric numbers (not prefixed like SC, NI, etc.)
      num when byte_size(num) == 7 ->
        if String.match?(num, ~r/^\d+$/), do: "0" <> num, else: num

      other ->
        other
    end
  end

  def clean_company_number(_), do: nil

  # Private functions

  defp make_request(url) do
    make_request_with_params(url, [])
  end

  defp make_request_with_params(url, query_params) do
    api_key = get_api_key()

    if api_key == nil do
      Logger.error("COMPANIES_HOUSE_API_KEY environment variable not set")
      {:error, :missing_api_key}
    else
      # Companies House uses basic auth with API key as username, empty password
      options = [
        auth: {:basic, "#{api_key}:"},
        headers: [{"accept", "application/json"}],
        params: query_params,
        receive_timeout: @timeout
      ]

      case Req.get(url, options) do
        {:ok, response} ->
          {:ok, response}

        {:error, %Mint.TransportError{reason: :timeout}} ->
          {:error, :timeout}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp get_api_key do
    Application.get_env(:ehs_enforcement, :companies_house)[:api_key]
  end

  defp calculate_similarity(str1, str2) when is_binary(str1) and is_binary(str2) do
    # Normalize both strings for comparison
    norm1 = normalize_name(str1)
    norm2 = normalize_name(str2)

    # Use Jaro-Winkler distance for similarity
    String.jaro_distance(norm1, norm2)
  end

  defp calculate_similarity(_, _), do: 0.0

  defp normalize_name(name) do
    name
    |> String.trim()
    |> String.downcase()
    # Remove common punctuation
    |> String.replace(~r/[\.,:;!@#$%^&*()]+/, "")
    # Normalize company suffixes
    |> String.replace(~r/\s+(limited|ltd\.?)$/i, " limited")
    |> String.replace(~r/\s+(plc|p\.l\.c\.?)$/i, " plc")
    # Replace multiple spaces with single space
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end
end
