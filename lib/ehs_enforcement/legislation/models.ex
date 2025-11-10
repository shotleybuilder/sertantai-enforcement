defmodule EhsEnforcement.Legislation.Models do
  @moduledoc """

  """
  @typeclass ~w[Act Regulation Order Rules Byelaws Measure Scheme]

  def type_class, do: @typeclass

  @hs_model [
    "💙 FIRE": [base: "app0bGzy4uDbKrCF5", si_codes: ["FIRE PRECAUTIONS", "FIRE SAFETY"]],
    "💙 FIRE: Dangerous and Explosive Substances": [
      base: "appqDhGjs1G7oVHrW",
      si_codes: ["PETROLEUM"]
    ],
    "💙 FOOD": [base: "", si_codes: ["FOOD", "FOOD AND DRUGS,COMPOSITION"]],
    "💙 HEALTH: Coronavirus": [base: "", si_codes: []],
    "💙 HEALTH: Drug & Medicine Safety": [base: "", si_codes: ["DANGEROUS DRUGS"]],
    "💙 HEALTH: Patient Safety": [base: "", si_codes: []],
    "💙 HEALTH: Public": [
      base: "",
      si_codes: ["MENTAL HEALTH", "PUBLIC HEALTH", "LICENSING (LIQUOR)"]
    ],
    "💜 HR: Employment": [base: "", si_codes: []],
    "💜 HR: Insurance / Compensation / Wages / Benefits": [base: "", si_codes: []],
    "💜 HR: Working Time": [base: "", si_codes: []],
    "💙 OH&S: Gas & Electrical Safety": [
      base: "appJu2qnECHmo9cln",
      si_codes: ["ELECTRICITY", "ELECTROMAGNETIC COMPATABILITY", "GAS"]
    ],
    "💙 OH&S: Mines & Quarries": [base: "appuoNQFKM2SUI3lK", si_codes: ["COAL INDUSTRY"]],
    "💙 OH&S: Occupational / Personal Safety": [
      base: "appiwDnCNQaZOSaVR",
      si_codes: [
        "HEALTH AND SAFETY",
        "HEALTH AND WELFARE",
        "SAFETY",
        "SAFETY, HEALTH AND WELFARE"
      ]
    ],
    "💙 OH&S: Offshore Safety": [base: "appDoxScBrdBhxnOb", si_codes: ["OFFSHORE INSTALLATIONS"]],
    "💙 PUBLIC": [base: "", si_codes: ["CONTROL OF DOGS", "DANGEROUS WILD ANIMALS"]],
    "💙 PUBLIC: Building Safety": [
      base: "",
      si_codes: ["BUILDING AND BUILDINGS", "BUILDING REGULATIONS"]
    ],
    "💙 PUBLIC: Consumer / Product Safety": [
      base: "appnTQBGljRQgVUhU",
      si_codes: ["CONSUMER PROTECTION"]
    ],
    "💙 TRANS: Air Safety": [base: "", si_codes: ["CIVIL AVIATION"]],
    "💙 TRANS: Rail Safety": [base: "", si_codes: []],
    "💙 TRANS: Road Safety": [base: "", si_codes: []],
    "💙 TRANS: Maritime Safety": [base: "", si_codes: []]
  ]

  def hs_family, do: Keyword.keys(@hs_model) |> Enum.map(&Atom.to_string(&1))

  def hs_model, do: @hs_model

  def hs_bases do
    Enum.map(
      @hs_model,
      fn {family, [base: base, si_codes: _]} ->
        {Atom.to_string(family), base}
      end
    )
  end

  def hs_si_code_family do
    Enum.reduce(
      @hs_model,
      %{},
      fn {family, [base: _, si_codes: si_codes]}, acc ->
        Enum.into(Enum.map(si_codes, fn si_code -> {si_code, Atom.to_string(family)} end), acc)
      end
    )
  end

  @e_model [
    "💚 AGRICULTURE": [
      base: "",
      si_codes: [
        "AGRICULTURAL",
        "AGRICULTURAL FOODSTUFFS (WASTE)",
        "AGRICULTURE",
        "AGRICULTURE HORTICULTURE",
        "COMMON AGRICULTURAL POLICY",
        "CROFTERS, COTTARS AND SMALL LANDHOLDERS",
        "HORTICULTURE",
        "PESTICIDES"
      ]
    ],
    "💚 AGRICULTURE: Pesticides": [base: "", si_codes: ["PESTICIDES"]],
    "💚 AIR QUALITY": [
      base: "",
      si_codes: ["CLEAN AIR", "CREMATION", "SMOKE", "STATUTORY NUISANCES AND CLEAN AIR"]
    ],
    "💚 ANIMALS & ANIMAL HEALTH": [
      base: "",
      si_codes: [
        "ANIMAL DISEASE",
        "ANIMAL HEALTH",
        "ANIMAL WELFARE",
        "ANIMALS",
        "ANIMALS HEALTH",
        "AQUATIC ANIMAL HEALTH",
        "BEE DISEASES",
        "DISEASES OF ANIMALS",
        "DISEASES OF FISH",
        "WELFARE OF ANIMALS",
        "ZOOS"
      ]
    ],
    "💚 ANTARCTICA": [base: "", si_codes: ["ANTARCTICA"]],
    "💚 BUILDINGS": [base: "", si_codes: []],
    "💚 CLIMATE CHANGE": [
      base: "appGv6qmDJK2Kdr3U",
      si_codes: ["CLIMATE CHANGE", "EMISSIONS TRADING"]
    ],
    "💚 ENERGY": [
      base: "app4L95N2NbK7x4M0",
      si_codes: [
        "ENERGY",
        "ENERGY CONSERVATION",
        "HEAT NETWORKS",
        "SUSTAINABLE AND RENEWABLE FUELS"
      ]
    ],
    "💚 ENVIRONMENTAL PROTECTION": [
      base: "appPFUz8wfo9RU7gN",
      si_codes: ["ENVIRONMENT", "ENVIRONMENTAL PROTECTION", "ENVIRONMENTAL PROTECTIONS"]
    ],
    "💚 FINANCE": [
      base: "appokFoa6ERUUAIkF",
      si_codes: [
        "AGGREGATES LEVY",
        "CLIMATE CHANGE LEVY",
        "LANDFILL TAX",
        "OIL TAX",
        "PLASTIC PACKAGING TAX",
        "STAMP DUTY LAND TAX"
      ]
    ],
    "💚 FISHERIES & FISHING": [
      base: "",
      si_codes: [
        "BOATS AND METHODS OF FISHING",
        "CONSERVATION OF SEA FISH",
        "FISH FARMING",
        "FISHERIES",
        "FISHERY LIMITS",
        "LANDING AND SALE OF SEA FISH",
        "RESTRICTION OF SEA FISHING",
        "SALMON AND FRESHWATER FISHERIES",
        "SEA FISH INDUSTRY",
        "SEA FISHERIES",
        "SHELLFISH"
      ]
    ],
    "💚 GMOs": [base: "", si_codes: []],
    "💚 HISTORIC ENVIRONMENT": [
      base: "",
      si_codes: [
        "ANCIENT MONUMENTS",
        "HISTORIC BUILDINGS AND MONUMENTS COMMISSION ARTS COUNCIL",
        "PROTECTION OF WRECKS"
      ]
    ],
    "💚 MARINE & RIVERINE": [
      base: "appLXqkeiiqrOXwWw",
      si_codes: [
        "CANALS AND INLAND WATERWAYS",
        "COAST PROTECTION",
        "CONTINENTAL SHELF",
        "DEEP SEA MINING",
        "ENVIRONMENTAL PROTECTION;MARINE LICENSING",
        "LICENSING (MARINE)",
        "MARINE CONSERVATION",
        "MARINE ENVIRONMENT",
        "MARINE LICENSING",
        "MARINE MANAGEMENT",
        "RIVER",
        "RIVER,SALMON AND FRESHWATER FISHERIES",
        "RIVER;SALMON AND FRESHWATER FISHERIES",
        "RIVERS"
      ]
    ],
    "💚 TRANSPORT: Harbours & Shipping": [base: "", si_codes: []],
    "💚 NOISE": [base: "", si_codes: ["NOISE"]],
    "💚 PLANNING & INFRASTRUCTURE": [
      base: "appJ3UVvRHEGIpNi4",
      si_codes: [
        "HARBOUR",
        "HARBOURS",
        "HARBOURS, DOCKS, PIERS AND FERRIES",
        "HIGHWAYS",
        "INDUSTRIAL DEVELOPMENT",
        "INFRASTRUCTURE PLANNING",
        "LONDON PLANNING",
        "NEW TOWNS",
        "PLANNING",
        "PLANNING FEES",
        "TRANSPORT AND WORKS"
      ]
    ],
    "💚 PLANT HEALTH": [
      base: "",
      si_codes: [
        "PLANT BREEDERS' RIGHTS",
        "PLANT HEALTH",
        "SEEDS",
        "WEEDS AND AGRICULTURAL SEEDS"
      ]
    ],
    "💚 POLLUTION": [
      base: "appj4oaimWQfwtUri",
      si_codes: [
        "INDUSTRIAL POLLUTION CONTROL",
        "LAND POLLUTION",
        "MARINE POLLUTION",
        "POLLUTION"
      ]
    ],
    "💚 NUCLEAR & RADIOLOGICAL": [
      base: "appozWdOMaGdp77eL",
      si_codes: [
        "ATOMIC ENERGY AND RADIOACTIVE SUBSTANCES",
        "RADIOACTIVE SUBSTANCES",
        "NUCLEAR ENERGY",
        "NUCLEAR SAFEGUARDS",
        "NUCLEAR SECURITY",
        "RADIOACTIVE SUBSTANCES"
      ]
    ],
    "💚 OIL & GAS - OFFSHORE - PETROLEUM": [base: "", si_codes: ["PETROLEUM"]],
    "💚 Railways & Rail Transport": [base: "", si_codes: []],
    "💚 Roads & Vehicles": [base: "", si_codes: []],
    "💚 TRANSPORT: Aviation": [base: "", si_codes: ["AIRPORTS"]],
    "💚 TOWN & COUNTRY PLANNING": [
      base: "",
      si_codes: ["OPEN SPACES", "TOWN AND COUNTRY PLANNING", "URBAN DEVELOPMENT"]
    ],
    "💚 TREES: Forestry & Timber": [base: "", si_codes: ["FORESTRY"]],
    "💚 WASTE": [
      base: "appfXbCYZmxSFQ6uY",
      si_codes: [
        "DUMPING AT SEA",
        "GENERAL WASTE MATERIALS",
        "GENERAL WASTE MATERIALS RECLAMATION",
        "SCRAP METAL DEALERS",
        "WASTE",
        "WASTE PRODUCTS RECLAMATION"
      ]
    ],
    "💚 WATER & WASTEWATER": [
      base: "appCZkMT3VlCLtBjy",
      si_codes: [
        "FLOOD RISK MANAGEMENT",
        "LAND DRAINAGE",
        "WATER",
        "WATER AND SEWERAGE",
        "WATER AND SEWERAGE SERVICES",
        "WATER INDUSTRY",
        "WATER RESOURCES",
        "WATER SUPPLY"
      ]
    ],
    "💚 WILDLIFE & COUNTRYSIDE": [
      base: "appXXwjSS8KgDySB6",
      si_codes: [
        "ACCESS TO THE COUNTRYSIDE",
        "COMMON",
        "COMMONS",
        "CONSERVATION",
        "CONSERVATION AREAS",
        "COUNTRYSIDE",
        "HILL LANDS",
        "HUNTING",
        "NATIONAL PARKS",
        "NATURAL ENVIRONMENT",
        "NATURE CONSERVATION",
        "RIGHTS OF WAY",
        "WILD BIRDS",
        "WILD BIRDS PROTECTION",
        "WILD BIRDS SALE FOR CONSUMPTION",
        "WILD BIRDS-CLASSIFICATION",
        "WILD BIRDS.",
        "WILD BIRDS: BIRD SANCTUARY",
        "WILD BIRDS: SALE FOR CONSUMPTION",
        "WILDLIFE"
      ]
    ]
  ]

  def e_family, do: Keyword.keys(@e_model) |> Enum.map(&Atom.to_string(&1))

  def e_model, do: @e_model

  def e_bases do
    Enum.map(
      @e_model,
      fn {family, [base: base, si_codes: _]} ->
        {Atom.to_string(family), base}
      end
    )
  end

  def e_si_code_family do
    Enum.reduce(
      @e_model,
      %{},
      fn {family, [base: _, si_codes: si_codes]}, acc ->
        Enum.into(Enum.map(si_codes, fn si_code -> {si_code, Atom.to_string(family)} end), acc)
      end
    )
  end

  def ehs_si_code_family do
    Map.merge(hs_si_code_family(), e_si_code_family())
  end

  def ehs_family, do: hs_family() ++ e_family()
end
