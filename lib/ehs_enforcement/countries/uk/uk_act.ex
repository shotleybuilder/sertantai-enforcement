defmodule UK.Act do
  @fields [
    :id,
    :name,
    :flow,
    :type,
    :part,
    :chapter,
    :heading,
    :section,
    :sub_section,
    :para,
    :sub_para,
    :amendment,
    :changes,
    :region,
    :max_amendments,
    :max_modifications,
    :max_commencements,
    :max_extents,
    :max_editorials,
    :heading?,
    :table_counter,
    :figure_counter,
    :text
  ]
  @number_fields [
    :part,
    :chapter,
    :heading,
    :section,
    :sub_section,
    :para,
    :sub_para,
    :amendment
  ]

  defstruct @fields

  @doc """
    Creates a UK.Act struct with the structure given by @fields and default values
  """
  def act,
    do:
      struct(
        __MODULE__,
        Enum.into(@fields, %{}, fn
          :max_amendments -> {:max_amendments, 0}
          :max_modifications -> {:max_modifications, 0}
          :max_commencements -> {:max_commencements, 0}
          :max_extents -> {:max_extents, 0}
          :max_editorials -> {:max_editorials, 0}
          :table_counter -> {:table_counter, 0}
          :figure_counter -> {:figure_counter, 0}
          :changes -> {:changes, []}
          k -> {k, ""}
        end)
      )

  def fields, do: @fields
  def number_fields, do: @number_fields

  def act?(type_code) when type_code in ["ukpga", "asp", "asc", "anaw", "nia", "apni", "ukla"],
    do: true

  def act?(_), do: false
end
