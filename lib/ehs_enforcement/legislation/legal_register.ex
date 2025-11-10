defmodule EhsEnforcement.Legislation.LegalRegister do
  # A struct to represent a Legal Register record

  @type legal_register :: %__MODULE__{
          Acronym: String.t(),
          Name: String.t(),

          # id fields
          record_id: String.t(),
          Title_EN: String.t(),
          type_code: String.t(),
          Number: String.t(),
          old_style_number: String.t(),
          Year: String.t(),

          # search fields
          Tags: list(),
          md_description: String.t(),

          # extent fields
          Geo_Extent: String.t(),
          Geo_Region: String.t(),
          Geo_Pan_Region: String.t(),

          # application fields
          Live?: String.t(),
          "Live?_description": String.t(),

          # Type fields
          Type: String.t(),
          type_class: String.t(),
          # Family fields
          Family: String.t(),
          family_ii: String.t(),
          SICode: String.t(),
          si_code: String.t(),

          # Metadata fields
          md_total_paras: integer(),
          md_body_paras: integer(),
          md_schedule_paras: integer(),
          md_images: integer(),
          md_date: String.t(),
          md_date_year: integer(),
          md_date_month: integer(),
          md_dct_valid_date: String.t(),
          md_restrict_start_date: String.t(),
          md_restrict_extent: String.t(),
          md_made_date: String.t(),
          md_enactment_date: String.t(),
          md_coming_into_force_date: String.t(),
          md_attachment_paras: integer(),
          md_modified: String.t(),
          md_subjects: list(),
          md_checked: String.t(),

          # EcARM
          Function: list(),
          Amending: String.t(),
          Enacting: String.t(),
          Revoking: String.t(),
          Amended_by: String.t(),
          Enacted_by: String.t(),
          Revoked_by: String.t(),
          amendments_checked: String.t(),

          # Enacting fields
          enact_error: String.t(),
          enacted_by_description: String.t(),

          # Amending fields
          "🔺_stats_affects_count": integer(),
          "🔺_stats_self_affects_count": integer(),
          "🔺_stats_affected_laws_count": integer(),
          "🔺_stats_affects_count_per_law": String.t(),
          "🔺_stats_affects_count_per_law_detailed": String.t(),

          # Amended By fields
          "🔻_stats_affected_by_count": integer(),
          "🔻_stats_self_affected_by_count": integer(),
          "🔻_stats_affected_by_laws_count": integer(),
          "🔻_stats_affected_by_count_per_law": String.t(),
          "🔻_stats_affected_by_count_per_law_detailed": String.t(),

          # Live? Re[voke|peal] fields
          "🔺_stats_revoking_laws_count": integer(),
          "🔺_stats_revoking_count_per_law": String.t(),
          "🔺_stats_revoking_count_per_law_detailed": String.t(),
          "🔻_stats_revoked_by_laws_count": integer(),
          "🔻_stats_revoked_by_count_per_law": String.t(),
          "🔻_stats_revoked_by_count_per_law_detailed": String.t(),

          # New law fields
          publication_date: String.t(),

          # Change Logs fields
          "Live?_change_log": String.t(),
          md_change_log: String.t(),
          amended_by_change_log: String.t(),

          # Governed Roles
          actor: list(),
          actor_article: String.t(),
          article_actor: String.t(),

          # Government Roles
          actor_gvt: list(),
          actor_gvt_article: String.t(),
          article_actor_gvt: String.t(),

          # Duties Holder
          duty_holder: list(),
          duty_holder_article: String.t(),
          duty_holder_article_clause: String.t(),
          article_duty_holder: String.t(),
          article_duty_holder_clause: String.t(),

          # Rights Holder
          rights_holder: list(),
          rights_holder_article: String.t(),
          rights_holder_article_clause: String.t(),
          article_rights_holder: String.t(),
          article_rights_holder_clause: String.t(),

          # Responsibilities Holder
          responsibility_holder: list(),
          responsibility_holder_article: String.t(),
          responsibility_holder_article_clause: String.t(),
          article_responsibility_holder: String.t(),
          article_responsibility_holder_clause: String.t(),

          # Powers Holders
          power_holder: list(),
          power_holder_article: String.t(),
          power_holder_article_clause: String.t(),
          article_power_holder: String.t(),
          article_power_holder_clause: String.t(),

          # Duty Type
          duty_type: list(),
          duty_type_article: String.t(),
          article_duty_type: String.t(),

          # POPIMAR
          popimar: list(),
          popimar_article: String.t(),
          article_popimar: String.t()
        }

  @struct ~w[
    Acronym
    Name

    record_id
    Title_EN
    type_code
    Number
    old_style_number
    Year

    Tags
    md_description

    Geo_Extent
    Geo_Region
    Geo_Pan_Region

    Live?
    Live?_description

    Type
    type_class

    Family
    family_ii

    SICode
    si_code

    md_total_paras
    md_body_paras
    md_schedule_paras
    md_images
    md_date
    md_date_month
    md_date_year
    md_dct_valid_date
    md_restrict_start_date
    md_restrict_extent
    md_made_date
    md_enactment_date
    md_coming_into_force_date
    md_attachment_paras
    md_modified
    md_subjects

    md_checked

    Function
    Enacting
    Enacted_by

    Amending
    Amended_by

    Revoking
    Revoked_by

    enact_error
    enacted_by_description

    amendments_checked

    🔺_stats_affects_count
    🔺_stats_self_affects_count
    🔺_stats_affected_laws_count
    🔺_stats_affects_count_per_law
    🔺_stats_affects_count_per_law_detailed

    🔻_stats_affected_by_count
    🔻_stats_self_affected_by_count
    🔻_stats_affected_by_laws_count
    🔻_stats_affected_by_count_per_law
    🔻_stats_affected_by_count_per_law_detailed

    🔺_stats_revoking_laws_count
    🔺_stats_revoking_count_per_law
    🔺_stats_revoking_count_per_law_detailed

    🔻_stats_revoked_by_laws_count
    🔻_stats_revoked_by_count_per_law
    🔻_stats_revoked_by_count_per_law_detailed

    publication_date

    md_change_log
    amending_change_log
    amended_by_change_log
    Live?_change_log

    actor
    actor_article
    article_actor

    actor_gvt
    actor_gvt_article
    article_actor_gvt

    duty_holder
    duty_holder_article
    duty_holder_article_clause
    article_duty_holder
    article_duty_holder_clause

    rights_holder
    rights_holder_article
    rights_holder_article_clause
    article_rights_holder
    article_rights_holder_clause

    responsibility_holder
    responsibility_holder_article
    responsibility_holder_article_clause
    article_responsibility_holder
    article_responsibility_holder_clause

    power_holder
    power_holder_article
    power_holder_article_clause
    article_power_holder
    article_power_holder_clause

    duty_type
    duty_type_article
    article_duty_type

    popimar
    popimar_article
    article_popimar
  ]a

  defstruct @struct

  @translator %{
    Acronym: :acronym,
    Name: :name,
    Title_EN: :title_en,
    Number: :number,
    Year: :year,
    type_code: :type_code,
    Type: :type_desc,
    type_class: :type_class,

    # SEARCH
    Tags: :tags,
    md_description: :md_description,
    md_subjects: :md_subjects,
    Family: :family,
    SICode: :si_code,
    # EXTENT
    Geo_Region: :geo_country,
    Geo_Pan_Region: :geo_region,
    Geo_Extent: :geo_extent,
    # APPLICATION
    "Live?_description": :live_description,
    Live?: :live,
    # METADATA
    md_body_paras: :md_body_paras,
    md_restrict_start_date: :md_restrict_start_date,
    md_total_paras: :md_total_paras,
    md_images: :md_images,
    md_date: :md_date,
    md_date_month: :md_date_month,
    md_date_year: :md_date_year,
    md_dct_valid_date: :md_dct_valid_date,
    md_attachment_paras: :md_attachment_paras,
    md_modified: :md_modified,
    md_schedule_paras: :md_schedule_paras,
    md_enactment_date: :md_enactment_date,
    md_made_date: :md_made_date,
    md_coming_into_force_date: :md_coming_into_force_date,
    md_restrict_extent: :md_restrict_extent,
    # ECARM
    Function: :function,
    Enacting: :enacting,
    Enacted_by: :enacted_by,
    enacted_by_description: :enacted_by_description,
    Amending: :amending,
    Amended_by: :amended_by,
    Revoking: :rescinding,
    Revoked_by: :rescinded_by,
    # Affecting
    "🔺_stats_affected_laws_count": :"△_#_laws_amd_by_law",
    "🔺_stats_self_affects_count": :"△_#_self_amd_by_law",
    "🔺_stats_affects_count": :"△_#_amd_by_law",
    "🔺_stats_affects_count_per_law": :"△_amd_short_desc",
    "🔺_stats_affects_count_per_law_detailed": :"△_amd_long_desc",
    # Affected By
    "🔻_stats_affected_by_laws_count": :"▽_#_laws_amd_law",
    "🔻_stats_self_affected_by_count": :"▽_#_self_amd_of_law",
    "🔻_stats_affected_by_count": :"▽_#_amd_of_law",
    "🔻_stats_affected_by_count_per_law": :"▽_amd_short_desc",
    "🔻_stats_affected_by_count_per_law_detailed": :"▽_amd_long_desc",
    # Revoking
    "🔺_stats_revoking_laws_count": :"△_#_laws_rsc_law",
    "🔺_stats_revoking_count_per_law": :"△_rsc_short_desc",
    "🔺_stats_revoking_count_per_law_detailed": :"△_rsc_long_desc",
    # Revoked By
    "🔻_stats_revoked_by_count_per_law": :"▽_rsc_short_desc",
    "🔻_stats_revoked_by_laws_count": :"▽_#_laws_rsc_law",
    "🔻_stats_revoked_by_count_per_law_detailed": :"▽_rsc_long_desc",
    # CHANGE
    "Live?_change_log": :rsc_change_log,
    md_change_log: :md_change_log,
    amended_by_change_log: :amd_by_change_log,
    amending_change_log: :amd_change_log,
    # ROLES
    actor: :role,
    actor_article: :role_article,
    actor_gvt: :role_gvt,
    actor_gvt_article: :role_gvt_article,
    responsibility_holder: :responsibility_holder,
    article_power_holder_clause: :article_power_holder_clause,
    responsibility_holder_article_clause: :responsibility_holder_article_clause,
    power_holder_article: :power_holder_article,
    power_holder: :power_holder,
    power_holder_article_clause: :power_holder_article_clause,
    responsibility_holder_article: :responsibility_holder_article,
    article_power_holder: :article_power_holder,
    article_responsibility_holder_clause: :article_responsibility_holder_clause,
    article_responsibility_holder: :article_responsibility_holder,
    duty_holder: :duty_holder,
    article_duty_holder_clause: :article_duty_holder_clause,
    rights_holder_article_clause: :rights_holder_article_clause,
    article_dutyholder: :article_dutyholder,
    rights_holder_article: :rights_holder_article,
    article_rights_holder: :article_rights_holder,
    article_rights_holder_clause: :article_rights_holder_clause,
    rights_holder: :rights_holder,
    duty_holder_article_clause: :duty_holder_article_clause,
    duty_holder_article: :duty_holder_article,
    duty_type: :purpose,
    duty_type_article: :purpose_article,
    article_duty_type: :article_purpose,
    popimar: :popimar,
    popimar_article: :popimar_article,
    article_popimar: :article_popimar,
    popimar_article_clause: :popimar_article_clause,
    article_popimar_clause: :article_popimar_clause,
    article_actor: :article_role,
    article_actor_gvt: :article_role_gvt
  }

  def supabase_conversion(record) when is_struct(record) do
    supabase_conversion(Map.from_struct(record))
  end

  def supabase_conversion(record) when is_map(record) do
    Enum.map(record, fn {k, v} -> {translate(k), v} end) |> Enum.into(%{})
  end

  def supabase_conversion(record) do
    raise ArgumentError, "Expected a map or struct, got: #{inspect(record)}"
  end

  defp translate(key) do
    case Map.get(@translator, key) do
      nil -> key
      value -> value
    end
  end
end
