defmodule EhsEnforcementWeb.OffenderLive.Show do
  use EhsEnforcementWeb, :live_view

  alias EhsEnforcement.Enforcement
  # alias Phoenix.LiveView.JS  # Unused alias removed

  require Ash.Query
  import Ash.Expr

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    # Subscribe to real-time updates for this offender
    :ok = Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "offender:#{id}")
    :ok = Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "case_created")
    :ok = Phoenix.PubSub.subscribe(EhsEnforcement.PubSub, "notice_created")

    socket =
      socket
      |> assign(:loading, true)
      |> assign(:offender, nil)
      |> assign(:offender_id, id)
      |> assign(:enforcement_timeline, [])
      |> assign(:related_offenders, [])
      |> assign(:agency_breakdown, %{})
      |> assign(:risk_assessment, %{})
      |> assign(:timeline_filters, %{})
      |> assign(:industry_context, %{})

    {:ok, socket}
  end

  @impl true
  def handle_params(%{"id" => id} = params, _url, socket) do
    socket =
      socket
      |> assign(:offender_id, id)
      |> assign(:timeline_filters, parse_timeline_filters(params))
      |> load_offender_data()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_timeline", %{"filter_type" => filter_type}, socket) do
    filters = Map.put(socket.assigns.timeline_filters, :filter_type, filter_type)

    socket =
      socket
      |> assign(:timeline_filters, filters)
      |> load_enforcement_timeline()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_timeline", %{"agency" => agency}, socket) do
    filters = Map.put(socket.assigns.timeline_filters, :agency, agency)

    socket =
      socket
      |> assign(:timeline_filters, filters)
      |> load_enforcement_timeline()

    {:noreply, socket}
  end

  @impl true
  def handle_event("filter_timeline", %{"from_date" => from_date, "to_date" => to_date}, socket) do
    filters =
      socket.assigns.timeline_filters
      |> Map.put(:from_date, from_date)
      |> Map.put(:to_date, to_date)

    socket =
      socket
      |> assign(:timeline_filters, filters)
      |> load_enforcement_timeline()

    {:noreply, socket}
  end

  @impl true
  def handle_event("export_pdf", _params, socket) do
    # PDF export functionality - placeholder for now
    socket = put_flash(socket, :info, "PDF export functionality coming soon")
    {:noreply, socket}
  end

  @impl true
  def handle_event("export_csv", _params, socket) do
    csv_data = generate_enforcement_csv(socket.assigns.enforcement_timeline)

    socket =
      socket
      |> push_event("download_csv", %{
        data: csv_data,
        filename: "offender_#{socket.assigns.offender_id}_enforcement_history.csv"
      })

    {:noreply, socket}
  end

  @impl true
  def handle_info({:case_created, case_record}, socket) do
    if case_record.offender_id == socket.assigns.offender_id do
      {:noreply, refresh_offender_data(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:notice_created, notice_record}, socket) do
    if notice_record.offender_id == socket.assigns.offender_id do
      {:noreply, refresh_offender_data(socket)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:offender_updated, offender}, socket) do
    if offender.id == socket.assigns.offender_id do
      {:noreply, refresh_offender_data(socket)}
    else
      {:noreply, socket}
    end
  end

  # Private functions

  defp parse_timeline_filters(params) do
    %{}
    |> maybe_add_timeline_filter(:filter_type, params["filter_type"])
    |> maybe_add_timeline_filter(:agency, params["agency"])
    |> maybe_add_timeline_filter(:from_date, params["from_date"])
    |> maybe_add_timeline_filter(:to_date, params["to_date"])
  end

  defp maybe_add_timeline_filter(filters, _key, nil), do: filters
  defp maybe_add_timeline_filter(filters, _key, ""), do: filters
  defp maybe_add_timeline_filter(filters, key, value), do: Map.put(filters, key, value)

  defp load_offender_data(socket) do
    case get_offender_with_details(socket.assigns.offender_id) do
      {:ok, offender} ->
        # Use Map.get to avoid type checker issue with struct field access
        offender_name = Map.get(offender, :name, "Unknown")

        socket
        |> assign(:offender, offender)
        |> assign(:page_title, offender_name)
        |> load_enforcement_timeline()
        |> load_related_offenders()
        |> calculate_agency_breakdown()
        |> calculate_risk_assessment()
        |> load_industry_context()
        |> assign(:loading, false)

      {:error, %Ash.Error.Query.NotFound{}} ->
        socket
        |> assign(:offender, nil)
        |> assign(:loading, false)
        |> put_flash(:error, "Offender not found")
    end
  end

  defp get_offender_with_details(id) do
    try do
      case Enforcement.get_offender!(id, load: [:cases, :notices]) do
        {:ok, offender} -> {:ok, offender}
        offender -> {:ok, offender}
      end
    rescue
      Ash.Error.Query.NotFound ->
        {:error, %Ash.Error.Query.NotFound{}}

      error ->
        {:error, error}
    end
  end

  defp load_enforcement_timeline(socket) do
    if socket.assigns.offender do
      timeline =
        build_enforcement_timeline(socket.assigns.offender, socket.assigns.timeline_filters)

      assign(socket, :enforcement_timeline, timeline)
    else
      socket
    end
  end

  defp build_enforcement_timeline(offender, filters) do
    cases = filter_enforcement_actions(offender.cases || [], filters, :case)
    notices = filter_enforcement_actions(offender.notices || [], filters, :notice)

    (cases ++ notices)
    |> Enum.sort_by(&get_action_date/1, {:desc, Date})
    |> group_by_year()
  end

  defp filter_enforcement_actions(actions, filters, type) do
    actions =
      actions
      |> maybe_filter_by_type(filters[:filter_type], type)
      |> maybe_filter_by_agency(filters[:agency])
      |> maybe_filter_by_date_range(filters[:from_date], filters[:to_date])

    Enum.map(actions, &Map.put(&1, :action_type, type))
  end

  defp maybe_filter_by_type(actions, nil, _type), do: actions
  defp maybe_filter_by_type(actions, "cases", :case), do: actions
  defp maybe_filter_by_type(actions, "notices", :notice), do: actions
  defp maybe_filter_by_type(_actions, _filter_type, _type), do: []

  defp maybe_filter_by_agency(actions, nil), do: actions

  defp maybe_filter_by_agency(actions, agency_code) do
    Enum.filter(actions, fn action ->
      case action.agency do
        %{code: code} -> Atom.to_string(code) == agency_code
        _ -> false
      end
    end)
  end

  defp maybe_filter_by_date_range(actions, nil, nil), do: actions

  defp maybe_filter_by_date_range(actions, from_date, to_date) do
    from_date = parse_date(from_date)
    to_date = parse_date(to_date)

    Enum.filter(actions, fn action ->
      action_date = get_action_date(action)

      within_from = !from_date || Date.compare(action_date, from_date) != :lt
      within_to = !to_date || Date.compare(action_date, to_date) != :gt

      within_from && within_to
    end)
  end

  defp parse_date(nil), do: nil
  defp parse_date(""), do: nil

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> date
      {:error, _} -> nil
    end
  end

  defp get_action_date(%{offence_action_date: nil}), do: ~D[1900-01-01]
  defp get_action_date(%{offence_action_date: date}), do: date
  defp get_action_date(%{notice_date: nil}), do: ~D[1900-01-01]
  defp get_action_date(%{notice_date: date}), do: date
  defp get_action_date(_), do: ~D[1900-01-01]

  defp group_by_year(timeline) do
    timeline
    |> Enum.group_by(fn action ->
      get_action_date(action).year
    end)
    |> Enum.sort_by(fn {year, _} -> year end, :desc)
  end

  defp load_related_offenders(socket) do
    if socket.assigns.offender do
      related = find_related_offenders(socket.assigns.offender)
      assign(socket, :related_offenders, related)
    else
      socket
    end
  end

  defp find_related_offenders(offender) do
    try do
      # Find offenders in same industry and local authority
      same_industry =
        Enforcement.list_offenders!(
          filter: [
            expr(industry == ^offender.industry and id != ^offender.id)
          ],
          limit: 5,
          sort: [total_fines: :desc]
        )

      same_area =
        Enforcement.list_offenders!(
          filter: [
            expr(local_authority == ^offender.local_authority and id != ^offender.id)
          ],
          limit: 5,
          sort: [total_fines: :desc]
        )

      %{
        same_industry: same_industry,
        same_area: same_area
      }
    rescue
      _ ->
        %{same_industry: [], same_area: []}
    end
  end

  defp calculate_agency_breakdown(socket) do
    if socket.assigns.offender do
      breakdown = build_agency_breakdown(socket.assigns.offender)
      assign(socket, :agency_breakdown, breakdown)
    else
      socket
    end
  end

  defp build_agency_breakdown(offender) do
    cases = offender.cases || []
    notices = offender.notices || []

    # Group by agency
    agency_stats =
      (cases ++ notices)
      |> Enum.group_by(fn action ->
        case action.agency do
          %{code: code} -> code
          _ -> :unknown
        end
      end)
      |> Enum.map(fn {agency_code, actions} ->
        case_count = Enum.count(actions, &Map.has_key?(&1, :offence_fine))
        notice_count = Enum.count(actions, &Map.has_key?(&1, :notice_type))

        total_fines =
          actions
          |> Enum.filter(&Map.has_key?(&1, :offence_fine))
          |> Enum.reduce(Decimal.new(0), fn action, acc ->
            Decimal.add(acc, action.offence_fine || Decimal.new(0))
          end)

        {agency_code,
         %{
           cases: case_count,
           notices: notice_count,
           total_fines: total_fines
         }}
      end)
      |> Enum.into(%{})

    agency_stats
  end

  defp calculate_risk_assessment(socket) do
    if socket.assigns.offender do
      risk = assess_offender_risk(socket.assigns.offender)
      assign(socket, :risk_assessment, risk)
    else
      socket
    end
  end

  defp assess_offender_risk(offender) do
    total_cases = offender.total_cases || 0
    total_notices = offender.total_notices || 0
    total_fines = Decimal.to_float(offender.total_fines || Decimal.new(0))

    # Calculate years of activity
    _years_active =
      if offender.first_seen_date && offender.last_seen_date do
        Date.diff(offender.last_seen_date, offender.first_seen_date) / 365
      else
        1
      end

    # Count agencies involved (this would need to be passed in or calculated differently)
    # placeholder - would need proper agency breakdown data
    agency_count = 1

    # Risk factors
    risk_factors = []
    risk_score = 0

    # Multiple agencies involvement
    {risk_factors, risk_score} =
      if agency_count > 1 do
        {["Multiple agencies involved" | risk_factors], risk_score + 30}
      else
        {risk_factors, risk_score}
      end

    # High fine amounts
    {risk_factors, risk_score} =
      if total_fines > 100_000 do
        {["Escalating fines" | risk_factors], risk_score + 25}
      else
        {risk_factors, risk_score}
      end

    # Recent activity
    recent_activity =
      offender.last_seen_date &&
        Date.diff(Date.utc_today(), offender.last_seen_date) < 365

    {risk_factors, risk_score} =
      if recent_activity do
        {["Recent activity" | risk_factors], risk_score + 20}
      else
        {risk_factors, risk_score}
      end

    # Multiple violations
    {risk_factors, risk_score} =
      if total_cases + total_notices > 5 do
        {["Multiple violations" | risk_factors], risk_score + 25}
      else
        {risk_factors, risk_score}
      end

    risk_level =
      cond do
        risk_score >= 70 -> "High Risk"
        risk_score >= 40 -> "Medium Risk"
        true -> "Low Risk"
      end

    %{
      level: risk_level,
      score: risk_score,
      factors: risk_factors
    }
  end

  defp load_industry_context(socket) do
    if socket.assigns.offender do
      context = build_industry_context(socket.assigns.offender)
      assign(socket, :industry_context, context)
    else
      socket
    end
  end

  defp build_industry_context(offender) do
    try do
      # Get industry peers
      industry_peers =
        Enforcement.list_offenders!(
          filter: [
            expr(industry == ^offender.industry and id != ^offender.id)
          ]
        )

      if length(industry_peers) > 0 do
        avg_fines =
          industry_peers
          |> Enum.map(&(&1.total_fines || Decimal.new(0)))
          |> Enum.reduce(Decimal.new(0), &Decimal.add/2)
          |> Decimal.div(Decimal.new(length(industry_peers)))

        offender_fines = offender.total_fines || Decimal.new(0)

        comparison =
          cond do
            Decimal.compare(offender_fines, Decimal.mult(avg_fines, Decimal.new(2))) == :gt ->
              "Significantly above industry average"

            Decimal.compare(offender_fines, avg_fines) == :gt ->
              "Above industry average"

            true ->
              "Within industry average"
          end

        %{
          industry: offender.industry,
          peer_count: length(industry_peers),
          avg_fines: avg_fines,
          comparison: comparison
        }
      else
        %{industry: offender.industry, peer_count: 0}
      end
    rescue
      _ ->
        %{industry: offender.industry, peer_count: 0}
    end
  end

  defp refresh_offender_data(socket) do
    load_offender_data(socket)
  end

  defp repeat_offender?(offender) do
    total_actions = (offender.total_cases || 0) + (offender.total_notices || 0)
    total_actions > 1
  end

  defp format_currency(nil), do: "£0"

  defp format_currency(amount) when is_binary(amount) do
    case Decimal.parse(amount) do
      {decimal, _} -> format_currency(decimal)
      :error -> "£0"
    end
  end

  defp format_currency(%Decimal{} = amount) do
    amount
    |> Decimal.to_string()
    |> String.to_integer()
    |> Number.Currency.number_to_currency(unit: "£")
  end

  defp format_currency(amount) when is_integer(amount) do
    Number.Currency.number_to_currency(amount, unit: "£")
  end

  defp format_date(nil), do: "N/A"
  defp format_date(date), do: Date.to_string(date)

  defp generate_enforcement_csv(timeline) do
    headers = ["Year", "Date", "Type", "ID", "Agency", "Details", "Fine Amount"]

    rows =
      timeline
      |> Enum.flat_map(fn {year, actions} ->
        Enum.map(actions, fn action ->
          case action.action_type do
            :case ->
              [
                to_string(year),
                Date.to_string(action.offence_action_date),
                "Case",
                action.regulator_id,
                get_agency_name(action.agency),
                action.offence_breaches || "",
                Decimal.to_string(action.offence_fine || Decimal.new(0))
              ]

            :notice ->
              [
                to_string(year),
                Date.to_string(action.notice_date),
                "Notice",
                action.regulator_id,
                get_agency_name(action.agency),
                action.notice_body || "",
                "N/A"
              ]
          end
        end)
      end)

    [headers | rows]
    |> CSV.encode()
    |> Enum.to_list()
    |> IO.iodata_to_binary()
  end

  defp get_agency_name(%{name: name}), do: name
  defp get_agency_name(_), do: "Unknown"
end
