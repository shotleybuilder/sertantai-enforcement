defmodule EhsEnforcement.Enforcement do
  @moduledoc """
  The Enforcement domain for managing enforcement agencies, cases, notices, and related entities.
  
  This domain uses Ash code interfaces. Generated functions are available for all resources.
  """
  
  use Ash.Domain, extensions: [AshPhoenix]
  
  require Ash.Query

  # Cache configuration for common filter combinations
  @cache_ttl 5 * 60 * 1000 # 5 minutes in milliseconds
  @cache_name :enforcement_cache

  # Performance monitoring configuration
  @slow_query_threshold 1000 # Log queries taking longer than 1000ms

  resources do
    resource EhsEnforcement.Enforcement.Agency do
      define :list_agencies, action: :read
      define :get_agency, action: :read, get_by: [:id]
      define :create_agency, action: :create
      define :update_agency, action: :update
      define :get_agency_by_code, action: :read, get_by: [:code]
    end
    
    resource EhsEnforcement.Enforcement.Offender do
      define :list_offenders, action: :read
      define :get_offender, action: :read, get_by: [:id]
      define :create_offender, action: :create
      define :update_offender, action: :update
      define :search_offenders, action: :search, args: [:query]
      define :update_offender_statistics, action: :update_statistics
    end
    
    resource EhsEnforcement.Enforcement.Case do
      define :list_cases, action: :read
      define :get_case, action: :read, get_by: [:id]
      define :create_case, action: :create
      define :update_case, action: :update
      define :update_case_from_scraping, action: :update_from_scraping
      define :sync_case_from_airtable, action: :sync_from_airtable
      define :destroy_case, action: :destroy
      define :list_cases_by_date_range, action: :by_date_range, args: [:from_date, :to_date]
      define :bulk_create_cases, action: :bulk_create
    end
    
    resource EhsEnforcement.Enforcement.Notice do
      define :list_notices, action: :read
      define :get_notice, action: :read, get_by: [:id]
      define :create_notice, action: :create
      define :update_notice, action: :update
      define :destroy_notice, action: :destroy
    end
    
    
    resource EhsEnforcement.Enforcement.Metrics do
      define :get_current_metrics, action: :get_current
      define :refresh_metrics, action: :refresh
    end
    
    
    resource EhsEnforcement.Enforcement.Legislation do
      define :list_legislation, action: :read
      define :get_legislation, action: :read, get_by: [:id]
      define :create_legislation, action: :create
      define :update_legislation, action: :update
      define :destroy_legislation, action: :destroy
      define :list_legislation_by_type, action: :by_type, args: [:legislation_type]
      define :list_legislation_by_year_range, action: :by_year_range, args: [:start_year, :end_year]
      define :search_legislation_title, action: :search_title, args: [:search_term]
    end
    
    resource EhsEnforcement.Enforcement.Offence do
      define :list_offences, action: :read
      define :get_offence, action: :read, get_by: [:id]
      define :create_offence, action: :create
      define :update_offence, action: :update
      define :destroy_offence, action: :destroy
      define :list_offences_by_case, action: :by_case, args: [:case_id]
      define :list_offences_by_notice, action: :by_notice, args: [:notice_id]
      define :list_offences_by_legislation, action: :by_legislation, args: [:legislation_id]
      define :get_offence_by_reference, action: :by_reference, args: [:offence_reference]
      define :list_offences_with_fines, action: :with_fines
      define :search_offence_description, action: :search_description, args: [:search_term]
      define :bulk_create_offences, action: :bulk_create
    end
  end

  forms do
    form :create_case, args: []
    form :update_case_from_scraping, args: []
    form :sync_case_from_airtable, args: []
    form :create_offender, args: []
    form :update_offender, args: []
    form :create_notice, args: []
    form :update_notice, args: []
  end

  @doc """
  Code Interface Functions
  
  This domain now uses Ash code interfaces. Use the generated functions instead of direct Ash calls:
  
  ## Agency Functions
  - `list_agencies/1` - List all agencies with options
  - `get_agency/2` - Get agency by ID  
  - `create_agency/2` - Create new agency
  - `update_agency/3` - Update existing agency
  - `get_agency_by_code/2` - Get agency by code
  
  ## Offender Functions  
  - `list_offenders/1` - List all offenders with basic options (code interface)
  - `list_offenders_with_filters/1` - List offenders with complex filtering (custom function)
  - `list_offenders_with_filters_cached!/1` - Cached version for performance
  - `list_offenders_with_filters_monitored!/1` - Monitored version with slow query logging
  - `get_offender/2` - Get offender by ID
  - `create_offender/2` - Create new offender
  - `update_offender/3` - Update existing offender
  - `search_offenders/2` - Search offenders with query
  - `fuzzy_search_offenders/2` - Fuzzy search using pg_trgm trigram similarity
  - `update_offender_statistics/3` - Update offender statistics
  - `count_offenders!/1` - Count offenders with filtering
  - `count_offenders_cached!/1` - Cached count for performance
  - `count_offenders_monitored!/1` - Monitored count with logging
  
  ## Case Functions
  - `list_cases/1` - List all cases with basic options (code interface)
  - `list_cases_with_filters/1` - List cases with complex filtering (custom function)
  - `get_case/2` - Get case by ID
  - `create_case/2` - Create new case
  - `update_case_from_scraping/3` - Update case from HSE scraping
  - `sync_case_from_airtable/3` - Sync case from Airtable migration
  - `destroy_case/2` - Delete case
  - `list_cases_by_date_range/3` - List cases in date range
  - `bulk_create_cases/2` - Bulk create multiple cases
  
  ## Notice Functions
  - `list_notices/1` - List all notices with options
  - `get_notice/2` - Get notice by ID
  - `create_notice/2` - Create new notice
  - `update_notice/3` - Update existing notice
  - `destroy_notice/2` - Delete notice
  - `sync_notice/3` - Sync notice data
  
  
  ## Metrics Functions
  - `get_current_metrics/1` - Get current cached dashboard metrics
  - `refresh_metrics/1` - Refresh all dashboard metrics from current data
  
  ## Legislation Functions
  - `list_legislation/1` - List all legislation with options
  - `get_legislation/2` - Get legislation by ID
  - `create_legislation/2` - Create new legislation
  - `update_legislation/3` - Update existing legislation
  - `destroy_legislation/2` - Delete legislation
  - `list_legislation_by_type/2` - List legislation by type (act, regulation, etc.)
  - `list_legislation_by_year_range/3` - List legislation within year range
  - `search_legislation_title/2` - Fuzzy search legislation titles
  
  ## Offence Functions (Unified Violation/Breach Support)
  - `list_offences/1` - List all offences with options  
  - `get_offence/2` - Get offence by ID
  - `create_offence/2` - Create new offence
  - `update_offence/3` - Update existing offence
  - `destroy_offence/2` - Delete offence
  - `list_offences_by_case/2` - List offences for specific case
  - `list_offences_by_notice/2` - List offences for specific notice
  - `list_offences_by_legislation/2` - List offences referencing specific legislation
  - `get_offence_by_reference/2` - Get offence by reference ID
  - `list_offences_with_fines/1` - List offences that have associated fines
  - `search_offence_description/2` - Fuzzy search offence descriptions
  - `bulk_create_offences/2` - Bulk create multiple offences
  """

  # Complex functions that extend beyond basic code interfaces

  def get_offender_by_name_and_postcode(name, postcode) do
    # Normalize the search name for matching
    normalized_search_name = EhsEnforcement.Enforcement.Offender.normalize_company_name(name)
    
    query = if postcode do
      EhsEnforcement.Enforcement.Offender
      |> Ash.Query.filter(normalized_name == ^normalized_search_name and postcode == ^postcode)
    else
      EhsEnforcement.Enforcement.Offender
      |> Ash.Query.filter(normalized_name == ^normalized_search_name and is_nil(postcode))
    end
    
    case query |> Ash.read_one() do
      {:ok, nil} -> {:error, %Ash.Error.Query.NotFound{}}
      result -> result
    end
  end


  def change_case_for_scraping(case_record, attrs \\ %{}) do
    case_record
    |> Ash.Changeset.for_update(:update_from_scraping, attrs)
  end

  def change_case_for_airtable_sync(case_record, attrs \\ %{}) do
    case_record
    |> Ash.Changeset.for_update(:sync_from_airtable, attrs)
  end

  def list_cases_with_filters(opts \\ []) do
    query = EhsEnforcement.Enforcement.Case
    
    # Apply filters if provided - optimized for composite index usage
    query = case opts[:filter] do
      nil -> query
      filters ->
        # Build comprehensive filter expression to leverage composite indexes
        build_optimized_case_filter(query, filters)
    end
    
    # Apply load if provided
    query = case opts[:load] do
      nil -> query
      loads -> Ash.Query.load(query, loads)
    end
    
    # Apply sort if provided
    query = case opts[:sort] do
      nil -> query
      sorts -> Ash.Query.sort(query, sorts)
    end
    
    # Apply pagination if provided
    query = case opts[:page] do
      nil -> query
      page_opts -> 
        limit = page_opts[:limit]
        offset = page_opts[:offset]
        count = page_opts[:count]
        
        query
        |> then(fn q -> if limit, do: Ash.Query.limit(q, limit), else: q end)
        |> then(fn q -> if offset, do: Ash.Query.offset(q, offset), else: q end)
        |> then(fn q -> if count, do: Ash.Query.page(q, count: true), else: q end)
    end
    
    Ash.read(query)
  end

  # Optimized filter building to leverage composite indexes (agency_id, offence_action_date)
  defp build_optimized_case_filter(query, filters) do
    # Group filters for optimal index usage
    agency_filter = filters[:agency_id]
    date_filters = filters[:offence_action_date] || []
    fine_filters = filters[:offence_fine] || []
    search_pattern = filters[:search]
    regulator_id_filter = filters[:regulator_id]
    
    # Build filter expression to use composite indexes efficiently
    query = if agency_filter && Enum.any?(date_filters) do
      # Use composite index (agency_id, offence_action_date) - most efficient path
      date_conditions = build_date_conditions(date_filters)
      case date_conditions do
        {start_date, end_date} when not is_nil(start_date) and not is_nil(end_date) ->
          Ash.Query.filter(query, 
            agency_id == ^agency_filter and 
            offence_action_date >= ^start_date and 
            offence_action_date <= ^end_date
          )
        {start_date, nil} when not is_nil(start_date) ->
          Ash.Query.filter(query, 
            agency_id == ^agency_filter and 
            offence_action_date >= ^start_date
          )
        {nil, end_date} when not is_nil(end_date) ->
          Ash.Query.filter(query, 
            agency_id == ^agency_filter and 
            offence_action_date <= ^end_date
          )
        _ ->
          Ash.Query.filter(query, agency_id == ^agency_filter)
      end
    else
      # Apply individual filters in optimal order
      query
      |> apply_if_present(agency_filter, fn q, value -> 
        Ash.Query.filter(q, agency_id == ^value) 
      end)
      |> apply_date_filters(date_filters)
    end
    
    # Apply remaining filters
    query
    |> apply_if_present(regulator_id_filter, fn q, value ->
      Ash.Query.filter(q, regulator_id == ^value)
    end)
    |> apply_fine_filters(fine_filters)
    |> apply_search_filter(search_pattern)
  end
  
  # Helper functions for optimized filtering
  defp apply_if_present(query, nil, _fun), do: query
  defp apply_if_present(query, value, fun), do: fun.(query, value)
  
  defp build_date_conditions(date_filters) do
    start_date = Enum.find_value(date_filters, fn
      {:greater_than_or_equal_to, date} -> date
      _ -> nil
    end)
    
    end_date = Enum.find_value(date_filters, fn
      {:less_than_or_equal_to, date} -> date
      _ -> nil
    end)
    
    {start_date, end_date}
  end
  
  defp apply_date_filters(query, []), do: query
  defp apply_date_filters(query, date_filters) do
    Enum.reduce(date_filters, query, fn
      {:greater_than_or_equal_to, date}, acc_q -> 
        Ash.Query.filter(acc_q, offence_action_date >= ^date)
      {:less_than_or_equal_to, date}, acc_q -> 
        Ash.Query.filter(acc_q, offence_action_date <= ^date)
      _, acc_q -> acc_q
    end)
  end
  
  defp apply_fine_filters(query, []), do: query
  defp apply_fine_filters(query, fine_filters) do
    Enum.reduce(fine_filters, query, fn
      {:greater_than_or_equal_to, amount}, acc_q -> 
        Ash.Query.filter(acc_q, offence_fine >= ^amount)
      {:less_than_or_equal_to, amount}, acc_q -> 
        Ash.Query.filter(acc_q, offence_fine <= ^amount)
      _, acc_q -> acc_q
    end)
  end
  
  defp apply_search_filter(query, nil), do: query
  defp apply_search_filter(query, pattern) when is_binary(pattern) do
    # Optimized search using OR conditions with proper Ash syntax
    Ash.Query.filter(query, 
      ilike(regulator_id, ^pattern) or 
      ilike(computed_breaches_summary, ^pattern) or 
      ilike(offender.name, ^pattern)
    )
  end


  def list_cases_with_filters!(opts \\ []) do
    case list_cases_with_filters(opts) do
      {:ok, cases} -> cases
      {:error, error} -> raise error
    end
  end

  def count_cases!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Case
    
    # Apply filters if provided - use same optimized filtering as list function
    query = case opts[:filter] do
      nil -> query
      filters -> build_optimized_case_filter(query, filters)
    end
    
    case Ash.count(query) do
      {:ok, count} -> count
      {:error, error} -> raise error
    end
  end

  def list_offenders_with_filters!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Offender
    
    # Apply complex filters if provided - optimized for available indexes
    query = case opts[:filter] do
      nil -> query
      filters -> build_optimized_offender_filter(query, filters)
    end
    
    # Apply sort if provided
    query = case opts[:sort] do
      nil -> Ash.Query.sort(query, [total_fines: :desc])  # Default sort by total fines
      sorts -> Ash.Query.sort(query, sorts)
    end
    
    # Apply load if provided
    query = case opts[:load] do
      nil -> query
      loads -> Ash.Query.load(query, loads)
    end
    
    # Apply pagination if provided
    query = case opts[:limit] do
      nil -> query
      limit -> Ash.Query.limit(query, limit)
    end
    
    # Apply offset if provided (for consistent pagination with cases/notices)
    query = case opts[:offset] do
      nil -> query
      offset -> Ash.Query.offset(query, offset)
    end
    
    case Ash.read(query) do
      {:ok, offenders} -> offenders
      {:error, error} -> raise error
    end
  end

  def count_offenders!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Offender
    
    # Apply filters if provided - use same optimized filtering as list function
    query = case opts[:filter] do
      nil -> query
      filters -> build_optimized_offender_filter(query, filters)
    end
    
    case Ash.count(query) do
      {:ok, count} -> count
      {:error, error} -> raise error
    end
  end

  def count_notices!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Notice
    
    # Apply filters if provided - use same optimized filtering as list function
    query = case opts[:filter] do
      nil -> query
      filters -> build_optimized_notice_filter(query, filters)
    end
    
    case Ash.count(query) do
      {:ok, count} -> count
      {:error, error} -> raise error
    end
  end

  def list_notices_with_filters!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Notice
    
    # Apply complex filters if provided - optimized for composite index usage
    query = case opts[:filter] do
      nil -> query
      filters -> build_optimized_notice_filter(query, filters)
    end
    
    # Apply sort if provided  
    query = case opts[:sort] do
      nil -> Ash.Query.sort(query, [offence_action_date: :desc])
      sorts -> Ash.Query.sort(query, sorts)
    end
    
    # Apply load if provided
    query = case opts[:load] do
      nil -> query
      loads -> Ash.Query.load(query, loads)
    end
    
    # Apply pagination if provided
    query = case opts[:limit] do
      nil -> query
      limit -> Ash.Query.limit(query, limit)
    end
    
    # Apply offset if provided (for consistent pagination with cases)
    query = case opts[:offset] do
      nil -> query
      offset -> Ash.Query.offset(query, offset)
    end
    
    case Ash.read(query) do
      {:ok, notices} -> notices
      {:error, error} -> raise error
    end
  end

  # Optimized filter building for notices to leverage composite indexes (agency_id, offence_action_date)
  defp build_optimized_notice_filter(query, filters) do
    # Group filters for optimal index usage
    agency_filter = filters[:agency_id]
    date_from = filters[:date_from]
    date_to = filters[:date_to]
    search_pattern = filters[:search]
    regulator_id_filter = filters[:regulator_id]
    action_type_filter = filters[:offence_action_type]
    
    # Build filter expression to use composite indexes efficiently
    query = if agency_filter && (date_from || date_to) do
      # Use composite index (agency_id, offence_action_date) - most efficient path
      case {date_from, date_to} do
        {start_date, end_date} when not is_nil(start_date) and not is_nil(end_date) ->
          Ash.Query.filter(query, 
            agency_id == ^agency_filter and 
            offence_action_date >= ^start_date and 
            offence_action_date <= ^end_date
          )
        {start_date, nil} when not is_nil(start_date) ->
          Ash.Query.filter(query, 
            agency_id == ^agency_filter and 
            offence_action_date >= ^start_date
          )
        {nil, end_date} when not is_nil(end_date) ->
          Ash.Query.filter(query, 
            agency_id == ^agency_filter and 
            offence_action_date <= ^end_date
          )
        _ ->
          Ash.Query.filter(query, agency_id == ^agency_filter)
      end
    else
      # Apply individual filters in optimal order
      query
      |> apply_if_present(agency_filter, fn q, value -> 
        Ash.Query.filter(q, agency_id == ^value) 
      end)
      |> apply_if_present(date_from, fn q, date ->
        Ash.Query.filter(q, offence_action_date >= ^date)
      end)
      |> apply_if_present(date_to, fn q, date ->
        Ash.Query.filter(q, offence_action_date <= ^date)
      end)
    end
    
    # Apply remaining filters
    query
    |> apply_if_present(regulator_id_filter, fn q, value ->
      Ash.Query.filter(q, regulator_id == ^value)
    end)
    |> apply_if_present(action_type_filter, fn q, value ->
      Ash.Query.filter(q, offence_action_type == ^value)
    end)
    |> apply_search_filter(search_pattern)
  end

  # Optimized filter building for offenders to leverage pg_trgm GIN indexes
  defp build_optimized_offender_filter(query, filters) do
    # Group filters for optimal index usage
    agency_filter = filters[:agency]
    industry_filter = filters[:industry]
    local_authority_filter = filters[:local_authority]
    business_type_filter = filters[:business_type]
    repeat_only_filter = filters[:repeat_only]
    search_pattern = filters[:search]
    
    # Apply individual filters in optimal order
    query
    |> apply_if_present(agency_filter, fn q, value ->
      # Filter offenders by agency using the denormalized agencies array
      # This is much more efficient than joining through cases/notices
      Ash.Query.filter(q, ^value in agencies)
    end)
    |> apply_if_present(industry_filter, fn q, value -> 
      Ash.Query.filter(q, industry == ^value) 
    end)
    |> apply_if_present(local_authority_filter, fn q, value ->
      Ash.Query.filter(q, local_authority == ^value)
    end)
    |> apply_if_present(business_type_filter, fn q, value ->
      # Convert string to atom if needed
      atom_value = if is_binary(value), do: String.to_atom(value), else: value
      Ash.Query.filter(q, business_type == ^atom_value)
    end)
    |> apply_repeat_offender_filter(repeat_only_filter)
    |> apply_offender_search_filter(search_pattern)
  end
  
  defp apply_repeat_offender_filter(query, nil), do: query
  defp apply_repeat_offender_filter(query, false), do: query
  defp apply_repeat_offender_filter(query, true) do
    # Repeat offenders have more than 2 total enforcement actions
    Ash.Query.filter(query, total_cases + total_notices > 2)
  end
  
  defp apply_offender_search_filter(query, nil), do: query
  defp apply_offender_search_filter(query, pattern) when is_binary(pattern) do
    # Optimized search using OR conditions with proper Ash syntax
    # Uses existing pg_trgm GIN indexes for efficient text search
    Ash.Query.filter(query, 
      ilike(name, ^pattern) or 
      ilike(normalized_name, ^pattern) or
      ilike(local_authority, ^pattern) or
      ilike(main_activity, ^pattern) or
      ilike(postcode, ^pattern)
    )
  end

  defp build_optimized_legislation_filter(query, filters) do
    # Start with base query
    query
    |> apply_legislation_type_filter(filters[:legislation_type])
    |> apply_legislation_year_range_filter(filters[:legislation_year])
    |> apply_legislation_search_filter(filters[:search])
    |> apply_legislation_agency_filter(filters[:agency])
  end

  defp apply_legislation_type_filter(query, nil), do: query
  defp apply_legislation_type_filter(query, type) when is_atom(type) do
    Ash.Query.filter(query, legislation_type == ^type)
  end

  defp apply_legislation_year_range_filter(query, nil), do: query
  defp apply_legislation_year_range_filter(query, year_conditions) when is_list(year_conditions) do
    Enum.reduce(year_conditions, query, fn
      {:greater_than_or_equal_to, year}, acc ->
        Ash.Query.filter(acc, legislation_year >= ^year)
      {:less_than_or_equal_to, year}, acc ->
        Ash.Query.filter(acc, legislation_year <= ^year)
      _, acc -> acc
    end)
  end

  defp apply_legislation_search_filter(query, nil), do: query
  defp apply_legislation_search_filter(query, pattern) when is_binary(pattern) do
    # Search in legislation title using ILIKE for broad compatibility
    Ash.Query.filter(query, ilike(legislation_title, ^pattern))
  end

  defp apply_legislation_agency_filter(query, nil), do: query
  defp apply_legislation_agency_filter(query, agency_code) when is_atom(agency_code) do
    # Filter legislation used by specific agency through either:
    # 1. Cases: offences → cases → agency
    # 2. Notices: offences → notices → agency
    Ash.Query.filter(query, 
      exists(offences, 
        exists(case, agency.code == ^agency_code) or
        exists(notice, agency.code == ^agency_code)
      )
    )
  end

  # Fuzzy search functions using pg_trgm trigram similarity

  @doc """
  Perform fuzzy search across cases using pg_trgm trigram similarity.
  
  This function uses PostgreSQL's pg_trgm extension to find cases with text fields
  that are similar to the search term, even with typos or partial matches.
  
  ## Parameters
  - `search_term` - The text to search for (minimum 3 characters)
  - `opts` - Additional query options (limit, offset, etc.)
  
  ## Options
  - `:similarity_threshold` - Minimum similarity score (0.0-1.0, default: 0.3)
  - `:limit` - Maximum number of results to return
  - `:offset` - Number of results to skip
  - `:load` - Associations to preload
  
  ## Examples
      iex> fuzzy_search_cases("construction", limit: 10)
      [%Case{regulator_id: "HSE-2024-123", computed_breaches_summary: "Construction (Design and Management) Regulations 2015"}]
      
      iex> fuzzy_search_cases("acme corp", similarity_threshold: 0.4)
      [%Case{offender: %{name: "ACME Construction Ltd"}}]
  """
  def fuzzy_search_cases(search_term, opts \\ [])
  def fuzzy_search_cases(search_term, opts) when is_binary(search_term) and byte_size(search_term) >= 3 do
    similarity_threshold = opts[:similarity_threshold] || 0.3
    
    query = EhsEnforcement.Enforcement.Case
    |> Ash.Query.filter(
      trigram_similarity(regulator_id, ^search_term) > ^similarity_threshold or
      trigram_similarity(computed_breaches_summary, ^search_term) > ^similarity_threshold or
      trigram_similarity(offender.name, ^search_term) > ^similarity_threshold
    )
    # Order by most recent cases first (GIN index handles relevance ranking)
    |> Ash.Query.sort(inserted_at: :desc)
    
    query = if opts[:limit], do: Ash.Query.limit(query, opts[:limit]), else: query
    query = if opts[:offset], do: Ash.Query.offset(query, opts[:offset]), else: query  
    query = if opts[:load], do: Ash.Query.load(query, opts[:load]), else: Ash.Query.load(query, [:offender])
    
    Ash.read(query)
  end
  def fuzzy_search_cases(_short_term, _opts), do: {:ok, []}  # Return empty for short terms

  @doc """
  Perform fuzzy search across notices using pg_trgm trigram similarity.
  
  Similar to fuzzy_search_cases/2 but searches notice fields including notice body.
  """
  def fuzzy_search_notices(search_term, opts \\ [])
  def fuzzy_search_notices(search_term, opts) when is_binary(search_term) and byte_size(search_term) >= 3 do
    similarity_threshold = opts[:similarity_threshold] || 0.3
    
    query = EhsEnforcement.Enforcement.Notice
    |> Ash.Query.filter(
      trigram_similarity(regulator_id, ^search_term) > ^similarity_threshold or
      trigram_similarity(notice_body, ^search_term) > ^similarity_threshold or
      trigram_similarity(offender.name, ^search_term) > ^similarity_threshold
    )
    # Order by most recent notices first (GIN index handles relevance ranking)
    |> Ash.Query.sort(inserted_at: :desc)
    
    query = if opts[:limit], do: Ash.Query.limit(query, opts[:limit]), else: query
    query = if opts[:offset], do: Ash.Query.offset(query, opts[:offset]), else: query
    query = if opts[:load], do: Ash.Query.load(query, opts[:load]), else: Ash.Query.load(query, [:offender])
    
    Ash.read(query)
  end
  def fuzzy_search_notices(_short_term, _opts), do: {:ok, []}  # Return empty for short terms

  @doc """
  Perform fuzzy search across offenders using pg_trgm trigram similarity.
  
  Searches offender name, normalized name, local authority, and main activity fields.
  """
  def fuzzy_search_offenders(search_term, opts \\ [])  
  def fuzzy_search_offenders(search_term, opts) when is_binary(search_term) and byte_size(search_term) >= 3 do
    similarity_threshold = opts[:similarity_threshold] || 0.3
    
    query = EhsEnforcement.Enforcement.Offender
    |> Ash.Query.filter(
      trigram_similarity(name, ^search_term) > ^similarity_threshold or
      trigram_similarity(normalized_name, ^search_term) > ^similarity_threshold or
      trigram_similarity(local_authority, ^search_term) > ^similarity_threshold or
      trigram_similarity(main_activity, ^search_term) > ^similarity_threshold
    )
    # Order by offender name (GIN index handles relevance ranking)
    |> Ash.Query.sort(name: :asc)
    
    query = if opts[:limit], do: Ash.Query.limit(query, opts[:limit]), else: query
    query = if opts[:offset], do: Ash.Query.offset(query, opts[:offset]), else: query
    
    Ash.read(query)
  end
  def fuzzy_search_offenders(_short_term, _opts), do: {:ok, []}  # Return empty for short terms

  # Cached query functions for common filter combinations

  @doc """
  Cached version of list_cases_with_filters! for frequently used filter combinations.
  
  Uses a simple cache key based on common filter patterns to avoid repeated database queries.
  Cache TTL is #{@cache_ttl / 1000} seconds.
  """
  def list_cases_with_filters_cached!(opts \\ []) do
    cache_key = build_cache_key("cases", opts)
    
    case get_from_cache(cache_key) do
      {:hit, result} -> result
      :miss ->
        result = list_cases_with_filters!(opts)
        put_in_cache(cache_key, result)
        result
    end
  end

  @doc """
  Cached version of list_notices_with_filters! for frequently used filter combinations.
  """
  def list_notices_with_filters_cached!(opts \\ []) do
    cache_key = build_cache_key("notices", opts)
    
    case get_from_cache(cache_key) do
      {:hit, result} -> result
      :miss ->
        result = list_notices_with_filters!(opts)
        put_in_cache(cache_key, result)
        result
    end
  end

  @doc """
  Cached count functions for dashboard metrics and pagination.
  """
  def count_cases_cached!(opts \\ []) do
    cache_key = build_cache_key("cases_count", opts)
    
    case get_from_cache(cache_key) do
      {:hit, result} -> result
      :miss ->
        result = count_cases!(opts)
        put_in_cache(cache_key, result)
        result
    end
  end

  def count_notices_cached!(opts \\ []) do
    cache_key = build_cache_key("notices_count", opts)
    
    case get_from_cache(cache_key) do
      {:hit, result} -> result
      :miss ->
        result = count_notices!(opts)
        put_in_cache(cache_key, result)
        result
    end
  end

  @doc """
  Cached version of list_offenders_with_filters! for frequently used filter combinations.
  """
  def list_offenders_with_filters_cached!(opts \\ []) do
    cache_key = build_cache_key("offenders", opts)
    
    case get_from_cache(cache_key) do
      {:hit, result} -> result
      :miss ->
        result = list_offenders_with_filters!(opts)
        put_in_cache(cache_key, result)
        result
    end
  end

  def count_offenders_cached!(opts \\ []) do
    cache_key = build_cache_key("offenders_count", opts)
    
    case get_from_cache(cache_key) do
      {:hit, result} -> result
      :miss ->
        result = count_offenders!(opts)
        put_in_cache(cache_key, result)
        result
    end
  end

  def list_legislation_with_filters!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Legislation
    
    # Apply complex filters if provided
    query = case opts[:filter] do
      nil -> query
      filters -> build_optimized_legislation_filter(query, filters)
    end
    
    # Apply sort if provided
    query = case opts[:sort] do
      nil -> Ash.Query.sort(query, [legislation_year: :desc])  # Default sort by year
      sorts -> Ash.Query.sort(query, sorts)
    end
    
    # Apply load if provided
    query = case opts[:load] do
      nil -> query
      loads -> Ash.Query.load(query, loads)
    end
    
    # Apply pagination if provided
    query = case opts[:limit] do
      nil -> query
      limit -> Ash.Query.limit(query, limit)
    end
    
    # Apply offset if provided (for consistent pagination)
    query = case opts[:offset] do
      nil -> query
      offset -> Ash.Query.offset(query, offset)
    end
    
    case Ash.read(query) do
      {:ok, legislation} -> legislation
      {:error, error} -> raise error
    end
  end

  def count_legislation!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Legislation
    
    # Apply filters if provided - use same optimized filtering as list function
    query = case opts[:filter] do
      nil -> query
      filters -> build_optimized_legislation_filter(query, filters)
    end
    
    case Ash.count(query) do
      {:ok, count} -> count
      {:error, error} -> raise error
    end
  end

  # Cache management functions
  
  defp build_cache_key(resource_type, opts) do
    # Create a stable cache key based on filter options
    filter_key = case opts[:filter] do
      nil -> "no_filter"
      filters -> 
        filters
        |> Enum.sort()
        |> Enum.map(fn {k, v} -> "#{k}:#{cache_value(v)}" end)
        |> Enum.join("|")
    end
    
    pagination_key = case {opts[:limit], opts[:offset]} do
      {nil, nil} -> "no_page"
      {limit, offset} -> "limit:#{limit || "nil"}|offset:#{offset || "nil"}"
    end
    
    "#{resource_type}:#{filter_key}:#{pagination_key}"
  end

  defp cache_value(value) when is_list(value) do
    value 
    |> Enum.map(&cache_value/1)
    |> Enum.join(",")
  end
  
  defp cache_value({key, val}), do: "#{key}=#{cache_value(val)}"
  defp cache_value(%Date{} = date), do: Date.to_iso8601(date)
  defp cache_value(%Decimal{} = decimal), do: Decimal.to_string(decimal)
  defp cache_value(value) when is_binary(value), do: String.slice(value, 0, 50) # Limit key length
  defp cache_value(value), do: inspect(value)

  defp get_from_cache(key) do
    case :ets.lookup(@cache_name, key) do
      [{^key, value, expires_at}] ->
        if System.monotonic_time(:millisecond) < expires_at do
          {:hit, value}
        else
          :ets.delete(@cache_name, key)
          :miss
        end
      [] -> :miss
    end
  end

  defp put_in_cache(key, value) do
    expires_at = System.monotonic_time(:millisecond) + @cache_ttl
    :ets.insert(@cache_name, {key, value, expires_at})
    value
  end

  @doc """
  Clear all cached results. Useful when data is updated.
  """
  def clear_cache do
    case :ets.whereis(@cache_name) do
      :undefined -> :ok
      _pid -> 
        :ets.delete_all_objects(@cache_name)
        :ok
    end
  end

  @doc """
  Initialize the cache table. Called during application startup.
  """
  def init_cache do
    case :ets.whereis(@cache_name) do
      :undefined ->
        :ets.new(@cache_name, [:set, :public, :named_table])
        :ok
      _pid -> :ok
    end
  end

  # Performance monitoring functions

  @doc """
  Monitored version of list_cases_with_filters! that logs slow queries.
  """
  def list_cases_with_filters_monitored!(opts \\ []) do
    monitor_query_performance("list_cases_with_filters!", opts, fn ->
      list_cases_with_filters!(opts)
    end)
  end

  @doc """
  Monitored version of list_notices_with_filters! that logs slow queries.
  """
  def list_notices_with_filters_monitored!(opts \\ []) do
    monitor_query_performance("list_notices_with_filters!", opts, fn ->
      list_notices_with_filters!(opts)
    end)
  end

  @doc """
  Monitored version of count_cases! that logs slow queries.
  """
  def count_cases_monitored!(opts \\ []) do
    monitor_query_performance("count_cases!", opts, fn ->
      count_cases!(opts)
    end)
  end

  @doc """
  Monitored version of count_notices! that logs slow queries.
  """
  def count_notices_monitored!(opts \\ []) do
    monitor_query_performance("count_notices!", opts, fn ->
      count_notices!(opts)
    end)
  end

  @doc """
  Monitored version of list_offenders_with_filters! that logs slow queries.
  """
  def list_offenders_with_filters_monitored!(opts \\ []) do
    monitor_query_performance("list_offenders_with_filters!", opts, fn ->
      list_offenders_with_filters!(opts)
    end)
  end

  @doc """
  Monitored version of count_offenders! that logs slow queries.
  """
  def count_offenders_monitored!(opts \\ []) do
    monitor_query_performance("count_offenders!", opts, fn ->
      count_offenders!(opts)
    end)
  end

  # Performance monitoring helpers

  defp monitor_query_performance(function_name, opts, query_fn) do
    start_time = System.monotonic_time(:millisecond)
    
    try do
      result = query_fn.()
      end_time = System.monotonic_time(:millisecond)
      query_time = end_time - start_time
      
      # Log slow queries
      if query_time > @slow_query_threshold do
        log_slow_query(function_name, opts, query_time, length_or_count(result))
      end
      
      # Log metrics for monitoring (optional telemetry events could be added here)
      log_query_metrics(function_name, opts, query_time, length_or_count(result))
      
      result
      
    rescue
      error ->
        end_time = System.monotonic_time(:millisecond)
        query_time = end_time - start_time
        
        log_query_error(function_name, opts, query_time, error)
        reraise error, __STACKTRACE__
    end
  end

  defp length_or_count(result) when is_list(result), do: length(result)
  defp length_or_count(result) when is_integer(result), do: result
  defp length_or_count(_), do: "unknown"

  defp log_slow_query(function_name, opts, query_time_ms, result_count) do
    require Logger
    
    filter_summary = summarize_filters(opts[:filter])
    
    Logger.warning("""
    Slow query detected in Enforcement context
    Function: #{function_name}
    Query time: #{query_time_ms}ms (threshold: #{@slow_query_threshold}ms)
    Result count: #{result_count}
    Filters: #{filter_summary}
    Options: #{inspect(opts, limit: :infinity, printable_limit: :infinity)}
    """)
  end

  defp log_query_metrics(function_name, opts, query_time_ms, result_count) do
    # This could be extended to send metrics to external monitoring systems
    # For now, we'll just log debug info for queries over 100ms
    if query_time_ms > 100 do
      require Logger
      
      filter_summary = summarize_filters(opts[:filter])
      
      Logger.debug("""
      Query performance metrics
      Function: #{function_name}
      Query time: #{query_time_ms}ms
      Result count: #{result_count}  
      Filters: #{filter_summary}
      """)
    end
  end

  defp log_query_error(function_name, opts, query_time_ms, error) do
    require Logger
    
    filter_summary = summarize_filters(opts[:filter])
    
    Logger.error("""
    Query error in Enforcement context
    Function: #{function_name}
    Query time: #{query_time_ms}ms
    Error: #{inspect(error)}
    Filters: #{filter_summary}
    Options: #{inspect(opts, limit: :infinity)}
    """)
  end

  defp summarize_filters(nil), do: "none"
  defp summarize_filters(filters) when is_map(filters) do
    filters
    |> Enum.map(fn
      {key, value} when is_list(value) -> "#{key}:#{length(value)}_conditions"
      {key, value} when is_binary(value) -> "#{key}:#{String.slice(value, 0, 20)}..."
      {key, %Date{}} -> "#{key}:date"
      {key, %Decimal{}} -> "#{key}:decimal"
      {key, _value} -> "#{key}:value"
    end)
    |> Enum.join(", ")
  end
  defp summarize_filters(filters), do: inspect(filters, limit: 50)

  @doc """
  Get query performance statistics for monitoring dashboards.
  This could be extended to track metrics in ETS/database for reporting.
  """
  def get_performance_stats do
    # In a production system, this would retrieve actual performance metrics
    # For now, return a placeholder that could be extended
    %{
      slow_query_threshold_ms: @slow_query_threshold,
      cache_ttl_seconds: @cache_ttl / 1000,
      monitoring_enabled: true,
      cache_status: case :ets.whereis(@cache_name) do
        :undefined -> "not_initialized"
        _pid -> "active"
      end
    }
  end

  # ============================================================================
  # Legislation Deduplication Functions
  # ============================================================================

  require Logger

  @doc """
  Find or create legislation with deduplication logic.
  
  This function prevents duplicate legislation records by:
  1. Normalizing the title
  2. Searching for exact matches first
  3. Using fuzzy matching for similar titles
  4. Creating new records only when no match exists
  
  Works for both HSE and EA legislation processing.
  
  ## Parameters
  - `title` - The legislation title (required)
  - `year` - The year enacted (optional, extracted from title if not provided)
  - `number` - The legislation number (optional)
  - `type` - The legislation type (optional, determined from title if not provided)
  
  ## Examples
      iex> find_or_create_legislation("Health and Safety at Work Act 1974", 1974, 37)
      {:ok, %Legislation{legislation_title: "Health and Safety at Work etc. Act", ...}}
      
      iex> find_or_create_legislation("COSHH REGULATIONS 2002")
      {:ok, %Legislation{legislation_title: "Control of Substances Hazardous to Health Regulations", ...}}
  """
  @spec find_or_create_legislation(String.t(), integer() | nil, integer() | nil, atom() | nil) :: 
    {:ok, struct()} | {:error, term()}
  def find_or_create_legislation(title, year \\ nil, number \\ nil, type \\ nil) when is_binary(title) do
    require Logger
    
    # Validate and normalize input data
    input_data = %{
      title: title,
      year: year,
      number: number,
      type: type
    }
    
    case EhsEnforcement.Utility.validate_legislation_data(input_data) do
      {:ok, validated_data} ->
        do_find_or_create_legislation(validated_data)
      
      {:error, reason} ->
        Logger.warning("Invalid legislation data: #{reason} - Input: #{inspect(input_data)}")
        {:error, reason}
    end
  end

  defp do_find_or_create_legislation(validated_data) do
    %{
      legislation_title: title,
      legislation_year: year,
      legislation_number: number,
      legislation_type: _type
    } = validated_data
    
    # Try exact match first using Ash identity
    case find_exact_legislation(title, year, number) do
      {:ok, legislation} ->
        Logger.debug("Found exact legislation match: #{title}")
        {:ok, legislation}
      
      {:error, :not_found} ->
        # Try fuzzy match for similar titles
        case find_similar_legislation(title, year) do
          {:ok, legislation} ->
            Logger.info("Found similar legislation match: #{title} -> #{legislation.legislation_title}")
            {:ok, legislation}
          
          {:error, :not_found} ->
            # Create new legislation record
            Logger.info("Creating new legislation: #{title}")
            create_new_legislation(validated_data)
          
          error ->
            error
        end
      
      error ->
        error
    end
  end

  defp find_exact_legislation(title, year, number) do
    query = EhsEnforcement.Enforcement.Legislation
    |> Ash.Query.filter(
      legislation_title == ^title and
      legislation_year == ^year and
      legislation_number == ^number
    )
    
    case Ash.read_one(query) do
      {:ok, nil} -> {:error, :not_found}
      {:ok, legislation} -> {:ok, legislation}
      error -> error
    end
  end

  defp find_similar_legislation(title, year, similarity_threshold \\ 0.85) do
    # Get all legislation with the same year (or nil year)
    base_query = EhsEnforcement.Enforcement.Legislation
    |> Ash.Query.filter(legislation_year == ^year or is_nil(legislation_year))
    
    case Ash.read(base_query) do
      {:ok, candidates} ->
        # Find the best match using similarity scoring
        best_match = candidates
        |> Enum.map(fn candidate ->
          similarity = EhsEnforcement.Utility.calculate_title_similarity(title, candidate.legislation_title)
          {candidate, similarity}
        end)
        |> Enum.filter(fn {_candidate, similarity} -> similarity >= similarity_threshold end)
        |> Enum.max_by(fn {_candidate, similarity} -> similarity end, fn -> nil end)
        
        case best_match do
          {legislation, _similarity} -> {:ok, legislation}
          nil -> {:error, :not_found}
        end
      
      error -> error
    end
  end

  defp create_new_legislation(validated_data) do
    EhsEnforcement.Enforcement.create_legislation(validated_data)
  end

  @doc """
  Batch find or create multiple legislation records.
  
  Useful for processing multiple breaches or offences at once.
  Returns a map of original titles to legislation records.
  """
  @spec batch_find_or_create_legislation([map()]) :: {:ok, map()} | {:error, term()}
  def batch_find_or_create_legislation(legislation_data_list) when is_list(legislation_data_list) do
    results = Enum.reduce_while(legislation_data_list, %{}, fn data, acc ->
      title = data[:title] || data["title"]
      year = data[:year] || data["year"]
      number = data[:number] || data["number"]
      type = data[:type] || data["type"]
      
      case find_or_create_legislation(title, year, number, type) do
        {:ok, legislation} ->
          {:cont, Map.put(acc, title, legislation)}
        
        {:error, reason} ->
          {:halt, {:error, {title, reason}}}
      end
    end)
    
    case results do
      %{} = success_map -> {:ok, success_map}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Search for existing legislation by title with fuzzy matching.
  
  Useful for manual deduplication or verification.
  """
  @spec search_legislation_fuzzy(String.t(), float()) :: {:ok, [struct()]} | {:error, term()}
  def search_legislation_fuzzy(search_title, similarity_threshold \\ 0.7) when is_binary(search_title) do
    normalized_search = EhsEnforcement.Utility.normalize_legislation_title(search_title)
    
    case EhsEnforcement.Enforcement.list_legislation() do
      {:ok, all_legislation} ->
        matches = all_legislation
        |> Enum.map(fn legislation ->
          similarity = EhsEnforcement.Utility.calculate_title_similarity(
            normalized_search, 
            legislation.legislation_title
          )
          {legislation, similarity}
        end)
        |> Enum.filter(fn {_legislation, similarity} -> similarity >= similarity_threshold end)
        |> Enum.sort_by(fn {_legislation, similarity} -> similarity end, :desc)
        |> Enum.map(fn {legislation, _similarity} -> legislation end)
        
        {:ok, matches}
      
      error -> error
    end
  end

  @doc """
  Get legislation statistics for monitoring duplicate prevention.
  """
  def get_legislation_stats do
    case EhsEnforcement.Enforcement.list_legislation() do
      {:ok, all_legislation} ->
        stats = %{
          total_count: length(all_legislation),
          by_type: group_by_type(all_legislation),
          missing_year: count_missing_field(all_legislation, :legislation_year),
          missing_number: count_missing_field(all_legislation, :legislation_number),
          potential_duplicates: find_potential_duplicates(all_legislation)
        }
        {:ok, stats}
      
      error -> error
    end
  end

  defp group_by_type(legislation_list) do
    Enum.group_by(legislation_list, & &1.legislation_type)
    |> Enum.map(fn {type, items} -> {type, length(items)} end)
    |> Enum.into(%{})
  end

  defp count_missing_field(legislation_list, field) do
    Enum.count(legislation_list, fn item ->
      Map.get(item, field) |> is_nil()
    end)
  end

  defp find_potential_duplicates(legislation_list) do
    # Group by normalized title and look for groups with multiple items
    legislation_list
    |> Enum.group_by(fn legislation ->
      # Group by title + year to identify potential duplicates
      {
        EhsEnforcement.Utility.normalize_legislation_title(legislation.legislation_title),
        legislation.legislation_year
      }
    end)
    |> Enum.filter(fn {_key, items} -> length(items) > 1 end)
    |> Enum.map(fn {{title, year}, items} ->
      %{
        normalized_title: title,
        year: year,
        count: length(items),
        records: Enum.map(items, & &1.id)
      }
    end)
  end
end