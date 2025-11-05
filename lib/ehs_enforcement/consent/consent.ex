defmodule EhsEnforcement.Consent do
  @moduledoc """
  The Consent domain for managing GDPR-compliant cookie consent.

  This domain handles consent settings for users, tracking their cookie
  preferences and consent history.
  """

  use Ash.Domain

  resources do
    resource EhsEnforcement.Consent.ConsentSettings do
      define(:list_consent_settings, action: :read)
      define(:get_consent_settings, action: :read, get_by: [:id])
      define(:create_consent_settings, action: :create)
      define(:update_consent_settings, action: :update)
      define(:destroy_consent_settings, action: :destroy)
      define(:grant_consent, action: :grant_consent)
      define(:revoke_consent, action: :revoke_consent)
      define(:active_consents, action: :active_consents)
    end
  end
end
