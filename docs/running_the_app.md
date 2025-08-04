  # Start iex with mix
  iex -S mix

  # Check available functions in Notices module
  EhsEnforcement.Agencies.Hse.Notices.__info__(:functions)

  # Test HSE Notices API - Option 1: Let it prompt for page numbers
  EhsEnforcement.Agencies.Hse.Notices.api_get_hse_notices([])

  # Test HSE Notices API - Option 2: Provide specific pages
  EhsEnforcement.Agencies.Hse.Notices.api_get_hse_notices([pages: "1", country: "England"])

  # Test HSE Notices API - Option 3: Provide a range of pages
  EhsEnforcement.Agencies.Hse.Notices.api_get_hse_notices([pages: "1..3", country: "England"])

  # Check available functions in Cases module
  EhsEnforcement.Agencies.Hse.Cases.__info__(:functions)

  # Test HSE Cases API - Option 1: Let it prompt for page numbers
  EhsEnforcement.Agencies.Hse.Cases.api_get_hse_cases()

  # Test HSE Cases API - Option 2: Provide specific pages
  EhsEnforcement.Agencies.Hse.Cases.api_get_hse_cases([pages: "1", country: "England"])

  # Test HSE Cases by ID - It will prompt for the case ID
  EhsEnforcement.Agencies.Hse.Cases.api_get_hse_case_by_id()

  # Test HSE Cases by ID - With options
  EhsEnforcement.Agencies.Hse.Cases.api_get_hse_case_by_id([database: "convictions"])

  Notes:

  1. Database Errors: You'll see Postgrex errors about the database not existing - this is expected since we haven't set up PostgreSQL yet. The scrapers will still work.
  2. Interactive Prompts: The functions use ExPrompt to ask for page numbers if not provided in options.
  3. Airtable Posts: The functions will attempt to post results to Airtable. Make sure you have the AIRTABLE_API_KEY environment variable set if you want this to work.
  4. Page Numbers:
    - Single page: "1"
    - Multiple pages: "1,2,3"
    - Range: "1..5"
  5. Country Options: Default is "England", but you can specify others in the options.

  The functions should scrape data from the HSE website and attempt to post it to Airtable. You'll see debug output showing the URLs being accessed and the results being processed.
