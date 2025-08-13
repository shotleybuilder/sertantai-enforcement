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
    
    resource EhsEnforcement.Enforcement.Breach do
      define :list_breaches, action: :read
      define :get_breach, action: :read, get_by: [:id]
      define :create_breach, action: :create
      define :update_breach, action: :update
    end
    
    resource EhsEnforcement.Enforcement.Metrics do
      define :get_current_metrics, action: :get_current
      define :refresh_metrics, action: :refresh
    end
    
    resource EhsEnforcement.Enforcement.Violation do
      define :list_violations, action: :read
      define :get_violation, action: :read, get_by: [:id]
      define :create_violation, action: :create
      define :update_violation, action: :update
      define :destroy_violation, action: :destroy
      define :list_violations_by_case, action: :by_case, args: [:case_id]
      define :get_violation_by_case_reference, action: :by_case_reference, args: [:case_reference]
      define :bulk_create_violations, action: :bulk_create
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
  
  ## Breach Functions
  - `list_breaches/1` - List all breaches with options
  - `get_breach/2` - Get breach by ID
  - `create_breach/2` - Create new breach
  - `update_breach/3` - Update existing breach
  
  ## Metrics Functions
  - `get_current_metrics/1` - Get current cached dashboard metrics
  - `refresh_metrics/1` - Refresh all dashboard metrics from current data
  
  ## Violation Functions (EA Multi-offence Support)
  - `list_violations/1` - List all violations with options
  - `get_violation/2` - Get violation by ID
  - `create_violation/2` - Create new violation
  - `update_violation/3` - Update existing violation
  - `destroy_violation/2` - Delete violation
  - `list_violations_by_case/2` - List violations for specific case
  - `get_violation_by_case_reference/2` - Get violation by EA case reference
  - `bulk_create_violations/2` - Bulk create multiple violations for EA cases
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
      ilike(offence_breaches, ^pattern) or 
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
      [%Case{regulator_id: "HSE-2024-123", offence_breaches: "Construction (Design and Management) Regulations 2015"}]
      
      iex> fuzzy_search_cases("acme corp", similarity_threshold: 0.4)
      [%Case{offender: %{name: "ACME Construction Ltd"}}]
  """
  def fuzzy_search_cases(search_term, opts \\ [])
  def fuzzy_search_cases(search_term, opts) when is_binary(search_term) and byte_size(search_term) >= 3 do
    similarity_threshold = opts[:similarity_threshold] || 0.3
    
    query = EhsEnforcement.Enforcement.Case
    |> Ash.Query.filter(
      trigram_similarity(regulator_id, ^search_term) > ^similarity_threshold or
      trigram_similarity(offence_breaches, ^search_term) > ^similarity_threshold or
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
      trigram_similarity(offence_breaches, ^search_term) > ^similarity_threshold or
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
end