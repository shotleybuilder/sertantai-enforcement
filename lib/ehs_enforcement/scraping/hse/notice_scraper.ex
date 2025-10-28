defmodule EhsEnforcement.Scraping.Hse.NoticeScraper do
  @moduledoc """
  HSE notice scraper module.
  Handles scraping of HSE enforcement notice data from the HSE website with rate limiting.

  The `get_hse_notices/2` function retrieves a list of HSE notices based on the specified page number and country.

  The `get_notice_details/1` function retrieves the details of a specific HSE notice based on the notice number.

  The `get_notice_breaches/1` function retrieves the breaches associated with a specific HSE notice based on the notice number.

  All functions include ethical rate limiting to respect HSE website resources.
  """

  require Logger
  alias EhsEnforcement.Scraping.RateLimiter

  def get_hse_notices(page_number: page_number, country: country) do
    base_url = ~s|https://resources.hse.gov.uk|

    # URL encode the country parameter to handle spaces
    encoded_country = URI.encode_www_form(country)

    url =
      base_url <>
        ~s|/notices/notices/notice_list.asp?PN=#{page_number}&ST=N&CO=,AND&SN=F&EO==&SF=CTR&SV=#{encoded_country}&SO=DNIS|

    Logger.debug("Fetching HSE notices for #{country}, page #{page_number}")

    case RateLimiter.rate_limited_request(url) do
      {:ok, body} ->
        body
        |> parse_tr()
        |> extract_td()
        |> extract_notices(country)

      {:error, reason} ->
        Logger.error(
          "Failed to fetch HSE notices for #{country}, page #{page_number}: #{inspect(reason)}"
        )

        {:error, reason}
    end
  end

  def get_notice_details(%{notice_number: notice_number}), do: get_notice_details(notice_number)

  def get_notice_details(notice_number) do
    base_url = ~s|https://resources.hse.gov.uk|
    encoded_notice_number = URI.encode_www_form(notice_number)
    url = base_url <> ~s|/notices/notices/notice_details.asp?SF=CN&SV=#{encoded_notice_number}|

    Logger.debug("Fetching details for HSE notice #{notice_number}")

    case RateLimiter.rate_limited_request(url) do
      {:ok, body} ->
        body
        |> parse_tr()
        |> extract_td()
        |> extract_notice_details()

      {:error, reason} ->
        Logger.warning("Failed to fetch details for notice #{notice_number}: #{inspect(reason)}")
        # Return empty map on error to avoid breaking the pipeline
        %{}
    end
  end

  def get_notice_breaches(%{notice_number: notice_number}), do: get_notice_breaches(notice_number)

  def get_notice_breaches(notice_number) do
    base_url = ~s|https://resources.hse.gov.uk|
    encoded_notice_number = URI.encode_www_form(notice_number)

    url =
      base_url <>
        ~s|/notices/breach/breach_list.asp?ST=B&SN=F&EO==&SF=NN&SV=#{encoded_notice_number}|

    Logger.debug("Fetching breaches for HSE notice #{notice_number}")

    case RateLimiter.rate_limited_request(url) do
      {:ok, body} ->
        body
        |> parse_tr()
        |> extract_td()
        |> extract_notice_breaches()

      {:error, reason} ->
        Logger.warning("Failed to fetch breaches for notice #{notice_number}: #{inspect(reason)}")
        # Return empty breaches on error
        %{offence_breaches: []}
    end
  end

  defp parse_tr(body) do
    {:ok, document} = Floki.parse_document(body)
    Floki.find(document, "tr")
  end

  defp extract_td(notices) do
    Enum.reduce(notices, [], fn
      {"tr", [], notice}, acc -> [notice | acc]
      _, acc -> acc
    end)
  end

  defp extract_notices(notices, country) do
    Enum.reduce(notices, [], fn
      [
        {"td", [],
         [
           {"a",
            [
              {"title", _},
              {"href", _}
            ], [notice_number]}
         ]},
        {"td", [], [recipients_name]},
        {"td", [], [notice_type]},
        {"td", [], [issue_date]},
        {"td", [], [local_authority]},
        {"td", [], [sic]}
      ],
      acc ->
        [
          %{
            regulator_id: String.trim(notice_number),
            offender_name: String.trim(recipients_name),
            offence_action_type: String.trim(notice_type),
            offence_action_date: EhsEnforcement.Utility.iso_date(issue_date),
            offender_local_authority: String.trim(local_authority),
            offender_sic: String.trim(sic),
            offender_country: country
          }
          | acc
        ]

      _, acc ->
        acc
    end)
  end

  defp extract_notice_details(notice_details) do
    Enum.reduce(notice_details, %{}, fn
      [
        {"td", _, _},
        {"td", _, _},
        {"td", _, ["HSE Directorate"]},
        {"td", _, [regulator_function]}
      ],
      acc ->
        Map.put(
          acc,
          :regulator_function,
          EhsEnforcement.Utility.upcase_first_from_upcase_phrase(regulator_function)
        )

      [
        {"td", _, ["Compliance Date"]},
        {"td", _, [compliance_date]},
        {"td", _, ["Revised Compliance Date"]},
        {"td", _, [revised_compliance_date]}
      ],
      acc ->
        acc
        |> Map.put(:offence_compliance_date, EhsEnforcement.Utility.iso_date(compliance_date))
        |> Map.put(
          :offence_revised_compliance_date,
          EhsEnforcement.Utility.iso_date(revised_compliance_date)
        )

      [
        {"td", _, ["Compliance Date"]},
        {"td", _, [compliance_date]},
        {"td", _, _},
        {"td", _, _}
      ],
      acc ->
        Map.put(acc, :offence_compliance_date, EhsEnforcement.Utility.iso_date(compliance_date))

      [
        {"td", _, ["Description"]},
        {"td", _, [description]}
      ],
      acc ->
        Map.put(acc, :offence_description, String.trim(description))

      [
        {"td", _, ["Main Activity"]},
        {"td", _, [main_activity]}
      ],
      acc ->
        Map.put(acc, :offender_main_activity, String.trim(main_activity))

      [
        {"td", _, ["Industry"]},
        {"td", _, [industry]}
      ],
      acc ->
        Map.put(acc, :offender_industry, String.trim(industry))

      [
        {"td", _, ["Result"]},
        {"td", _, [result]}
      ],
      acc ->
        Map.put(acc, :offence_result, String.trim(result))

      _notice, acc ->
        acc
    end)
  end

  defp extract_notice_breaches(notice_breaches) do
    Enum.reduce(notice_breaches, [], fn
      [
        {"td", _, _},
        {"td", _, _},
        {"td", _, _},
        {"td", _, [breach]},
        {_, _, _}
      ],
      acc ->
        [String.trim(breach) | acc]

      _breach, acc ->
        acc
    end)
    |> (&Map.put(%{}, :offence_breaches, &1)).()
  end
end
