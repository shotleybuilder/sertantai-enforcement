defmodule EhsEnforcement.Agencies.Hse.CaseScraper do
  @moduledoc """
  HSE case scraper module.
  Handles scraping of HSE court case data from the HSE website.
  """

  def get_hse_cases(search, opts \\ %{database: "convictions"}) do
    # Options are 'convictions-history' or 'convictions'

    base_url = ~s|https://resources.hse.gov.uk/#{opts.database}/case/|

    url =
      case search do
        %{page: page} ->
          ~s/case_list.asp?PN=#{page}&ST=C&EO=LIKE&SN=F&SF=DN&SV=&SO=DODS/

        # case_list.asp?PN=#{page}&ST=C&EO=LIKE&SN=F&SF=DN&SV=&SO=DODS

        %{id: id} ->
          ~s/case_list.asp?ST=C&EO=LIKE&SN=F&SF=CN&SV=#{id}/
      end

    Req.new(base_url: base_url, url: url)
    |> Req.Request.append_request_steps(debug_url: debug_url())
    |> Req.request!()
    |> Map.get(:body)
    |> parse_tr()
    |> extract_td()
    |> extract_cases()
  end

  def get_case_details(case_number, opts \\ %{database: "convictions"}) do
    base_url = ~s|https://resources.hse.gov.uk/#{opts.database}/case/|
    url = ~s/case_details.asp?SF=CN&SV=#{case_number}/

    Req.get!(base_url: base_url, url: url).body
    |> parse_tr()
    |> extract_td()
    |> extract_case_details(opts.database)
  end

  # PRIVATE FUNCTIONS

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

  defp extract_cases(cases) do

    Enum.reduce(cases, [], fn
      [
        {"td", _,
         [
           {"a",
            [
              _,
              _
            ], [regulator_id]}
         ]},
        {"td", _, [offender_name]},
        {"td", _, [offence_action_date]},
        {"td", _, [offender_local_authority]},
        {"td", _, [offender_main_activity]}
      ],
      acc ->
        [
          %{
            regulator_id: String.trim(regulator_id),
            offender_name: offender_name,
            offence_action_date: EhsEnforcement.Utility.iso_date(offence_action_date),
            offender_local_authority: offender_local_authority,
            offender_main_activity: offender_main_activity
          }
          | acc
        ]

      _, acc ->
        acc
    end)
  end

  defp extract_case_details(case_details, database) do

    Enum.reduce(case_details, %{}, fn
      [
        {"td", _,
         [
           {"a", [{"href", url_breach}], ["Breach involved in this Case"]},
           _
         ]}
      ],
      acc ->
        Map.merge(acc, case_breach(String.trim_leading(url_breach, "../"), database))

      [
        {"td", _,
         [
           {"a", [{"href", url_breach}], ["Breach involved in this Case"]},
           _,
           {"a", [{"href", url_cases}], ["Related Cases"]},
           _
         ]}
      ],
      acc ->
        acc = Map.merge(acc, case_breach(String.trim_leading(url_breach, "../"), database))

        Map.put(
          acc,
          :offender_related_cases,
          get_related_cases(String.trim_leading(url_cases, "../"), database)
        )

      [
        {"td", _,
         [
           {"a", [{"href", url_breaches}], ["Breaches involved in this Case"]},
           _
         ]}
      ] = _td,
      acc ->

        Map.merge(acc, case_breaches(String.trim_leading(url_breaches, "../"), database))

      [
        {"td", _,
         [
           {"a", [{"href", url_breaches}], ["Breaches involved in this Case"]},
           _,
           {"a", [{"href", url_cases}], ["Related Cases"]},
           _
         ]}
      ] = _td,
      acc ->

        acc = Map.merge(acc, case_breaches(String.trim_leading(url_breaches, "../"), database))

        Map.put(
          acc,
          :offender_related_cases,
          get_related_cases(String.trim_leading(url_cases, "../"), database)
        )

      [
        {"td", _, _},
        {"td", _, _},
        {"td", _, [{_, _, ["HSE Directorate"]}]},
        {"td", _, [regulator_function]}
      ],
      acc ->
        Map.merge(acc, %{
          regulator_function:
            EhsEnforcement.Utility.upcase_first_from_upcase_phrase(regulator_function),
          regulator_regulator_function:
            "HSE_" <> EhsEnforcement.Utility.upcase_first_from_upcase_phrase(regulator_function)
        })

      [
        {"td", _, [{_, _, ["Main Activity"]}]},
        {"td", _, [offender_main_activity]}
      ],
      acc ->
        Map.put(acc, :offender_main_activity, offender_main_activity)

      [{"td", _, [{_, _, ["Industry"]}]}, {"td", _, [offender_industry]}], acc ->
        Map.put(acc, :offender_industry, offender_industry)

      [{"td", _, [{_, _, ["Local Authority"]}]}, {"td", _, [offender_local_authority]}], acc ->
        Map.put(acc, :offender_local_authority, offender_local_authority)

      [
        {"td", _, [{_, _, ["Total Fine"]}]},
        {"td", _, [offence_fine]},
        {"td", _, [{_, _, ["Total Costs Awarded to HSE"]}]},
        {"td", _, [offence_costs]}
      ],
      acc ->
        Map.merge(acc, %{
          offence_fine: convert_monetary_string_to_float(offence_fine),
          offence_costs: convert_monetary_string_to_float(offence_costs)
        })

      [
        {"td", _, [{_, _, ["Total Fine"]}]},
        {:comment, _},
        {"td", _, [offence_fine]},
        {"td", _, [{_, _, ["Total Costs Awarded to HSE"]}]},
        {"td", _, [offence_costs]}
      ],
      acc ->
        Map.merge(acc, %{
          offence_fine: convert_monetary_string_to_float(offence_fine),
          offence_costs: convert_monetary_string_to_float(offence_costs)
        })

      _, acc ->
        acc
    end)

    #
  end

  defp case_breach("breach/breach_details.asp?SF=BID&SV=" <> case_number = _url, database) do
    url =
      "search/search.asp?ST=B&SN=F&EO=%3D&SF=CN&SV=" <> Regex.replace(~r/\d{3}$/, case_number, "")

    case_breaches(url, database)
  end

  defp case_breaches(
         "search/search.asp?ST=B&SN=F&EO=%3D&SF=CN&SV=" <> case_number = _url,
         database
       ) do
    base_url = ~s|https://resources.hse.gov.uk/#{database}/breach/|
    url = ~s|breach_list.asp?ST=B&SN=F&EO=%3D&SF=CN&SV=#{case_number}|
    # IO.puts("URL: #{base_url}#{url}")

    tds =
      Req.get!(base_url: base_url, url: url).body
      |> parse_tr()
      |> extract_td()


    Enum.reduce(tds, %{offence_number: 0, offence_breaches: []}, fn
      [
        {"td", _, _},
        {"td", _, _},
        {"td", _, [offence_hearing_date]},
        {"td", _, [offence_result]},
        {"td", _, _},
        {"td", _, [offence_breach]}
      ] = _td,
      acc ->

        Map.merge(acc, %{
          offence_number: acc.offence_number + 1,
          offence_result: offence_result,
          offence_breaches: acc.offence_breaches ++ [offence_breach],
          offence_hearing_date: EhsEnforcement.Utility.iso_date(offence_hearing_date)
        })

      _, acc ->
        acc
    end)
  end

  defp get_related_cases(
         "search/search.asp?ST=C&SN=R&EO=%3D&SF=RCN&SV=" <> case_number = _url,
         database
       ) do
    get_related_cases(case_number, database)
  end

  defp get_related_cases(case_number, database) do
    base_url = ~s|https://resources.hse.gov.uk/#{database}/case/|
    url = ~s|case_list.asp?ST=C&SN=R&EO=%3D&SF=RCN&SV=#{case_number}|

    tds =
      Req.get!(base_url: base_url, url: url).body
      |> parse_tr()
      |> extract_td()


    Enum.reduce(tds, [], fn
      [
        {"td", [],
         [
           {"a",
            [
              {"title", _},
              {"href", _}
            ], [related_case_number]}
         ]},
        {"td", _, _},
        {"td", _, _},
        {"td", _, _},
        {"td", _, _}
      ],
      acc ->
        [
          "HSE_" <> String.trim(related_case_number) | acc
        ]

      _, acc ->
        acc
    end)
    |> Enum.join(",")
  end

  defp debug_url,
    do: fn request ->
      request
    end

  defp convert_monetary_string_to_float(string) do
    # Convert monetary string to float
    # e.g. "£1,000" => 1000.0
    string
    |> String.replace(~r/[^0-9.]/, "")
    |> String.to_float()
  end
end
