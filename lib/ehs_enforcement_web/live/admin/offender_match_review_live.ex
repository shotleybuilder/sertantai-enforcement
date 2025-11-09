defmodule EhsEnforcementWeb.Admin.OffenderMatchReviewLive do
  @moduledoc """
  LiveView for manually reviewing medium-confidence Companies House matches.

  Admins can:
  - View list of pending offender review records
  - See top 3 Companies House candidates for each offender
  - Approve a match (sets company_registration_number on offender)
  - Skip/reject matches
  - Flag for later review
  """

  use EhsEnforcementWeb, :live_view

  require Ash.Query

  alias EhsEnforcement.Enforcement

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:page_title, "Review Companies House Matches")
     |> assign(:selected_review, nil)
     |> assign(:show_modal, false)
     |> assign(:filter_status, :pending)
     |> load_reviews()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  defp apply_action(socket, :index, _params) do
    socket
    |> assign(:page_title, "Review Companies House Matches")
    |> assign(:selected_review, nil)
    |> assign(:show_modal, false)
  end

  defp apply_action(socket, :show, %{"id" => id}) do
    case Enforcement.get_review(id) do
      {:ok, review} ->
        # Load the offender relationship
        review = Ash.load!(review, [:offender, :reviewed_by])

        socket
        |> assign(:page_title, "Review Match - #{review.offender.name}")
        |> assign(:selected_review, review)
        |> assign(:show_modal, true)

      {:error, _} ->
        socket
        |> put_flash(:error, "Review record not found")
        |> push_navigate(to: ~p"/admin/offenders/reviews")
    end
  end

  @impl true
  def handle_event("filter_status", %{"status" => status}, socket) do
    filter_status = String.to_existing_atom(status)

    {:noreply,
     socket
     |> assign(:filter_status, filter_status)
     |> load_reviews()}
  end

  def handle_event("select_review", %{"id" => id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/offenders/reviews/#{id}")}
  end

  def handle_event("close_modal", _params, socket) do
    {:noreply, push_patch(socket, to: ~p"/admin/offenders/reviews")}
  end

  def handle_event("approve_match", %{"company_number" => company_number}, socket) do
    review = socket.assigns.selected_review

    # Get current user (assuming it's in session/assigns)
    # For now, we'll use a placeholder - you may need to adjust based on your auth setup
    current_user_id = get_current_user_id(socket)

    case Enforcement.approve_match(review, current_user_id, company_number) do
      {:ok, _updated_review} ->
        {:noreply,
         socket
         |> put_flash(:info, "Match approved! Offender updated with company number.")
         |> push_patch(to: ~p"/admin/offenders/reviews")
         |> load_reviews()}

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to approve match: #{inspect(error)}")}
    end
  end

  def handle_event("skip_match", _params, socket) do
    review = socket.assigns.selected_review
    current_user_id = get_current_user_id(socket)

    case Enforcement.skip_match(review, current_user_id) do
      {:ok, _updated_review} ->
        {:noreply,
         socket
         |> put_flash(:info, "Match skipped.")
         |> push_patch(to: ~p"/admin/offenders/reviews")
         |> load_reviews()}

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to skip match: #{inspect(error)}")}
    end
  end

  def handle_event("flag_for_later", _params, socket) do
    review = socket.assigns.selected_review
    current_user_id = get_current_user_id(socket)

    case Enforcement.flag_for_later(review, current_user_id) do
      {:ok, _updated_review} ->
        {:noreply,
         socket
         |> put_flash(:info, "Flagged for later review.")
         |> push_patch(to: ~p"/admin/offenders/reviews")
         |> load_reviews()}

      {:error, error} ->
        {:noreply,
         socket
         |> put_flash(:error, "Failed to flag: #{inspect(error)}")}
    end
  end

  # Private helpers

  defp load_reviews(socket) do
    filter_status = socket.assigns[:filter_status] || :pending

    reviews =
      case filter_status do
        :all ->
          Enforcement.list_reviews()

        status ->
          Enforcement.reviews_by_status(status)
      end
      |> case do
        {:ok, reviews} ->
          # Load offender relationship for each review
          Ash.load!(reviews, [:offender])

        {:error, _} ->
          []
      end
      |> Enum.sort_by(& &1.confidence_score, :desc)

    assign(socket, :reviews, reviews)
  end

  defp get_current_user_id(socket) do
    # TODO: Get from session/assigns based on your auth setup
    # For now, return a placeholder
    # socket.assigns.current_user.id
    case socket.assigns[:current_user] do
      %{id: id} -> id
      _ -> nil
    end
  end

  defp format_confidence(score) when is_float(score) do
    "#{Float.round(score * 100, 1)}%"
  end

  defp format_confidence(_), do: "N/A"

  defp format_date(nil), do: "N/A"

  defp format_date(%DateTime{} = datetime) do
    Calendar.strftime(datetime, "%Y-%m-%d %H:%M")
  end

  defp confidence_color(score) when is_float(score) and score >= 0.9, do: "text-green-600"
  defp confidence_color(score) when is_float(score) and score >= 0.8, do: "text-yellow-600"
  defp confidence_color(score) when is_float(score), do: "text-orange-600"
  defp confidence_color(_), do: "text-gray-600"

  defp status_badge_color(:pending), do: "bg-yellow-100 text-yellow-800"
  defp status_badge_color(:approved), do: "bg-green-100 text-green-800"
  defp status_badge_color(:skipped), do: "bg-gray-100 text-gray-800"
  defp status_badge_color(:needs_review), do: "bg-red-100 text-red-800"
  defp status_badge_color(_), do: "bg-gray-100 text-gray-800"

  defp days_pending_color(days) when days <= 7, do: "text-gray-600"
  defp days_pending_color(days) when days <= 14, do: "text-yellow-600"
  defp days_pending_color(_), do: "text-red-600"
end
