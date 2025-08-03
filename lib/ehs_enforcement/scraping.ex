defmodule EhsEnforcement.Scraping do
  @moduledoc """
  The Scraping domain for managing HSE scraping operations.
  """

  use Ash.Domain,
    extensions: [AshPhoenix]

  resources do
    resource EhsEnforcement.Scraping.ScrapeRequest
    resource EhsEnforcement.Scraping.ScrapeSession
    resource EhsEnforcement.Scraping.CaseProcessingLog
    resource EhsEnforcement.Scraping.ScrapedCase
  end
end