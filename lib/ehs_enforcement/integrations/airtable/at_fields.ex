defmodule EhsEnforcement.Integrations.Airtable.AtFields do
  @doc """

  """
  @law_at_fields ~s/
    'Separate Base?'
    'Count (Articles)'
    Region
    Year
    Number
    Title_EN
    Type
    Class
    leg.gov.uk
    'SI Code'
    Regulator
    'Parent to'
    'Child of'
    Tags
  /

  @article_at_fields ~s/
    UK
    Dutyholder
    'Requ Type'
    'Article Type'
    text_EN
  /

  def law_at_fields_as_list, do: Enum.map(String.split(@law_at_fields), fn x -> x end)

  def article_at_fields_as_list, do: Enum.map(String.split(@article_at_fields), fn x -> x end)

  ["record_id.md", "do_not_display.md", "touched.md", "urls.md"]

  def at_fields(%{table_name: "Article"}) do
    ["faq.md", "answer.md", "off_sch.md" | article_at_fields_as_list()]
  end

  def at_fields(%{table_name: "UK"}) do
    ["faq.md", "answer.md", "on_sch.md" | law_at_fields_as_list()]
  end
end
