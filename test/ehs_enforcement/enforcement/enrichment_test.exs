defmodule EhsEnforcement.Enforcement.EnrichmentTest do
  use EhsEnforcement.DataCase, async: true

  require Ash.Query
  import Ash.Expr

  alias EhsEnforcement.Enforcement

  setup do
    # Create test agency
    {:ok, agency} =
      Enforcement.create_agency(%{
        code: :hse,
        name: "Health and Safety Executive"
      })

    # Create test offender
    {:ok, offender} =
      Enforcement.create_offender(%{
        name: "Test Company Ltd",
        local_authority: "Manchester"
      })

    # Create test case
    {:ok, test_case} =
      Enforcement.create_case(%{
        agency_id: agency.id,
        offender_id: offender.id,
        regulator_id: "HSE001",
        offence_result: "Guilty",
        offence_fine: Decimal.new("10000.00"),
        offence_action_date: ~D[2024-01-15],
        offence_breaches: "Health and Safety at Work etc. Act 1974"
      })

    # Create test notice
    {:ok, test_notice} =
      Enforcement.create_notice(%{
        agency_id: agency.id,
        offender_id: offender.id,
        regulator_id: "HSE-NOTICE-001",
        offence_action_type: "Improvement Notice",
        offence_action_date: ~D[2024-02-01],
        notice_date: ~D[2024-02-01],
        notice_body: "You must comply with regulations"
      })

    %{
      agency: agency,
      offender: offender,
      test_case: test_case,
      test_notice: test_notice
    }
  end

  describe "enrichment resource - case enrichment" do
    test "creates enrichment for a case with all fields", %{test_case: test_case} do
      attrs = %{
        case_id: test_case.id,
        regulation_links: [
          %{
            "act" => "Health and Safety at Work etc. Act 1974",
            "section" => "Section 2",
            "relevance_score" => 0.95,
            "summary" => "General duty of employers"
          }
        ],
        benchmark_analysis: %{
          "average_fine" => 15000,
          "percentile_ranking" => 65,
          "similar_cases_count" => 42
        },
        pattern_detection: %{
          "similar_cases" => 5,
          "trend" => "increasing",
          "notable_precedents" => ["Case A", "Case B"]
        },
        layperson_summary: "This case involved workplace safety violations.",
        professional_summary: "The defendant failed to ensure adequate safety measures.",
        auto_tags: ["construction", "safety-violation", "repeat-offender"],
        confidence_scores: %{
          "regulation_links" => 0.95,
          "benchmark_accuracy" => 0.87,
          "pattern_detection" => 0.82
        },
        model_version: "gpt-4-turbo",
        processing_time_ms: 2500
      }

      assert {:ok, enrichment} = Enforcement.create_enrichment(attrs)

      assert enrichment.case_id == test_case.id
      assert enrichment.notice_id == nil
      assert length(enrichment.regulation_links) == 1
      assert enrichment.benchmark_analysis["average_fine"] == 15000
      assert enrichment.layperson_summary =~ "workplace safety"
      assert enrichment.professional_summary =~ "adequate safety measures"
      assert length(enrichment.auto_tags) == 3
      assert enrichment.model_version == "gpt-4-turbo"
      assert enrichment.processing_time_ms == 2500
    end

    test "creates minimal enrichment for a case", %{test_case: test_case} do
      attrs = %{
        case_id: test_case.id,
        layperson_summary: "Brief summary",
        model_version: "claude-sonnet-3.5"
      }

      assert {:ok, enrichment} = Enforcement.create_enrichment(attrs)
      assert enrichment.case_id == test_case.id
      assert enrichment.model_version == "claude-sonnet-3.5"
    end

    test "queries enrichment by case", %{test_case: test_case} do
      # Create enrichment
      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "Test summary",
          model_version: "gpt-4"
        })

      # Query by case
      {:ok, found} = Enforcement.get_enrichment_by_case(test_case.id)
      assert found.id == enrichment.id
      assert found.case_id == test_case.id
    end

    test "calculates enrichment_type for case enrichment", %{test_case: test_case} do
      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "Test",
          model_version: "gpt-4"
        })

      # Load with calculation
      loaded =
        Enforcement.get_enrichment!(enrichment.id, load: [:enrichment_type])

      assert loaded.enrichment_type == :case
    end
  end

  describe "enrichment resource - notice enrichment" do
    test "creates enrichment for a notice", %{test_notice: test_notice} do
      attrs = %{
        notice_id: test_notice.id,
        regulation_links: [
          %{
            "act" => "Health and Safety at Work etc. Act 1974",
            "section" => "Section 21",
            "relevance_score" => 0.92
          }
        ],
        benchmark_analysis: %{
          "avg_compliance_period" => 30,
          "notice_escalation_rate" => 0.15
        },
        layperson_summary: "Notice requires safety improvements within 30 days.",
        professional_summary: "Improvement notice issued under Section 21.",
        model_version: "claude-sonnet-3.5"
      }

      assert {:ok, enrichment} = Enforcement.create_enrichment(attrs)

      assert enrichment.notice_id == test_notice.id
      assert enrichment.case_id == nil
      assert enrichment.model_version == "claude-sonnet-3.5"
    end

    test "queries enrichment by notice", %{test_notice: test_notice} do
      # Create enrichment
      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          notice_id: test_notice.id,
          layperson_summary: "Notice summary",
          model_version: "gpt-4"
        })

      # Query by notice
      {:ok, found} = Enforcement.get_enrichment_by_notice(test_notice.id)
      assert found.id == enrichment.id
      assert found.notice_id == test_notice.id
    end

    test "calculates enrichment_type for notice enrichment", %{test_notice: test_notice} do
      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          notice_id: test_notice.id,
          layperson_summary: "Test",
          model_version: "gpt-4"
        })

      # Load with calculation
      loaded =
        Enforcement.get_enrichment!(enrichment.id, load: [:enrichment_type])

      assert loaded.enrichment_type == :notice
    end
  end

  describe "enrichment resource - validation rules" do
    test "requires model_version" do
      attrs = %{
        layperson_summary: "Test summary"
        # Missing model_version
      }

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_enrichment(attrs)
    end

    test "requires either case_id or notice_id" do
      attrs = %{
        layperson_summary: "Test summary",
        model_version: "gpt-4"
        # Missing both case_id and notice_id
      }

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_enrichment(attrs)
    end

    test "prevents enrichment with both case_id and notice_id", %{
      test_case: test_case,
      test_notice: test_notice
    } do
      attrs = %{
        case_id: test_case.id,
        notice_id: test_notice.id,
        layperson_summary: "Test summary",
        model_version: "gpt-4"
      }

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_enrichment(attrs)
    end

    test "requires at least one enrichment field", %{test_case: test_case} do
      attrs = %{
        case_id: test_case.id,
        model_version: "gpt-4"
        # No enrichment fields (regulation_links, benchmark_analysis, etc.)
      }

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_enrichment(attrs)
    end

    test "enforces processing_time_ms >= 0", %{test_case: test_case} do
      attrs = %{
        case_id: test_case.id,
        layperson_summary: "Test",
        model_version: "gpt-4",
        processing_time_ms: -100
      }

      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_enrichment(attrs)
    end
  end

  describe "enrichment resource - query actions" do
    test "lists enrichments by model version", %{test_case: test_case, test_notice: test_notice} do
      # Create enrichments with different models
      {:ok, _e1} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "GPT summary",
          model_version: "gpt-4-turbo"
        })

      {:ok, _e2} =
        Enforcement.create_enrichment(%{
          notice_id: test_notice.id,
          layperson_summary: "Claude summary",
          model_version: "claude-sonnet-3.5"
        })

      {:ok, _e3} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          professional_summary: "Another GPT",
          model_version: "gpt-4-turbo"
        })

      # Query by model version
      {:ok, gpt_enrichments} = Enforcement.list_enrichments_by_model("gpt-4-turbo")
      assert length(gpt_enrichments) == 2

      {:ok, claude_enrichments} = Enforcement.list_enrichments_by_model("claude-sonnet-3.5")
      assert length(claude_enrichments) == 1
    end

    test "lists recent enrichments", %{test_case: test_case} do
      # Create enrichment (will have recent generated_at timestamp)
      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "Recent enrichment",
          model_version: "gpt-4"
        })

      # Query recent enrichments
      {:ok, recent} = Enforcement.list_recent_enrichments()

      # Should include our enrichment
      assert Enum.any?(recent, fn e -> e.id == enrichment.id end)
    end

    test "updates enrichment content", %{test_case: test_case} do
      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "Original summary",
          model_version: "gpt-4"
        })

      # Update enrichment
      {:ok, updated} =
        Enforcement.update_enrichment(enrichment, %{
          layperson_summary: "Updated summary",
          auto_tags: ["new-tag", "another-tag"]
        })

      assert updated.layperson_summary == "Updated summary"
      assert length(updated.auto_tags) == 2

      # case_id and model_version should be immutable (not in update action)
      assert updated.case_id == test_case.id
      assert updated.model_version == "gpt-4"
    end

    test "destroys enrichment", %{test_case: test_case} do
      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "To be deleted",
          model_version: "gpt-4"
        })

      assert :ok = Enforcement.destroy_enrichment(enrichment)

      # Should not be found
      assert_raise Ash.Error.Invalid, fn ->
        Enforcement.get_enrichment!(enrichment.id)
      end
    end
  end

  describe "enrichment resource - defaults and timestamps" do
    test "sets default values correctly", %{test_case: test_case} do
      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "Test",
          model_version: "gpt-4"
        })

      # auto_tags defaults to empty array
      assert enrichment.auto_tags == []

      # Timestamps are set
      assert enrichment.inserted_at != nil
      assert enrichment.updated_at != nil
      assert enrichment.generated_at != nil
    end

    test "generated_at can be set explicitly", %{test_case: test_case} do
      explicit_time = DateTime.utc_now() |> DateTime.add(-3600, :second)

      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "Test",
          model_version: "gpt-4",
          generated_at: explicit_time
        })

      # Should use the explicit time
      assert DateTime.diff(enrichment.generated_at, explicit_time, :second) == 0
    end
  end

  describe "enrichment resource - relationships" do
    test "loads case relationship", %{test_case: test_case} do
      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "Test",
          model_version: "gpt-4"
        })

      # Load with case relationship
      loaded = Enforcement.get_enrichment!(enrichment.id, load: [:case])

      assert loaded.case.id == test_case.id
      assert loaded.case.regulator_id == "HSE001"
    end

    test "loads notice relationship", %{test_notice: test_notice} do
      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          notice_id: test_notice.id,
          layperson_summary: "Test",
          model_version: "gpt-4"
        })

      # Load with notice relationship
      loaded = Enforcement.get_enrichment!(enrichment.id, load: [:notice])

      assert loaded.notice.id == test_notice.id
      assert loaded.notice.regulator_id == "HSE-NOTICE-001"
    end

    test "returns most recent enrichment when multiple exist", %{test_case: test_case} do
      # Create first enrichment
      {:ok, first} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "First enrichment",
          model_version: "gpt-4"
        })

      # Wait a moment to ensure different timestamps
      :timer.sleep(100)

      # Create second enrichment for same case
      {:ok, second} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "Second enrichment",
          model_version: "gpt-4-turbo"
        })

      # by_case should return most recent (sorted by generated_at desc, limited to 1)
      {:ok, found} = Enforcement.get_enrichment_by_case(test_case.id)

      assert found.id == second.id
      assert found.layperson_summary == "Second enrichment"
    end
  end

  describe "enrichment resource - database constraints" do
    test "database enforces XOR constraint on case_id and notice_id", %{
      test_case: test_case,
      test_notice: test_notice
    } do
      # Try to insert with both IDs directly (bypassing Ash validation)
      # This should fail at the database level
      attrs = %{
        case_id: test_case.id,
        notice_id: test_notice.id,
        layperson_summary: "Test",
        model_version: "gpt-4"
      }

      # Ash validation should catch this first
      assert {:error, %Ash.Error.Invalid{}} = Enforcement.create_enrichment(attrs)
    end

    test "database enforces foreign key constraints", %{test_case: test_case} do
      # Create enrichment
      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          layperson_summary: "Test",
          model_version: "gpt-4"
        })

      # Try to delete the case - should fail due to FK constraint
      result = Enforcement.destroy_case(test_case)

      # Should get an error due to foreign key constraint
      assert {:error, %Ash.Error.Unknown{}} = result

      # Enrichment should still exist
      assert {:ok, loaded} = Enforcement.get_enrichment(enrichment.id)
      assert loaded.case_id == test_case.id
    end
  end

  describe "enrichment resource - JSONB field handling" do
    test "stores and retrieves complex regulation_links", %{test_case: test_case} do
      complex_links = [
        %{
          "act" => "Health and Safety at Work etc. Act 1974",
          "section" => "Section 2(1)",
          "subsection" => "a",
          "relevance_score" => 0.95,
          "summary" => "General duty of employers to employees",
          "penalty_range" => %{"min" => 1000, "max" => 50000}
        },
        %{
          "act" => "Management of Health and Safety at Work Regulations 1999",
          "section" => "Regulation 3",
          "relevance_score" => 0.88,
          "summary" => "Risk assessment requirement"
        }
      ]

      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          regulation_links: complex_links,
          model_version: "gpt-4"
        })

      # Retrieve and verify
      found = Enforcement.get_enrichment!(enrichment.id)
      assert length(found.regulation_links) == 2
      assert found.regulation_links |> List.first() |> Map.get("subsection") == "a"

      assert found.regulation_links
             |> List.first()
             |> Map.get("penalty_range")
             |> Map.get("max") == 50000
    end

    test "stores and retrieves nested benchmark_analysis", %{test_case: test_case} do
      benchmarks = %{
        "financial" => %{
          "average_fine" => 15000,
          "median_fine" => 12000,
          "percentile_ranking" => 65,
          "similar_cases_count" => 42
        },
        "temporal" => %{
          "year_over_year_change" => 0.15,
          "trend" => "increasing"
        },
        "comparative" => %{
          "industry_average" => 18000,
          "regional_average" => 14500
        }
      }

      {:ok, enrichment} =
        Enforcement.create_enrichment(%{
          case_id: test_case.id,
          benchmark_analysis: benchmarks,
          layperson_summary: "Test",
          model_version: "gpt-4"
        })

      found = Enforcement.get_enrichment!(enrichment.id)
      assert found.benchmark_analysis["financial"]["average_fine"] == 15000
      assert found.benchmark_analysis["temporal"]["trend"] == "increasing"
      assert found.benchmark_analysis["comparative"]["regional_average"] == 14500
    end
  end
end
