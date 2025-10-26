defmodule EhsEnforcement.Scraping.StrategyRegistryTest do
  use ExUnit.Case, async: true

  alias EhsEnforcement.Scraping.StrategyRegistry

  describe "get_strategy/2" do
    test "returns HSE Case strategy for :hse and :case" do
      assert {:ok, strategy} = StrategyRegistry.get_strategy(:hse, :case)
      assert strategy == EhsEnforcement.Scraping.Strategies.HSE.CaseStrategy
    end

    test "returns HSE Notice strategy for :hse and :notice" do
      assert {:ok, strategy} = StrategyRegistry.get_strategy(:hse, :notice)
      assert strategy == EhsEnforcement.Scraping.Strategies.HSE.NoticeStrategy
    end

    test "returns EA Case strategy for :environment_agency and :case" do
      assert {:ok, strategy} = StrategyRegistry.get_strategy(:environment_agency, :case)
      assert strategy == EhsEnforcement.Scraping.Strategies.EA.CaseStrategy
    end

    test "returns EA Notice strategy for :environment_agency and :notice" do
      assert {:ok, strategy} = StrategyRegistry.get_strategy(:environment_agency, :notice)
      assert strategy == EhsEnforcement.Scraping.Strategies.EA.NoticeStrategy
    end

    test "returns error for unknown agency" do
      assert {:error, :strategy_not_found} = StrategyRegistry.get_strategy(:unknown_agency, :case)
    end

    test "returns error for unknown enforcement type" do
      assert {:error, :strategy_not_found} = StrategyRegistry.get_strategy(:hse, :unknown_type)
    end

    test "returns error for unknown agency and type combination" do
      assert {:error, :strategy_not_found} =
               StrategyRegistry.get_strategy(:unknown_agency, :unknown_type)
    end
  end

  describe "list_strategies/0" do
    test "returns list of all registered strategy combinations" do
      strategies = StrategyRegistry.list_strategies()

      assert is_list(strategies)
      assert length(strategies) == 4

      # Check all expected strategies are present
      assert {:hse, :case} in strategies
      assert {:hse, :notice} in strategies
      assert {:environment_agency, :case} in strategies
      assert {:environment_agency, :notice} in strategies
    end

    test "returned list contains only tuples of {agency, enforcement_type}" do
      strategies = StrategyRegistry.list_strategies()

      Enum.each(strategies, fn strategy ->
        assert is_tuple(strategy)
        assert tuple_size(strategy) == 2

        {agency, enforcement_type} = strategy
        assert is_atom(agency)
        assert is_atom(enforcement_type)
      end)
    end
  end

  describe "count_strategies/0" do
    test "returns correct count of registered strategies" do
      assert StrategyRegistry.count_strategies() == 4
    end

    test "count matches length of list_strategies" do
      assert StrategyRegistry.count_strategies() == length(StrategyRegistry.list_strategies())
    end
  end

  describe "strategy_exists?/2" do
    test "returns true for HSE Case strategy" do
      assert StrategyRegistry.strategy_exists?(:hse, :case) == true
    end

    test "returns true for HSE Notice strategy" do
      assert StrategyRegistry.strategy_exists?(:hse, :notice) == true
    end

    test "returns true for EA Case strategy" do
      assert StrategyRegistry.strategy_exists?(:environment_agency, :case) == true
    end

    test "returns true for EA Notice strategy" do
      assert StrategyRegistry.strategy_exists?(:environment_agency, :notice) == true
    end

    test "returns false for unknown agency" do
      assert StrategyRegistry.strategy_exists?(:unknown_agency, :case) == false
    end

    test "returns false for unknown enforcement type" do
      assert StrategyRegistry.strategy_exists?(:hse, :unknown_type) == false
    end

    test "returns false for unknown combination" do
      assert StrategyRegistry.strategy_exists?(:unknown_agency, :unknown_type) == false
    end
  end

  describe "strategy consistency" do
    test "all strategies from list_strategies can be retrieved via get_strategy" do
      strategies = StrategyRegistry.list_strategies()

      Enum.each(strategies, fn {agency, enforcement_type} ->
        assert {:ok, _strategy} = StrategyRegistry.get_strategy(agency, enforcement_type)
      end)
    end

    test "strategy_exists? returns true for all strategies from list_strategies" do
      strategies = StrategyRegistry.list_strategies()

      Enum.each(strategies, fn {agency, enforcement_type} ->
        assert StrategyRegistry.strategy_exists?(agency, enforcement_type) == true
      end)
    end

    test "get_strategy returns consistent module for multiple calls" do
      {:ok, strategy1} = StrategyRegistry.get_strategy(:hse, :case)
      {:ok, strategy2} = StrategyRegistry.get_strategy(:hse, :case)

      assert strategy1 == strategy2
    end
  end
end
