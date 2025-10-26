defmodule EhsEnforcement.Scraping.StrategyRegistry do
  @moduledoc """
  Central registry for scraping strategies.

  This module provides a centralized lookup mechanism for finding the
  appropriate strategy module based on agency and enforcement type.

  Strategies are registered as a static compile-time map, providing
  fast lookup with zero runtime overhead.

  ## Usage

      # In LiveView mount
      {:ok, strategy} = StrategyRegistry.get_strategy(:hse, :case)
      # => {:ok, EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy}

      # List all available strategies
      strategies = StrategyRegistry.list_strategies()
      # => [{:hse, :case}, {:hse, :notice}, {:environment_agency, :case}, ...]

      # Handle missing strategy
      case StrategyRegistry.get_strategy(:unknown_agency, :case) do
        {:ok, strategy} -> use_strategy(strategy)
        {:error, :strategy_not_found} -> show_error("Unsupported agency")
      end

  ## Adding New Strategies

  To add a new agency or enforcement type, update the `@strategies` map
  in this module and implement the corresponding strategy module:

      @strategies %{
        # Existing strategies
        {:hse, :case} => EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy,

        # New strategy
        {:sepa, :case} => EhsEnforcement.Scraping.Strategies.SEPA.CaseStrategy
      }

  Then implement the strategy module following the `ScrapeStrategy` behavior.
  """

  @typedoc """
  Agency identifier atom.

  Currently supported agencies:
  - `:hse` - Health and Safety Executive
  - `:environment_agency` - Environment Agency

  Future agencies:
  - `:sepa` - Scottish Environment Protection Agency
  - `:nrw` - Natural Resources Wales
  """
  @type agency :: atom()

  @typedoc """
  Enforcement type identifier.

  Supported types:
  - `:case` - Court cases and prosecutions
  - `:notice` - Enforcement notices
  """
  @type enforcement_type :: :case | :notice

  @typedoc """
  Strategy module implementing the ScrapeStrategy behavior.
  """
  @type strategy_module :: module()

  # Strategy registry mapping {agency, enforcement_type} to strategy modules.
  # Each entry maps an agency/type combination to its implementing strategy module.
  # All strategy modules must implement the `EhsEnforcement.Scraping.ScrapeStrategy` behavior.
  @strategies %{
    {:hse, :case} => EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy,
    {:hse, :notice} => EhsEnforcement.Scraping.Strategies.HSE.NoticeStrategy,
    {:environment_agency, :case} => EhsEnforcement.Scraping.Strategies.EA.CaseStrategy,
    {:environment_agency, :notice} => EhsEnforcement.Scraping.Strategies.EA.NoticeStrategy
  }

  @doc """
  Retrieves the strategy module for a given agency and enforcement type.

  Returns the strategy module if found, or an error tuple if no matching
  strategy exists.

  ## Parameters

    * `agency` - Agency identifier atom (e.g., `:hse`, `:environment_agency`)
    * `enforcement_type` - Enforcement type atom (`:case` or `:notice`)

  ## Returns

    * `{:ok, strategy_module}` - Successfully found strategy module
    * `{:error, :strategy_not_found}` - No strategy registered for this combination

  ## Examples

      iex> StrategyRegistry.get_strategy(:hse, :case)
      {:ok, EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy}

      iex> StrategyRegistry.get_strategy(:environment_agency, :notice)
      {:ok, EhsEnforcement.Scraping.Strategies.EA.NoticeStrategy}

      iex> StrategyRegistry.get_strategy(:unknown_agency, :case)
      {:error, :strategy_not_found}

      iex> StrategyRegistry.get_strategy(:hse, :unknown_type)
      {:error, :strategy_not_found}
  """
  @spec get_strategy(agency(), enforcement_type()) ::
          {:ok, strategy_module()} | {:error, :strategy_not_found}
  def get_strategy(agency, enforcement_type) when is_atom(agency) and is_atom(enforcement_type) do
    case Map.get(@strategies, {agency, enforcement_type}) do
      nil -> {:error, :strategy_not_found}
      strategy -> {:ok, strategy}
    end
  end

  @doc """
  Lists all registered strategy combinations.

  Returns a list of `{agency, enforcement_type}` tuples representing
  all available strategies.

  ## Returns

  List of `{agency, enforcement_type}` tuples

  ## Examples

      iex> StrategyRegistry.list_strategies()
      [
        {:hse, :case},
        {:hse, :notice},
        {:environment_agency, :case},
        {:environment_agency, :notice}
      ]
  """
  @spec list_strategies() :: list({agency(), enforcement_type()})
  def list_strategies do
    Map.keys(@strategies)
  end

  @doc """
  Returns the total number of registered strategies.

  ## Examples

      iex> StrategyRegistry.count_strategies()
      4
  """
  @spec count_strategies() :: non_neg_integer()
  def count_strategies do
    map_size(@strategies)
  end

  @doc """
  Checks if a strategy exists for the given agency and enforcement type.

  ## Parameters

    * `agency` - Agency identifier atom
    * `enforcement_type` - Enforcement type atom

  ## Returns

  Boolean indicating whether the strategy exists

  ## Examples

      iex> StrategyRegistry.strategy_exists?(:hse, :case)
      true

      iex> StrategyRegistry.strategy_exists?(:unknown, :case)
      false
  """
  @spec strategy_exists?(agency(), enforcement_type()) :: boolean()
  def strategy_exists?(agency, enforcement_type) do
    Map.has_key?(@strategies, {agency, enforcement_type})
  end
end
