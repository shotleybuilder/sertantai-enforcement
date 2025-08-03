defmodule EhsEnforcement.Agencies.Hse.Breaches do
  @moduledoc """
  HSE breaches processing module.
  Handles parsing and linking of HSE breach data to legislation records.
  """
  # TODO: This module has dependencies on Legl.Countries.Uk.LeglRegister.TypeCode
  # and Legl.Services.Airtable modules that need to be updated
  alias EhsEnforcement.Legislation.TypeCode
  alias EhsEnforcement.Integrations.Airtable, as: AT

  @lrt %{
    "health and safety at work act 1974" =>
      {"recLD5iPXEVNbw7P3", "Health and Safety at Work etc. Act", "ukpga", "1974", "37"},
    "control of substances hazardous to health regulations 2002" =>
      {"recNEMWdB0YYo8Fq5", "Control of Substances Hazardous to Health Regulations", "uksi",
       "2002", "2677"},
    "workplace (health, safety and welfare) regulations 1992" =>
      {"recjXsI8jOY9AMcO6", "Workplace (Health, Safety and Welfare) Regulations", "uksi", "1992",
       "3004"},
    "lifting operations and lifting equipment regulations 1998" =>
      {"recjXsI8jOY9AMcO6", "Lifting Operations and Lifting Equipment Regulations", "uksi",
       "1998", "2307"},
    "construction (design and management) regulations 2015" =>
      {"rec8eJ507CIvSSEGm", "Construction (Design and Management) Regulations", "uksi", "2015",
       "51"},
    "construction (design and management) regulations 2007" =>
      {"recnJqiLbSMUC9xFp", "Construction (Design and Management) Regulations", "uksi", "2007",
       "320"},
    "gas safety (installation and use) regulations 1998" =>
      {"recYpSkw8XB0B6Mzj", "Gas Safety (Installation and Use) Regulations", "uksi", "1998",
       "2451"},
    "control of vibration at work regulations 2005" =>
      {"receFEwE91ncP8Lf0", "Control of Vibration at Work Regulations", "uksi", "2005", "1093"},
    "management of health and safety at work regulations 1999" =>
      {"recbAfXL89NNwAW0c", "Management of Health & Safety at Work Regulations", "uksi", "1999",
       "3242"},
    "work at height regulations 2005" =>
      {"rec74SLDMhn0qgSLf", "Work at Height Regulations", "uksi", "2005", "735"},
    "provision and use of work equipment regulations 1998" =>
      {"recnKQFdOsxuKy8Mq", "Provision and Use of Work Equipment Regulations", "uksi", "1998",
       "2306"},
    "control of noise at work regulations 2005" =>
      {"recuvpcpqTyiylB29", "Control of Noise at Work Regulations", "uksi", "2005", "1643"},
    "dangerous substances and explosive atmospheres regulations 2002" =>
      {"reczbF5sc98gWKRPF", "Dangerous Substances and Explosive Atmospheres Regulations", "uksi",
       "2002", "2776"},
    "electricity at work regulations 1989" =>
      {"recqsgiUhypuonfqD", "Electricity at Work Regulations", "uksi", "1989", "635"},
    "control of asbestos regulations 2006" =>
      {"reczJrIaf4wRgtIho", "Control of Asbestos Regulations", "uksi", "2006", "2739"},
    "control of asbestos regulations 2012" =>
      {"rec3CTrDFkiYNOt0e", "Control of Asbestos Regulations", "uksi", "2012", "632"},
    "control of asbestos at work regulations 2002" =>
      {"recK2TiAGPv1A3J0T", "Control of Asbestos Regulations", "uksi", "2002", "2675"},
    "pressure systems safety regulations 2000" =>
      {"recqtUdAoUQILrbZh", "Pressure Systems Safety Regulations", "uksi", "2000", "128"},
    "confined spaces regulations 1997" =>
      {"recmT5FY5alrsoF1r", "Confined Spaces Regulations", "uksi", "1997", "1713"},
    "explosives regulations 2014" =>
      {"recEVNE54yeszbZ2d", "Explosives Regulations", "uksi", "2014", "1638"},
    "control of lead at work regulations 2002" =>
      {"recJNHrz72hl5OzGu", "Control of Lead at Work Regulations", "uksi", "2002", "2676"},
    "ionising radiations regulations 2017" =>
      {"recan1y9sBF8HGBbV", "Ionising Radiations Regulations", "uksi", "2017", "1075"},
    "control of major accident hazards regulations 2015" =>
      {"recfmqOKRuZjPSldh", "Control of Major Accident Hazards Regulations", "uksi", "2015",
       "483"},
    "manual handling operations regulations 1992" =>
      {"recnjrPs8yToocpLw", "Manual Handling Operations Regulations", "uksi", "1992", "2793"},
    "transport and works act 1992" =>
      {"rec5aWqBptAEEEv1g", "Transport And Works Act", "ukpga", "1992", "42"},
    "personal protective equipment at work regulations 1992" =>
      {"recaqRpcsArtSJnhf", "Personal Protective Equipment at Work Regulations", "uksi", "1992",
       "2966"},
    "control of artificial optical radiation at work regulations 2010" =>
      {"receV7EVJl70Te7kl", "Control of Artificial Optical Radiation at Work Regulations", "uksi",
       "2010", "1140"},
    "mines regulations 2014" =>
      {"rec9xwFfuwhMsu8sz", "Mines Regulations", "uksi", "2014", "3248"},
    "diving at work regulations 1997" =>
      {"recJSq1SlxGIbuIf3", "Diving at Work Regulations", "uksi", "1997", "2776"},
    "offshore prevention of fire regulations 1995" =>
      {"rec7adxFsU2KO9FJj",
       "Offshore Installations (Prevention of Fire and Explosion, and Emergency Response) Regulations",
       "uksi", "1995", "743"},
    "asbestos (licensing) regulations 1983" =>
      {"recUQYpOshcPeneTP", "Asbestos (Licensing) Regulations", "uksi", "1983", "1649"},
    "health and safety (first-aid) regulations 1981" =>
      {"recIIgarIVtrr4Ncx", "Health and Safety (First-Aid) Regulations", "uksi", "1981", "917"},
    "reporting of injuries, diseases and dangerous occurrences regulations 1995" =>
      {"rec4bcfijNPU9rXfu",
       "Reporting of Injuries, Diseases and Dangerous Occurrences Regulations", "uksi", "1995",
       "3163"},
    "quarries regulations 1999" =>
      {"recHsaXo5ou8dHkHn", "Quarries Regulations", "uksi", "1999", "2024"},
    "Employers' Liability (Compulsory Insurance) Regulations 1998" =>
      {"recEkVtuxodoZvhHE", "Employers' Liability (Compulsory Insurance) Regulations", "uksi",
       "1998", "2573"},
    "control of pesticides regulations 1986" =>
      {"recdvQfb21nsKKwsF", "Control of Pesticides Regulations", "uksi", "1986", "1510"},
    "classification, labelling and packaging of chemicals (amendments to secondary legislation) regulations 2015" =>
      {"recKvmZCr7dXhAd4I",
       "Classification, Labelling and Packaging of Chemicals (Amendments to Secondary Legislation) Regulations",
       "uksi", "2015", "21"},
    "mines and quarries (tips) act 1969" =>
      {"recBGfgrGtYzBWW7t", "Mines and Quarries (Tips) Act", "ukpga", "1969", "10"},
    "offshore installations and wells (design and construction, etc.) regulations 1996" =>
      {"recbszmJmM2KF8LKM",
       "Offshore Installations and Wells (Design and Construction, etc.) Regulations", "uksi",
       "1996", "913"},
    "biocidal products regulations 2001" =>
      {"reclyKNyhPw9pdj97", "Biocidal Products Regulations", "uksi", "2001", "880"}
  }

  def enum_breaches(notices) do
    Enum.reduce(notices, [], fn %{offence_breaches: breaches} = notice, acc ->
      breaches_clean = breaches_clean(breaches)

      Map.merge(notice, breaches_clean)
      |> (&[&1 | acc]).()
    end)
  end

  defp breaches_clean(breaches) do

    breaches_clean =
      split_breach_into_title_year_article(breaches)
      |> Enum.reduce({[], []}, fn breach, acc ->
        case get_linked_airtable_record_id(breach) do
          {record_id, title, _type_code, year, number} ->
            {record_id, title, year, number}

            breach_clean =
              case breach do
                %{article: article, sub_article: sub_article} ->
                  ~s/#{title} #{year} #{number} #{article}(#{sub_article})/

                %{article: article} ->
                  ~s/#{title} #{year} #{number} #{article}/

                _ ->
                  ~s/#{title} #{year} #{number}/
              end

            {[breach_clean | elem(acc, 0)], [~s/#{record_id}/ | elem(acc, 1)]}

          "" ->
            IO.puts(~s/ERROR: #{breach.title}/)
            acc
        end
      end)

    breaches =
      breaches
      |> Enum.sort()
      |> Enum.join("\n")

    offence_breaches_clean =
      breaches_clean
      |> elem(0)
      |> Enum.sort()
      |> Enum.join("\n")

    offence_lrt =
      breaches_clean
      |> elem(1)
      |> Enum.uniq()

    # Sets values for the fields: breaches_clean, lrt
    %{
      offence_breaches: breaches,
      offence_breaches_clean: offence_breaches_clean,
      offence_lrt: offence_lrt
    }
  end

  defp split_breach_into_title_year_article(breaches) when is_list(breaches) do
    Enum.map(breaches, fn breach ->
      split_breach_into_title_year_article(breach)
    end)
  end

  defp split_breach_into_title_year_article(breach) when is_binary(breach) do
    breach
    |> String.trim()
    |> String.trim_trailing(" /")
    |> String.split("/")
    |> Enum.map(&String.trim/1)
    |> case do
      [title_year, article, sub_article] ->
        Map.merge(title_year(title_year), %{article: article, sub_article: sub_article})

      [title_year, article] ->
        Map.merge(title_year(title_year), %{article: article})

      [title_year] ->
        title_year(title_year)
    end
  end

  defp title_year(title_year) do
    case Regex.run(~r/^(.*?)[ ](\d{4})/, title_year) do
      [_, title, year] ->
        %{title: clean_title(title), year: year}

      nil ->
        %{title: clean_title(title_year)}
    end
  end

  defp clean_title(title) do
    title
    |> (&Regex.replace(~r/Regs/, &1, "Regulations")).()
    |> (&Regex.replace(~r/[ ]{2,}/, &1, " ")).()
    |> (&Regex.replace(~r/&/, &1, "and")).()
    |> (&Regex.replace(~r/Equip/, &1, "Equipment")).()
    |> (&Regex.replace(~r/^Electricity at Work$/, &1, "Electricity at Work Regulations")).()
    |> (&Regex.replace(~r/Equipmentment/, &1, "Equipment")).()
    |> (&Regex.replace(
          ~r/Offshore Prevention Of Fire/,
          &1,
          "Offshore Prevention Of Fire Regulations"
        )).()
    |> (&Regex.replace(
          ~r/Health and Safety \(First Aid\)/,
          &1,
          "Health and Safety (First-Aid) Regulations"
        )).()
    |> (&Regex.replace(
          ~r/Reporting of Injuries Diseases and Dangerous \(1995\)/,
          &1,
          "Reporting of Injuries, Diseases and Dangerous Occurrences Regulations"
        )).()
    |> (&Regex.replace(
          ~r/Employers Liability Compulsory Insurance/,
          &1,
          "Employers' Liability (Compulsory Insurance) Regulations"
        )).()
    |> (&Regex.replace(~r/Control of Pesticides/, &1, "Control of Pesticides Regulations")).()
    |> (&Regex.replace(
          ~r/Classif,label and pack of substancesandmixtu/,
          &1,
          "Classification, Labelling and Packaging of Chemicals (Amendments to Secondary Legislation) Regulations"
        )).()
    |> (&Regex.replace(~r/Mines and Quarry \(Tips\)/, &1, "Mines and Quarries (Tips) Act")).()
    |> (&Regex.replace(
          ~r/Offshore Design and Construction/,
          &1,
          "Offshore Installations and Wells (Design and Construction, etc.) Regulations"
        )).()
    |> (&Regex.replace(
          ~r/Make available on market and use biocid pr/,
          &1,
          "Biocidal Products Regulations"
        )).()
    |> (&Regex.replace(
          ~r/Corp Manslaughter and Corp Homicide|Manslaughter/,
          &1,
          "Corporate Manslaughter and Corporate Homicide Act"
        )).()
    |> (&Regex.replace(
          ~r/Notification of Cooling Towers and Evaporative Condensers/,
          &1,
          "Notification of Cooling Towers and Evaporative Condensers Regulations"
        )).()
  end

  defp get_linked_airtable_record_id(%{title: title} = breach) do
    # HSE records sometimes fail to include year
    breach =
      case Map.get(breach, :year) do
        nil -> Map.put(breach, :year, get_missing_year(title))
        _ -> breach
      end

    search_term = String.downcase(title) <> " " <> breach.year

    case Map.get(@lrt, search_term) do
      nil ->

        breach
        |> Map.put(:type_code, type_code(breach))
        |> get_linked_airtable_record()
        |> match_title(title)

      lrt ->
        lrt
    end
  end

  defp get_missing_year("Electricity at Work Regulations"), do: "1989"
  defp get_missing_year("Workplace (Health, Safety and Welfare) Regulations"), do: "1992"
  defp get_missing_year("Manual Handling Operations Regulations"), do: "1992"
  defp get_missing_year("Offshore Prevention Of Fire Regulations"), do: "1995"
  defp get_missing_year("Asbestos (Licensing) Regulations"), do: "1983"
  defp get_missing_year("Health and Safety (First-Aid) Regulations"), do: "1981"
  defp get_missing_year("Employers' Liability (Compulsory Insurance) Regulations"), do: "1998"
  defp get_missing_year("Control of Pesticides Regulations"), do: "1986"
  defp get_missing_year("Mines and Quarries (Tips) Act"), do: "1969"
  defp get_missing_year("Biocidal Products Regulations"), do: "2001"
  defp get_missing_year("Health and Safety (Display Screen Equipment) Regulations"), do: "1992"
  defp get_missing_year("Corporate Manslaughter and Corporate Homicide Act"), do: "2007"

  defp get_missing_year("Notification of Cooling Towers and Evaporative Condensers Regulations"),
    do: "1992"

  defp get_missing_year("Reporting of Injuries, Diseases and Dangerous Occurrences Regulations"),
    do: "1995"

  defp get_missing_year(
         "Classification, Labelling and Packaging of Chemicals (Amendments to Secondary Legislation) Regulations"
       ),
       do: "2015"

  defp get_missing_year(
         "Offshore Installations and Wells (Design and Construction, etc.) Regulations"
       ),
       do: "1996"

  defp type_code(%{title: title}) do
    TypeCode.type_code_from_title(title)
    |> elem(1)
  end

  def match_title(at_records, title) do
    Enum.reduce_while(at_records, {"", 0}, fn
      %{
        "id" => id,
        "fields" => %{
          "Title_EN" => title_en,
          "type_code" => type_code,
          "Year" => year,
          "Number" => number
        }
      } = _record,
      acc ->
        case String.jaro_distance(title_en, title) do
          1.0 ->
            {:halt, {{id, title_en, type_code, Integer.to_string(year), number}, 1.0}}

          jd ->
            if jd > elem(acc, 1) do
              {:cont, {{id, title_en, type_code, Integer.to_string(year), number}, jd}}
            else
              {:cont, acc}
            end
        end
    end)
    |> elem(0)
  end

  def get_linked_airtable_record(%{type_code: type_code, year: year} = _breach) do
    base = "appq5OQW9bTHC1zO5"
    table = "tblJW0DMpRs74CJux"

    formula =
      ~s|AND({type_code} = "#{type_code}", {Year} = "#{year}", {💙 H&S REGISTER} = "💙", {Makes?} = TRUE())|

    view = ""

    params = %{
      fields: ["Name", "Title_EN", "type_code", "Year", "Number"],
      formula: formula,
      view: view
    }

    base_url = EhsEnforcement.Integrations.Airtable.Endpoint.base_url()
    {:ok, url} = AT.Url.url(base, table, params)
    headers = EhsEnforcement.Integrations.Airtable.Headers.headers()

    req_opts = [
      {:base_url, base_url},
      {:url, url},
      {:headers, headers}
    ]

    Req.new(req_opts)
    |> Req.Request.append_request_steps(debug_url: debug_url())
    |> Req.request!()
    |> Map.get(:body)
    |> Map.get("records")

    # Req.get!(base_url: , url: url, headers: headers).body
  end

  defp debug_url,
    do: fn request ->
      request
    end

  # defp debug_body,
  #  do: fn request ->
  #    IO.puts(request.body)
  #    request
  #  end
end