defmodule EhsEnforcement.Enforcement do
  @moduledoc """
  The Enforcement domain for managing enforcement agencies, cases, notices, and related entities.
  
  This domain uses Ash code interfaces. Generated functions are available for all resources.
  """
  
  use Ash.Domain, extensions: [AshPhoenix]
  
  require Ash.Query
  import Ash.Expr

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
      define :sync_case, action: :sync
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
  end

  forms do
    form :create_case, args: []
    form :sync_case, args: []
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
  - `list_offenders/1` - List all offenders with options
  - `get_offender/2` - Get offender by ID
  - `create_offender/2` - Create new offender
  - `update_offender/3` - Update existing offender
  - `search_offenders/2` - Search offenders with query
  - `update_offender_statistics/3` - Update offender statistics
  
  ## Case Functions
  - `list_cases/1` - List all cases with basic options (code interface)
  - `list_cases_with_filters/1` - List cases with complex filtering (custom function)
  - `get_case/2` - Get case by ID
  - `create_case/2` - Create new case
  - `sync_case/3` - Sync case data (update equivalent)
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
  """

  # Complex functions that extend beyond basic code interfaces

  def get_offender_by_name_and_postcode(name, postcode) do
    # Normalize the search name for matching
    normalized_search_name = EhsEnforcement.Sync.OffenderMatcher.normalize_company_name(name)
    
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


  def change_case(case_record, attrs \\ %{}) do
    case_record
    |> Ash.Changeset.for_update(:sync, attrs)
  end

  def list_cases_with_filters(opts \\ []) do
    query = EhsEnforcement.Enforcement.Case
    
    # Apply filters if provided
    query = case opts[:filter] do
      nil -> query
      filters ->
        Enum.reduce(filters, query, fn
          {:regulator_id, value}, q -> Ash.Query.filter(q, regulator_id == ^value)
          {:agency_id, value}, q -> Ash.Query.filter(q, agency_id == ^value)
          {:offence_action_date, conditions}, q when is_list(conditions) ->
            Enum.reduce(conditions, q, fn
              {:greater_than_or_equal_to, date}, acc_q -> Ash.Query.filter(acc_q, offence_action_date >= ^date)
              {:less_than_or_equal_to, date}, acc_q -> Ash.Query.filter(acc_q, offence_action_date <= ^date)
              _, acc_q -> acc_q
            end)
          {:offence_fine, conditions}, q when is_list(conditions) ->
            Enum.reduce(conditions, q, fn
              {:greater_than_or_equal_to, amount}, acc_q -> Ash.Query.filter(acc_q, offence_fine >= ^amount)
              {:less_than_or_equal_to, amount}, acc_q -> Ash.Query.filter(acc_q, offence_fine <= ^amount)
              _, acc_q -> acc_q
            end)
          {:search, pattern}, q ->
            # Handle search with OR conditions using proper Ash syntax
            # Search in: regulator_id, offence_breaches, and offender.name
            Ash.Query.filter(q, ilike(regulator_id, ^pattern) or ilike(offence_breaches, ^pattern) or ilike(offender.name, ^pattern))
          _, q -> q
        end)
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

  def list_cases_with_filters!(opts \\ []) do
    case list_cases_with_filters(opts) do
      {:ok, cases} -> cases
      {:error, error} -> raise error
    end
  end

  def count_cases!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Case
    
    # Apply filters if provided
    query = case opts[:filter] do
      nil -> query
      filters ->
        Enum.reduce(filters, query, fn
          {:regulator_id, value}, q -> Ash.Query.filter(q, regulator_id == ^value)
          {:agency_id, value}, q -> Ash.Query.filter(q, agency_id == ^value)
          {:offence_action_date, conditions}, q when is_list(conditions) ->
            Enum.reduce(conditions, q, fn
              {:greater_than_or_equal_to, date}, acc_q -> Ash.Query.filter(acc_q, offence_action_date >= ^date)
              {:less_than_or_equal_to, date}, acc_q -> Ash.Query.filter(acc_q, offence_action_date <= ^date)
              _, acc_q -> acc_q
            end)
          {:search, pattern}, q ->
            Ash.Query.filter(q, ilike(regulator_id, ^pattern) or ilike(offence_breaches, ^pattern) or ilike(offender.name, ^pattern))
          _, q -> q
        end)
    end
    
    case Ash.count(query) do
      {:ok, count} -> count
      {:error, error} -> raise error
    end
  end

  def count_offenders!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Offender
    
    # Apply filters if provided
    query = case opts[:filter] do
      nil -> query
      filters -> Ash.Query.filter(query, ^filters)
    end
    
    case Ash.count(query) do
      {:ok, count} -> count
      {:error, error} -> raise error
    end
  end

  def count_notices!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Notice
    
    # Apply filters if provided
    query = case opts[:filter] do
      nil -> query
      filters -> Ash.Query.filter(query, ^filters)
    end
    
    case Ash.count(query) do
      {:ok, count} -> count
      {:error, error} -> raise error
    end
  end

  def list_notices_with_filters!(opts \\ []) do
    query = EhsEnforcement.Enforcement.Notice
    
    # Apply complex filters if provided (beyond what code interfaces handle)
    query = case opts[:filter] do
      nil -> query
      filters ->
        Enum.reduce(filters, query, fn
          {:regulator_id, value}, q -> Ash.Query.filter(q, regulator_id == ^value)
          {:agency_id, value}, q -> Ash.Query.filter(q, agency_id == ^value)
          {:date_from, date}, q -> Ash.Query.filter(q, offence_action_date >= ^date)
          {:date_to, date}, q -> Ash.Query.filter(q, offence_action_date <= ^date)
          {:search, pattern}, q ->
            # Handle search with OR conditions
            Ash.Query.filter(q, ilike(regulator_id, ^pattern) or ilike(offence_breaches, ^pattern) or ilike(offender.name, ^pattern))
          _, q -> q
        end)
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
    
    case Ash.read(query) do
      {:ok, notices} -> notices
      {:error, error} -> raise error
    end
  end
end