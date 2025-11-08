defmodule EhsEnforcementWeb.Admin.ScrapeLive do
  @moduledoc """
  Unified admin interface for scraping all agencies and enforcement types.

  This LiveView uses the Strategy Pattern to provide a single interface for:
  - HSE case scraping
  - HSE notice scraping
  - Environment Agency case scraping
  - Environment Agency notice scraping

  The strategy is selected based on URL parameters (:agency and :type),
  and all agency-specific logic is delegated to the appropriate strategy module.

  ## Routes
  - `/admin/scrape/hse/case` - HSE case scraping
  - `/admin/scrape/hse/notice` - HSE notice scraping
  - `/admin/scrape/environment_agency/case` - EA case scraping
  - `/admin/scrape/environment_agency/notice` - EA notice scraping

  ## Features
  - Strategy-based scraping (pluggable agency/type implementations)
  - Real-time progress updates via Phoenix PubSub
  - Strategy-specific parameter forms
  - Unified progress display
  - Error handling and recovery
  """

  use EhsEnforcementWeb, :live_view

  require Logger
  require Ash.Query

  alias EhsEnforcement.Scraping.ScrapeCoordinator
  alias EhsEnforcement.Enforcement.Notice
  alias EhsEnforcement.Enforcement.Case
  alias Phoenix.PubSub
  alias EhsEnforcementWeb.Components.ProgressComponent

  # LiveView Callbacks

  @impl true
  def mount(_params, _session, socket) do
    # Default to HSE agency and convictions database
    agency = :hse
    database = "convictions"
    enforcement_type = derive_enforcement_type(agency, database)
    strategy = determine_strategy(agency, database)

    socket =
      socket
      |> assign(:agency, agency)
      |> assign(:database, database)
      |> assign(:enforcement_type, enforcement_type)
      |> assign(:strategy, strategy)
      |> assign(:strategy_name, strategy.strategy_name())
      |> assign(:current_session, nil)
      |> assign(:scraping_active, false)
      |> assign(:scraping_session_started_at, nil)
      |> assign(:progress, initial_progress())
      |> assign(:form_params, default_form_params(agency, database))
      |> assign(:validation_errors, %{})
      |> assign(:loading, false)
      |> assign(:scraped_records, [])

    # Add reactive data loading when connected
    if connected?(socket) do
      # Subscribe to PubSub events for progress tracking
      :ok = PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:created")
      :ok = PubSub.subscribe(EhsEnforcement.PubSub, "scrape_session:updated")

      # Subscribe to ProcessingLog for scraped record display (batch updates)
      # ProcessingLog fires for ALL records (created, updated, existing) at end of batch
      :ok = PubSub.subscribe(EhsEnforcement.PubSub, "processing_log:created")

      # Subscribe to real-time individual record scraping events
      # These fire immediately after each record is processed (every 3 seconds for EA)
      case enforcement_type do
        :notice ->
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "notice:scraped")
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "notice:created")
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "notice:updated")

        :case ->
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped")
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "case:created")
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "case:updated")
      end

      # Add reactive data loading with keep_live
      socket = add_reactive_data_loading(socket, enforcement_type)
      {:ok, socket}
    else
      # Initialize empty assigns for disconnected state
      socket =
        socket
        |> assign(:recent_records, [])
        |> assign(:session_results, [])

      {:ok, socket}
    end
  end

  @impl true
  def handle_event("start_scraping", params, socket) do
    strategy = socket.assigns.strategy

    # Validate parameters using strategy
    case strategy.validate_params(params) do
      {:ok, validated_params} ->
        # Start scraping session in background task
        opts =
          [
            agency: socket.assigns.agency,
            enforcement_type: socket.assigns.enforcement_type
          ] ++ Map.to_list(validated_params)

        # Run scraping in background Task so LiveView can process PubSub messages
        task =
          Task.async(fn ->
            ScrapeCoordinator.start_scraping_session(opts)
          end)

        Logger.info("Starting scraping task",
          agency: socket.assigns.agency,
          type: socket.assigns.enforcement_type
        )

        socket =
          socket
          |> assign(:scraping_active, true)
          |> assign(:scraping_task, task)
          |> assign(:scraping_session_started_at, DateTime.utc_now())
          |> assign(:scraped_records, [])
          |> assign(:validation_errors, %{})
          |> put_flash(:info, "Scraping started successfully")

        {:noreply, socket}

      {:error, reason} ->
        Logger.warning("Invalid scraping parameters",
          agency: socket.assigns.agency,
          type: socket.assigns.enforcement_type,
          reason: reason
        )

        socket =
          socket
          |> assign(:validation_errors, %{general: reason})
          |> put_flash(:error, "Invalid parameters: #{reason}")

        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("clear_session", _params, socket) do
    socket =
      socket
      |> assign(:current_session, nil)
      |> assign(:scraping_active, false)
      |> assign(:progress, initial_progress())
      |> assign(:validation_errors, %{})
      |> put_flash(:info, "Session cleared")

    {:noreply, socket}
  end

  @impl true
  def handle_event("clear_scraped_records", _params, socket) do
    socket =
      socket
      |> assign(:scraped_records, [])
      |> assign(:scraping_session_started_at, nil)
      |> put_flash(:info, "Scraped records cleared")

    {:noreply, socket}
  end

  @impl true
  def handle_event("stop_scraping", _params, socket) do
    # Kill the background scraping task if it exists
    _ =
      if socket.assigns[:scraping_task] do
        Task.shutdown(socket.assigns.scraping_task, :brutal_kill)
      end

    socket =
      socket
      |> assign(:scraping_active, false)
      |> assign(:scraping_task, nil)
      |> put_flash(:info, "Scraping stopped")

    {:noreply, socket}
  end

  @impl true
  def handle_event("validate_params", params, socket) do
    strategy = socket.assigns.strategy

    # CRITICAL: Update form_params with user input to maintain form state
    # Merge params into existing form_params to preserve user edits
    updated_form_params = Map.merge(socket.assigns.form_params, params)

    # Only validate if dates appear complete (avoid validating partial input)
    should_validate = dates_complete?(params)

    if should_validate do
      case strategy.validate_params(params) do
        {:ok, _validated} ->
          socket =
            socket
            |> assign(:form_params, updated_form_params)
            |> assign(:validation_errors, %{})

          {:noreply, socket}

        {:error, reason} ->
          socket =
            socket
            |> assign(:form_params, updated_form_params)
            |> assign(:validation_errors, %{general: reason})

          {:noreply, socket}
      end
    else
      # Don't validate incomplete dates - just update form params
      socket =
        socket
        |> assign(:form_params, updated_form_params)
        |> assign(:validation_errors, %{})

      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("select_agency", %{"agency" => agency_str}, socket) do
    # Parse agency string to atom
    agency = String.to_existing_atom(agency_str)

    # Get default database for this agency
    {default_database, default_enforcement_type} =
      case agency do
        :hse -> {"convictions", :case}
        :ea -> {"cases", :case}
      end

    # Determine new strategy
    strategy = determine_strategy(agency, default_database)

    # Update socket with new agency, database, enforcement type, strategy, and form params
    socket =
      socket
      |> assign(:agency, agency)
      |> assign(:database, default_database)
      |> assign(:enforcement_type, default_enforcement_type)
      |> assign(:strategy, strategy)
      |> assign(:strategy_name, strategy.strategy_name())
      |> assign(:form_params, default_form_params(agency, default_database))
      |> assign(:validation_errors, %{})

    {:noreply, socket}
  end

  @impl true
  def handle_event("select_database", %{"database" => database}, socket) do
    agency = socket.assigns.agency

    # Derive enforcement type from database
    enforcement_type = derive_enforcement_type(agency, database)

    # Determine new strategy
    strategy = determine_strategy(agency, database)

    # CRITICAL: Unsubscribe from old enforcement type topics
    old_enforcement_type = socket.assigns.enforcement_type

    if old_enforcement_type != enforcement_type do
      Logger.info(
        "🔄 Enforcement type changed from #{old_enforcement_type} to #{enforcement_type}, updating PubSub subscriptions"
      )

      # Unsubscribe from old topics
      case old_enforcement_type do
        :notice ->
          :ok = PubSub.unsubscribe(EhsEnforcement.PubSub, "notice:scraped")
          :ok = PubSub.unsubscribe(EhsEnforcement.PubSub, "notice:created")
          :ok = PubSub.unsubscribe(EhsEnforcement.PubSub, "notice:updated")

        :case ->
          :ok = PubSub.unsubscribe(EhsEnforcement.PubSub, "case:scraped")
          :ok = PubSub.unsubscribe(EhsEnforcement.PubSub, "case:created")
          :ok = PubSub.unsubscribe(EhsEnforcement.PubSub, "case:updated")
      end

      # Subscribe to new topics
      case enforcement_type do
        :notice ->
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "notice:scraped")
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "notice:created")
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "notice:updated")

        :case ->
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "case:scraped")
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "case:created")
          :ok = PubSub.subscribe(EhsEnforcement.PubSub, "case:updated")
      end
    end

    # Update socket with new database, enforcement type, strategy, and form params
    socket =
      socket
      |> assign(:database, database)
      |> assign(:enforcement_type, enforcement_type)
      |> assign(:strategy, strategy)
      |> assign(:strategy_name, strategy.strategy_name())
      |> assign(:form_params, default_form_params(agency, database))
      |> assign(:validation_errors, %{})

    {:noreply, socket}
  end

  # PubSub Event Handlers

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "scrape_session:created",
          event: "create",
          payload: %Ash.Notifier.Notification{data: session_data}
        },
        socket
      ) do
    # Check if this session is for our agency/type
    if session_matches?(session_data, socket.assigns.agency, socket.assigns.enforcement_type) do
      Logger.debug("Scrape session created",
        session_id: session_data.id,
        agency: socket.assigns.agency,
        type: socket.assigns.enforcement_type
      )

      socket =
        socket
        |> assign(:current_session, session_data)
        |> assign(:scraping_active, true)
        |> update_progress_from_session(session_data)

      {:noreply, socket}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "scrape_session:updated",
          event: "update",
          payload: %Ash.Notifier.Notification{data: session_data}
        },
        socket
      ) do
    # Check if this is our current session
    current_session = socket.assigns.current_session

    Logger.debug("Received scrape_session:updated broadcast",
      session_id: session_data.session_id,
      session_db_id: session_data.id,
      current_session_id: current_session && current_session.id,
      matches: current_session && current_session.id == session_data.id,
      cases_processed: session_data.cases_processed,
      cases_found: session_data.cases_found
    )

    if current_session && current_session.id == session_data.id do
      Logger.debug("Scrape session updated - UPDATING UI",
        session_id: session_data.id,
        status: session_data.status,
        progress: calculate_session_progress(session_data, socket.assigns.strategy)
      )

      socket =
        socket
        |> assign(:current_session, session_data)
        |> assign(:scraping_active, session_data.status == :running)
        |> update_progress_from_session(session_data)

      {:noreply, socket}
    else
      Logger.debug("Scrape session updated - SKIPPING (not our session)")
      {:noreply, socket}
    end
  end

  # Template Rendering

  # Handle real-time individual notice scraping events
  @impl true
  def handle_info({:record_scraped, %{record: notice, status: status, type: :notice}}, socket) do
    Logger.info(
      "🔔 Received real-time notice:scraped event - regulator_id: #{notice.regulator_id}, status: #{status}"
    )

    Logger.debug(
      "📊 LiveView state - scraping_session_started_at: #{inspect(socket.assigns.scraping_session_started_at)}"
    )

    Logger.debug(
      "📊 LiveView state - current scraped_records count: #{length(socket.assigns.scraped_records)}"
    )

    Logger.debug(
      "📊 LiveView state - enforcement_type: #{socket.assigns.enforcement_type}, agency: #{socket.assigns.agency}"
    )

    # Load full notice with associations
    notice_with_assoc =
      try do
        Notice
        |> Ash.get!(notice.id, load: [:agency, :offender], actor: socket.assigns.current_user)
        |> Map.put(:processing_status, status)
      rescue
        e ->
          Logger.warning("Failed to reload notice with associations: #{inspect(e)}")
          Map.put(notice, :processing_status, status)
      end

    # Remove any existing entry for this notice (deduplicate by regulator_id)
    existing_records =
      Enum.reject(socket.assigns.scraped_records, fn existing ->
        existing.regulator_id == notice.regulator_id
      end)

    # Add to the beginning of the list (most recent first)
    updated_scraped_records = [notice_with_assoc | existing_records]

    # Keep only the most recent 100 records
    updated_scraped_records = Enum.take(updated_scraped_records, 100)

    Logger.debug(
      "✅ Added notice to scraped_records in real-time: #{notice.regulator_id}, new count: #{length(updated_scraped_records)}"
    )

    socket = assign(socket, scraped_records: updated_scraped_records)

    {:noreply, socket}
  end

  # Handle real-time individual case scraping events
  @impl true
  def handle_info({:record_scraped, %{record: case_record, status: status, type: :case}}, socket) do
    Logger.info(
      "🔔 Received real-time case:scraped event - regulator_id: #{case_record.regulator_id}, status: #{status}"
    )

    Logger.debug(
      "📊 LiveView state - scraping_session_started_at: #{inspect(socket.assigns.scraping_session_started_at)}"
    )

    Logger.debug(
      "📊 LiveView state - current scraped_records count: #{length(socket.assigns.scraped_records)}"
    )

    Logger.debug(
      "📊 LiveView state - enforcement_type: #{socket.assigns.enforcement_type}, agency: #{socket.assigns.agency}"
    )

    # Load full case with associations
    case_with_assoc =
      try do
        Case
        |> Ash.get!(case_record.id,
          load: [:agency, :offender],
          actor: socket.assigns.current_user
        )
        |> Map.put(:processing_status, status)
      rescue
        e ->
          Logger.warning("Failed to reload case with associations: #{inspect(e)}")
          Map.put(case_record, :processing_status, status)
      end

    # Remove any existing entry for this case (deduplicate by regulator_id)
    existing_records =
      Enum.reject(socket.assigns.scraped_records, fn existing ->
        existing.regulator_id == case_record.regulator_id
      end)

    # Add to the beginning of the list (most recent first)
    updated_scraped_records = [case_with_assoc | existing_records]

    # Keep only the most recent 100 records
    updated_scraped_records = Enum.take(updated_scraped_records, 100)

    Logger.debug(
      "✅ Added case to scraped_records in real-time: #{case_record.regulator_id}, new count: #{length(updated_scraped_records)}"
    )

    socket = assign(socket, scraped_records: updated_scraped_records)

    {:noreply, socket}
  end

  # Handle ProcessingLog creation - this fires for ALL scraped records (created, updated, existing)
  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "processing_log:created",
          payload: %Ash.Notifier.Notification{} = notification
        },
        socket
      ) do
    Logger.info("🔔 Received processing_log:created broadcast")

    Logger.info(
      "🔔 ProcessingLog data: items_found=#{notification.data.items_found}, items_created=#{notification.data.items_created}, items_existing=#{notification.data.items_existing}"
    )

    socket =
      if socket.assigns.scraping_session_started_at do
        # ProcessingLog contains scraped_items array with regulator_ids
        # Load full records for each scraped item
        scraped_items = notification.data.scraped_items || []

        Logger.info("🔔 Processing #{length(scraped_items)} scraped items")

        # Load full records based on enforcement type
        loaded_records =
          case socket.assigns.enforcement_type do
            :notice ->
              load_notices_from_scraped_items(scraped_items, socket.assigns.current_user)

            :case ->
              load_cases_from_scraped_items(scraped_items, socket.assigns.current_user)
          end

        Logger.info("🔔 Loaded #{length(loaded_records)} full records")

        # Add all loaded records to scraped_records
        updated_scraped_records = loaded_records ++ socket.assigns.scraped_records

        # Keep only the most recent 100 records
        updated_scraped_records = Enum.take(updated_scraped_records, 100)

        assign(socket, scraped_records: updated_scraped_records)
      else
        socket
      end

    {:noreply, socket}
  end

  # Handle record creation during active scraping - notices
  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "notice:created",
          event: "create",
          payload: %Ash.Notifier.Notification{} = notification
        },
        socket
      ) do
    Logger.info(
      "🔔 Received notice:created broadcast - notification data: #{inspect(notification.data)}"
    )

    Logger.info(
      "🔔 Current scraping_session_started_at: #{inspect(socket.assigns.scraping_session_started_at)}"
    )

    # Only add to scraped_records if we have an active session
    socket =
      if socket.assigns.scraping_session_started_at do
        # Load full notice data with associations
        notice =
          Notice
          |> Ash.get!(notification.data.id,
            load: [:agency, :offender],
            actor: socket.assigns.current_user
          )

        # Get processing status from notification metadata or default to :created
        processing_status = notification.metadata[:processing_status] || :created

        # Add processing status to notice for template use
        notice_with_status = Map.put(notice, :processing_status, processing_status)

        # Remove any existing entry for this notice (deduplicate by regulator_id)
        existing_records =
          Enum.reject(socket.assigns.scraped_records, fn existing ->
            existing.regulator_id == notice.regulator_id
          end)

        # Add to the beginning of the list (most recent first)
        updated_scraped_records = [notice_with_status | existing_records]

        # Keep only the most recent 100 records
        updated_scraped_records = Enum.take(updated_scraped_records, 100)

        Logger.debug(
          "Added notice to scraped_records: #{notice.regulator_id} (status: #{processing_status})"
        )

        assign(socket, scraped_records: updated_scraped_records)
      else
        socket
      end

    {:noreply, socket}
  end

  # Handle record creation during active scraping - cases
  @impl true
  def handle_info(
        %Phoenix.Socket.Broadcast{
          topic: "case:created",
          event: "create",
          payload: %Ash.Notifier.Notification{} = notification
        },
        socket
      ) do
    Logger.info(
      "🔔 Received case:created broadcast - notification data: #{inspect(notification.data)}"
    )

    Logger.info(
      "🔔 Current scraping_session_started_at: #{inspect(socket.assigns.scraping_session_started_at)}"
    )

    # Only add to scraped_records if we have an active session
    socket =
      if socket.assigns.scraping_session_started_at do
        # Load full case data with associations
        case_record =
          Case
          |> Ash.get!(notification.data.id,
            load: [:agency, :offender],
            actor: socket.assigns.current_user
          )

        # Get processing status from notification metadata or default to :created
        processing_status = notification.metadata[:processing_status] || :created

        # Add processing status to case for template use
        case_with_status = Map.put(case_record, :processing_status, processing_status)

        # Remove any existing entry for this case (deduplicate by regulator_id)
        existing_records =
          Enum.reject(socket.assigns.scraped_records, fn existing ->
            existing.regulator_id == case_record.regulator_id
          end)

        # Add to the beginning of the list (most recent first)
        updated_scraped_records = [case_with_status | existing_records]

        # Keep only the most recent 100 records
        updated_scraped_records = Enum.take(updated_scraped_records, 100)

        Logger.debug(
          "Added case to scraped_records: #{case_record.regulator_id} (status: #{processing_status})"
        )

        assign(socket, scraped_records: updated_scraped_records)
      else
        socket
      end

    {:noreply, socket}
  end

  # Handle case updates during active scraping - for when existing cases are updated
  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "case:scraped:updated"} = broadcast, socket) do
    Logger.info(
      "🔔 Received case:scraped:updated broadcast - payload: #{inspect(broadcast.payload)}"
    )

    Logger.info(
      "🔔 Current scraping_session_started_at: #{inspect(socket.assigns.scraping_session_started_at)}"
    )

    # Only add to scraped_records if we have an active session
    socket =
      if socket.assigns.scraping_session_started_at do
        case broadcast.payload do
          %Ash.Notifier.Notification{} = notification ->
            # Load full case data with associations
            case_record =
              Case
              |> Ash.get!(notification.data.id,
                load: [:agency, :offender],
                actor: socket.assigns.current_user
              )

            # Get processing status from notification metadata or default to :updated
            processing_status = notification.metadata[:processing_status] || :updated

            # Add processing status to case for template use
            case_with_status = Map.put(case_record, :processing_status, processing_status)

            # Remove any existing entry for this case (deduplicate by regulator_id)
            existing_records =
              Enum.reject(socket.assigns.scraped_records, fn existing ->
                existing.regulator_id == case_record.regulator_id
              end)

            # Add to the beginning of the list (most recent first)
            updated_scraped_records = [case_with_status | existing_records]

            # Keep only the most recent 100 records
            updated_scraped_records = Enum.take(updated_scraped_records, 100)

            Logger.debug(
              "Added/updated case in scraped_records: #{case_record.regulator_id} (status: #{processing_status})"
            )

            assign(socket, scraped_records: updated_scraped_records)

          _ ->
            socket
        end
      else
        socket
      end

    {:noreply, socket}
  end

  # Ignore other PubSub events and handle Task completion
  @impl true
  def handle_info({ref, {:ok, _session_id}}, socket) when is_reference(ref) do
    # Task completed successfully
    Process.demonitor(ref, [:flush])
    Logger.info("Scraping task completed successfully")
    {:noreply, socket}
  end

  @impl true
  def handle_info({ref, {:error, reason}}, socket) when is_reference(ref) do
    # Task failed
    Process.demonitor(ref, [:flush])
    Logger.error("Scraping task failed: #{inspect(reason)}")

    socket =
      socket
      |> assign(:scraping_active, false)
      |> assign(:scraping_task, nil)
      |> put_flash(:error, "Scraping failed: #{inspect(reason)}")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    # Task process died
    {:noreply, socket}
  end

  @impl true
  def handle_info(msg, socket) do
    Logger.debug("⚠️ Unhandled message: #{inspect(msg)}")
    {:noreply, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-6xl mx-auto p-6">
      <!-- Page Header -->
      <div class="mb-8">
        <h1 class="text-3xl font-bold text-gray-900">UK Enforcement Data Scraping</h1>
        <p class="mt-2 text-gray-600">
          Manually trigger enforcement data scraping from UK regulatory agencies with real-time progress monitoring
        </p>
        
    <!-- Navigation Links -->
        <div class="mt-4 flex flex-wrap gap-3">
          <.link
            navigate={~p"/admin"}
            class="inline-flex items-center px-3 py-2 border border-gray-300 shadow-sm text-sm leading-4 font-medium rounded-md text-gray-700 bg-white hover:bg-gray-50 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M10 19l-7-7m0 0l7-7m-7 7h18"
              />
            </svg>
            Admin Dashboard
          </.link>

          <.link
            navigate={~p"/admin/scrape-sessions"}
            class="inline-flex items-center px-3 py-2 border border-blue-300 shadow-sm text-sm leading-4 font-medium rounded-md text-blue-700 bg-blue-50 hover:bg-blue-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500"
          >
            <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z"
              />
            </svg>
            View Sessions
          </.link>

          <.link
            navigate={~p"/admin/scrape-sessions-design"}
            class="inline-flex items-center px-3 py-2 border border-purple-300 shadow-sm text-sm leading-4 font-medium rounded-md text-purple-700 bg-purple-50 hover:bg-purple-100 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-purple-500"
          >
            <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path
                stroke-linecap="round"
                stroke-linejoin="round"
                stroke-width="2"
                d="M7 21a4 4 0 01-4-4V5a2 2 0 012-2h4a2 2 0 012 2v12a4 4 0 01-4 4zm0 0h12a2 2 0 002-2v-4a2 2 0 00-2-2h-2.343M11 7.343l1.657-1.657a2 2 0 012.828 0l2.829 2.829a2 2 0 010 2.828l-8.486 8.485M7 17h.01"
              />
            </svg>
            Sessions Design
          </.link>
        </div>
      </div>
      
    <!-- Flash Messages -->
      <.flash_group flash={@flash} />
      
    <!-- 2-Column Grid Layout -->
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <!-- Left Column: Scraping Configuration (2/3 width) -->
        <div class="lg:col-span-2">
          <div class="bg-white rounded-lg shadow-sm border border-gray-200 p-6">
            <h2 class="text-xl font-semibold text-gray-900 mb-4">Scraping Configuration</h2>

            <.form for={%{}} phx-submit="start_scraping">
              <!-- Agency Selection -->
              <div class="mb-6">
                <label class="block text-sm font-medium text-gray-700 mb-2">Agency</label>
                <div class="flex space-x-3">
                  <button
                    type="button"
                    phx-click="select_agency"
                    phx-value-agency="hse"
                    disabled={@scraping_active}
                    class={"flex-1 px-4 py-2 rounded-md text-sm font-medium transition-colors #{if @agency == :hse, do: "bg-blue-600 text-white", else: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"} #{if @scraping_active, do: "opacity-50 cursor-not-allowed"}"}
                  >
                    HSE (Health & Safety Executive)
                  </button>
                  <button
                    type="button"
                    phx-click="select_agency"
                    phx-value-agency="ea"
                    disabled={@scraping_active}
                    class={"flex-1 px-4 py-2 rounded-md text-sm font-medium transition-colors #{if @agency == :ea, do: "bg-blue-600 text-white", else: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50"} #{if @scraping_active, do: "opacity-50 cursor-not-allowed"}"}
                  >
                    Environment Agency (EA)
                  </button>
                </div>
              </div>
              
    <!-- Database/Type Selection -->
              <div class="mb-6">
                <label for="database" class="block text-sm font-medium text-gray-700 mb-2">
                  {database_label(@agency)}
                </label>
                <select
                  name="database"
                  id="database"
                  phx-change="select_database"
                  disabled={@scraping_active}
                  class="block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <%= for option <- database_options(@agency) do %>
                    <option value={option.value} selected={@database == option.value}>
                      {option.label}
                    </option>
                  <% end %>
                </select>
                <p class="mt-1 text-sm text-gray-500">
                  {database_help_text(@agency, @database)}
                </p>
              </div>
              
    <!-- Agency-Specific Parameters -->
              {render_form_fields(assigns)}
              
    <!-- Submit Button -->
              <div class="mt-6 flex items-center justify-between">
                <div class="text-sm text-gray-500">
                  <%= if @scraping_active do %>
                    <span class="inline-flex items-center">
                      <svg
                        class="animate-spin h-4 w-4 mr-2 text-blue-600"
                        fill="none"
                        viewBox="0 0 24 24"
                      >
                        <circle
                          class="opacity-25"
                          cx="12"
                          cy="12"
                          r="10"
                          stroke="currentColor"
                          stroke-width="4"
                        >
                        </circle>
                        <path
                          class="opacity-75"
                          fill="currentColor"
                          d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"
                        >
                        </path>
                      </svg>
                      Scraping in progress...
                    </span>
                  <% else %>
                    <span>Ready to start scraping</span>
                  <% end %>
                </div>

                <button
                  type="submit"
                  disabled={@scraping_active}
                  class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-blue-500 disabled:opacity-50 disabled:cursor-not-allowed"
                >
                  <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z"
                    />
                    <path
                      stroke-linecap="round"
                      stroke-linejoin="round"
                      stroke-width="2"
                      d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z"
                    />
                  </svg>
                  Start Scraping
                </button>
              </div>

              <%= if @validation_errors[:general] do %>
                <div class="mt-4 p-4 bg-red-50 border border-red-200 rounded-md">
                  <p class="text-sm text-red-700">{@validation_errors[:general]}</p>
                </div>
              <% end %>
            </.form>
          </div>
        </div>
        
    <!-- Right Column: Progress Display (1/3 width) -->
        <div class="lg:col-span-1">
          {render_progress(assigns)}
        </div>
      </div>
      
    <!-- Live Scraped Records (During Active Session) -->
      <%= if length(@scraped_records) > 0 do %>
        <div class="mt-8 bg-white shadow rounded-lg border border-gray-200 mb-8">
          <div class="px-6 py-4 border-b border-gray-200">
            <div class="flex items-center justify-between">
              <div>
                <h2 class="text-lg font-medium text-gray-900">
                  Scraped {String.capitalize(to_string(@enforcement_type))}s (This Session)
                </h2>
                <p class="mt-1 text-sm text-gray-500">
                  {length(@scraped_records)} {type_display_name(@enforcement_type)}s scraped in current session
                </p>
              </div>
              <div class="flex gap-2">
                <%= if @scraping_active do %>
                  <button
                    type="button"
                    phx-click="stop_scraping"
                    class="px-3 py-1.5 text-sm font-medium text-white bg-red-600 hover:bg-red-700 rounded-md"
                  >
                    Stop Scraping
                  </button>
                <% end %>
                <button
                  type="button"
                  phx-click="clear_scraped_records"
                  class="text-sm text-gray-500 hover:text-gray-700"
                >
                  Clear
                </button>
              </div>
            </div>
          </div>
          <div class="px-6 py-4">
            {render_scraped_records(assigns)}
          </div>
        </div>
      <% end %>
    </div>
    """
  end

  # Private Helper Functions

  # Check if date parameters are complete enough to validate
  # Returns false if dates are clearly incomplete (user still typing)
  defp dates_complete?(params) do
    date_from = params["date_from"] || params[:date_from]
    date_to = params["date_to"] || params[:date_to]

    # If no dates in params, consider complete (might be HSE scraping which doesn't use dates)
    if is_nil(date_from) and is_nil(date_to) do
      true
    else
      # Check if dates look complete (YYYY-MM-DD format with all parts filled)
      date_from_complete? = date_looks_complete?(date_from)
      date_to_complete? = date_looks_complete?(date_to)

      # Both dates should be complete before validating
      # OR if only one is present (date_from), it should be complete
      case {date_from, date_to} do
        {nil, nil} -> true
        {_from, nil} -> date_from_complete?
        {nil, _to} -> date_to_complete?
        {_from, _to} -> date_from_complete? and date_to_complete?
      end
    end
  end

  # Check if a single date string looks complete
  # Accepts YYYY-MM-DD or DD/MM/YYYY formats
  defp date_looks_complete?(nil), do: false
  defp date_looks_complete?(""), do: false

  defp date_looks_complete?(date) when is_binary(date) do
    # Check for YYYY-MM-DD format (10 chars minimum)
    # Check for DD/MM/YYYY format (10 chars minimum)
    # Partial dates like "dd/" or "dd/mm/" should return false
    String.length(date) >= 10 and
      (String.match?(date, ~r/^\d{4}-\d{2}-\d{2}$/) or
         String.match?(date, ~r/^\d{2}\/\d{2}\/\d{4}$/))
  end

  defp date_looks_complete?(%Date{}), do: true
  defp date_looks_complete?(_), do: false

  defp add_reactive_data_loading(socket, _enforcement_type) do
    # No reactive data loading needed - we only show current session data
    socket
  end

  # Strategy determination based on agency and database selection
  defp determine_strategy(:hse, "convictions"),
    do: EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy

  defp determine_strategy(:hse, "appeals"),
    do: EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy

  defp determine_strategy(:hse, "notices"),
    do: EhsEnforcement.Scraping.Strategies.HSE.NoticeStrategy

  defp determine_strategy(:ea, "cases"), do: EhsEnforcement.Scraping.Strategies.EA.CaseStrategy

  defp determine_strategy(:ea, "notices"),
    do: EhsEnforcement.Scraping.Strategies.EA.NoticeStrategy

  # Derive enforcement type from agency and database selection
  defp derive_enforcement_type(:hse, "notices"), do: :notice
  # convictions or appeals
  defp derive_enforcement_type(:hse, _database), do: :case
  defp derive_enforcement_type(:ea, "notices"), do: :notice
  defp derive_enforcement_type(:ea, "cases"), do: :case

  # UI helper functions for database selection
  defp database_label(:hse), do: "Select Database"
  defp database_label(:ea), do: "Select Enforcement Type"

  defp database_options(:hse) do
    [
      %{value: "convictions", label: "Convictions (Court Cases)"},
      %{value: "appeals", label: "Appeals (Court Cases)"},
      %{value: "notices", label: "Notices (Enforcement Notices)"}
    ]
  end

  defp database_options(:ea) do
    [
      %{value: "cases", label: "Court Cases"},
      %{value: "notices", label: "Enforcement Notices"}
    ]
  end

  defp database_help_text(:hse, "convictions"),
    do: "Scrape HSE conviction cases from the convictions database"

  defp database_help_text(:hse, "appeals"),
    do: "Scrape HSE appeal cases from the appeals database"

  defp database_help_text(:hse, "notices"),
    do: "Scrape HSE enforcement notices from the notices database"

  defp database_help_text(:ea, "cases"), do: "Scrape EA court cases (date range required)"

  defp database_help_text(:ea, "notices"),
    do: "Scrape EA enforcement notices (date range required)"

  defp database_help_text(_, _), do: "Select a database to begin scraping"

  defp initial_progress do
    %{
      status: :idle,
      current_page: nil,
      pages_processed: 0,
      cases_found: 0,
      cases_processed: 0,
      cases_created: 0,
      cases_created_current_page: 0,
      cases_updated: 0,
      cases_updated_current_page: 0,
      cases_exist_total: 0,
      cases_exist_current_page: 0,
      errors_count: 0,
      max_pages: nil
    }
  end

  defp default_form_params(agency, database) do
    case agency do
      :hse ->
        # HSE parameters - include database selection
        base_params = %{
          "start_page" => "1",
          "max_pages" => "10",
          "database" => database
        }

        # Add country for notice database
        if database == "notices" do
          Map.put(base_params, "country", "England")
        else
          base_params
        end

      :ea ->
        # EA parameters - determine action types from database
        action_types =
          case database do
            "cases" -> ["court_case"]
            "notices" -> ["enforcement_notice"]
            # Default fallback
            _ -> ["court_case"]
          end

        %{
          "date_from" => Date.add(Date.utc_today(), -30) |> Date.to_string(),
          "date_to" => Date.utc_today() |> Date.to_string(),
          "action_types" => action_types
        }
    end
  end

  defp session_matches?(session, agency, enforcement_type) do
    # Normalize agency names for comparison
    # LiveView uses :ea, but database stores :environment_agency
    normalized_session_agency = normalize_agency(session.agency)
    normalized_agency = normalize_agency(agency)

    # Match on agency first
    if normalized_session_agency != normalized_agency do
      false
    else
      # Derive enforcement type from session data
      session_enforcement_type = derive_enforcement_type_from_session(session)
      session_enforcement_type == enforcement_type
    end
  end

  # Normalize agency names to a common format
  defp normalize_agency(:ea), do: :environment_agency
  defp normalize_agency(:environment_agency), do: :environment_agency
  defp normalize_agency(:hse), do: :hse
  defp normalize_agency(other), do: other

  defp derive_enforcement_type_from_session(session) do
    cond do
      # HSE: check database field
      session.agency == :hse && session.database == "notices" ->
        :notice

      session.agency == :hse ->
        :case

      # EA: check action_types
      session.agency == :environment_agency && session.action_types == [:enforcement_notice] ->
        :notice

      session.agency == :environment_agency ->
        :case

      # Default fallback
      true ->
        :case
    end
  end

  defp update_progress_from_session(socket, session) do
    strategy = socket.assigns.strategy
    progress_display = strategy.format_progress_display(session)

    assign(socket, :progress, progress_display)
  end

  defp calculate_session_progress(session, strategy) do
    strategy.calculate_progress(session)
  end

  defp type_display_name(:case), do: "Cases"
  defp type_display_name(:notice), do: "Notices"
  defp type_display_name(type), do: to_string(type)

  # Scraped Records Rendering (Live session updates)

  defp render_scraped_records(%{enforcement_type: :notice, scraped_records: records} = assigns) do
    assigns = assign(assigns, :records, records)

    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Notice ID
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Recipient
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Notice Type
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Issue Date
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Compliance Date
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Status
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Processed
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <%= for notice <- @records do %>
            <tr class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900">
                {notice.regulator_id}
              </td>
              <td class="px-6 py-4 text-sm text-gray-900">
                <div class="max-w-48 truncate">
                  {(notice.offender && notice.offender.name) || "N/A"}
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {notice.offence_action_type || "N/A"}
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <%= if notice.notice_date do %>
                  {Calendar.strftime(notice.notice_date, "%Y-%m-%d")}
                <% else %>
                  <%= if notice.offence_action_date do %>
                    {Calendar.strftime(notice.offence_action_date, "%Y-%m-%d")}
                  <% else %>
                    N/A
                  <% end %>
                <% end %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <%= if notice.compliance_date do %>
                  {Calendar.strftime(notice.compliance_date, "%Y-%m-%d")}
                <% else %>
                  N/A
                <% end %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <%= case Map.get(notice, :processing_status, :unknown) do %>
                  <% :created -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Created
                    </span>
                  <% :updated -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      Updated
                    </span>
                  <% :existing -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                      Exists
                    </span>
                  <% _ -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                      Unknown
                    </span>
                <% end %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {Calendar.strftime(notice.updated_at, "%H:%M:%S")}
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  defp render_scraped_records(%{enforcement_type: :case, scraped_records: records} = assigns) do
    assigns = assign(assigns, :records, records)

    ~H"""
    <div class="overflow-x-auto">
      <table class="min-w-full divide-y divide-gray-200">
        <thead class="bg-gray-50">
          <tr>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Regulator ID
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Offender
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Date
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Fine
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Status
            </th>
            <th class="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">
              Processed
            </th>
          </tr>
        </thead>
        <tbody class="bg-white divide-y divide-gray-200">
          <%= for case <- @records do %>
            <tr class="hover:bg-gray-50">
              <td class="px-6 py-4 whitespace-nowrap text-sm font-mono text-gray-900">
                {case.regulator_id}
              </td>
              <td class="px-6 py-4 text-sm text-gray-900">
                <div class="max-w-48 truncate">
                  {(case.offender && case.offender.name) || "N/A"}
                </div>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                <%= if case.offence_action_date do %>
                  {Calendar.strftime(case.offence_action_date, "%Y-%m-%d")}
                <% else %>
                  N/A
                <% end %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-900">
                <%= if case.offence_fine && Decimal.positive?(case.offence_fine) do %>
                  £{Decimal.to_string(case.offence_fine, :normal)}
                <% else %>
                  N/A
                <% end %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap">
                <%= case Map.get(case, :processing_status, :unknown) do %>
                  <% :created -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800">
                      Created
                    </span>
                  <% :updated -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800">
                      Updated
                    </span>
                  <% :existing -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800">
                      Exists
                    </span>
                  <% _ -> %>
                    <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-yellow-100 text-yellow-800">
                      Unknown
                    </span>
                <% end %>
              </td>
              <td class="px-6 py-4 whitespace-nowrap text-sm text-gray-500">
                {Calendar.strftime(case.updated_at, "%H:%M:%S")}
              </td>
            </tr>
          <% end %>
        </tbody>
      </table>
    </div>
    """
  end

  # Form Rendering

  defp render_form_fields(%{agency: :hse} = assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-4 md:grid-cols-2 mb-6">
      <div>
        <label for="start_page" class="block text-sm font-medium text-gray-700">
          Start Page
        </label>
        <input
          type="number"
          name="start_page"
          id="start_page"
          value={@form_params["start_page"]}
          min="1"
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
          required
        />
      </div>

      <div>
        <label for="max_pages" class="block text-sm font-medium text-gray-700">
          End Page
        </label>
        <input
          type="number"
          name="max_pages"
          id="max_pages"
          value={@form_params["max_pages"]}
          min="1"
          max="1000"
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
          required
        />
      </div>
    </div>
    <!-- Hidden database field to submit with form -->
    <input type="hidden" name="database" value={@database} />
    """
  end

  defp render_form_fields(%{agency: :ea} = assigns) do
    ~H"""
    <div class="grid grid-cols-1 gap-4 md:grid-cols-2 mb-6">
      <div>
        <label for="date_from" class="block text-sm font-medium text-gray-700">
          From Date
        </label>
        <input
          type="date"
          name="date_from"
          id="date_from"
          value={@form_params["date_from"]}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
          required
        />
      </div>

      <div>
        <label for="date_to" class="block text-sm font-medium text-gray-700">
          To Date
        </label>
        <input
          type="date"
          name="date_to"
          id="date_to"
          value={@form_params["date_to"]}
          class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-blue-500 focus:ring-blue-500 sm:text-sm"
          required
        />
      </div>
    </div>

    <%= if @enforcement_type == :case do %>
      <div class="mb-6">
        <label class="block text-sm font-medium text-gray-700 mb-2">
          Action Types
        </label>
        <div class="space-y-2">
          <div class="flex items-center">
            <input
              type="checkbox"
              name="action_types[]"
              id="action_type_court_case"
              value="court_case"
              checked={Enum.member?(@form_params["action_types"] || [], "court_case")}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <label for="action_type_court_case" class="ml-2 block text-sm text-gray-700">
              Court Cases
            </label>
          </div>
          <div class="flex items-center">
            <input
              type="checkbox"
              name="action_types[]"
              id="action_type_caution"
              value="caution"
              checked={Enum.member?(@form_params["action_types"] || [], "caution")}
              class="h-4 w-4 text-blue-600 focus:ring-blue-500 border-gray-300 rounded"
            />
            <label for="action_type_caution" class="ml-2 block text-sm text-gray-700">
              Cautions
            </label>
          </div>
        </div>
      </div>
    <% end %>
    """
  end

  # Progress Rendering

  defp render_progress(assigns) do
    ~H"""
    <ProgressComponent.unified_progress_component agency={@agency} progress={@progress} />
    """
  end

  # Load notices from ProcessingLog scraped_items
  defp load_notices_from_scraped_items(scraped_items, actor) do
    # Extract regulator_ids from scraped_items
    regulator_ids = Enum.map(scraped_items, & &1["regulator_id"]) |> Enum.filter(& &1)

    if Enum.empty?(regulator_ids) do
      []
    else
      # Load all notices with these regulator_ids
      query_opts = if actor, do: [actor: actor], else: []

      {:ok, notices} =
        Notice
        |> Ash.Query.filter(regulator_id in ^regulator_ids)
        |> Ash.Query.load([:agency, :offender])
        |> Ash.read(query_opts)

      # Mark all as :existing since they came from ProcessingLog (already processed)
      Enum.map(notices, &Map.put(&1, :processing_status, :existing))
    end
  rescue
    error ->
      Logger.error("Failed to load notices from scraped_items: #{inspect(error)}")
      []
  end

  # Load cases from ProcessingLog scraped_items
  defp load_cases_from_scraped_items(scraped_items, actor) do
    # Extract regulator_ids from scraped_items
    regulator_ids = Enum.map(scraped_items, & &1["regulator_id"]) |> Enum.filter(& &1)

    if Enum.empty?(regulator_ids) do
      []
    else
      # Load all cases with these regulator_ids
      query_opts = if actor, do: [actor: actor], else: []

      {:ok, cases} =
        Case
        |> Ash.Query.filter(regulator_id in ^regulator_ids)
        |> Ash.Query.load([:agency, :offender])
        |> Ash.read(query_opts)

      # Mark all as :existing since they came from ProcessingLog (already processed)
      Enum.map(cases, &Map.put(&1, :processing_status, :existing))
    end
  rescue
    error ->
      Logger.error("Failed to load cases from scraped_items: #{inspect(error)}")
      []
  end
end
