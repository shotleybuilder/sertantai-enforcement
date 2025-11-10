defmodule EhsEnforcement.Legislation.TypeCode do
  defstruct ukpga: "ukpga",
            uksi: "uksi",
            nia: "nia",
            apni: "apni",
            nisi: "nisi",
            nisr: "nisr",
            nisro: "nisro",
            asp: "asp",
            ssi: "ssi",
            asc: "asc",
            anaw: "anaw",
            mwa: "mwa",
            wsi: "wsi",
            ukla: "ukla",
            ni: ["nia", "apni", "nisi", "nisr", "nisro"],
            s: ["asp", "ssi"],
            uk: ["ukpga", "uksi"],
            w: ["asc", "anaw", "mwa", "wsi"],
            o: ["ukcm", "ukla", "asc", "ukmo", "apgb", "aep"]

  def type_codes do
    ~w[ukpga uksi asp ssi asc uksi nia apni nisi nisr nisro anaw mwa wsi ukla eur eudr eudn]
  end

  def type_code(type_code) when is_atom(type_code) do
    case Map.get(%__MODULE__{}, type_code) do
      nil -> {:error, "No result for #{type_code}"}
      result when is_list(result) -> {:ok, result}
      result -> {:ok, [result]}
    end
  end

  def type_code(type_code) when is_list(type_code), do: {:ok, type_code}

  def type_code(nil), do: {:ok, [""]}

  def type_code(type_code) when is_binary(type_code), do: {:ok, [type_code]}

  def type_code(type_code),
    do: {:error, "Types for type_code must be Atom or List. You gave #{type_code}"}

  def type_code_from_title(title) do
    cond do
      String.contains?(title, "Act") -> {:ok, "ukpga"}
      String.contains?(title, "Regulation") -> {:ok, "uksi"}
      String.contains?(title, "Order") -> {:ok, "uksi"}
    end
  end
end

defmodule EhsEnforcement.Legislation.SClass do
  defstruct occupational_personal_safety: "Occupational / Personal Safety"

  def sClass(sClass) when is_atom(sClass) do
    case Map.get(%__MODULE__{}, sClass) do
      nil -> {:error, "No result for #{sClass}"}
      result -> {:ok, [result]}
    end
  end

  def sClass(sClass) when is_binary(sClass), do: {:ok, sClass}
end
