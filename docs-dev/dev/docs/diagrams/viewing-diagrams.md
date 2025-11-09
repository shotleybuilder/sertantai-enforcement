# Best Options for Viewing Diagrams

  1. GitHub (Recommended - Easiest)

  Push to GitHub and view the .md files there. GitHub has native Mermaid support:

  git add docs-dev/dev/*/diagrams/*.md
  git commit -m "Add Ash architecture diagrams"
  git push

  Then browse to any diagram file on GitHub - the Mermaid code blocks render automatically.

  2. Mermaid Live Editor (Best for Quick Viewing)

  Copy and paste the Mermaid code into the online editor:

  1. Open one of your diagram files (e.g., docs-dev/dev/enforcement/diagrams/enforcement-entity-relationship.md)
  2. Copy the Mermaid code (everything between the triple backticks)
  3. Go to https://mermaid.live/
  4. Paste and see instant rendering

  3. Browser Extension

  Install a Markdown viewer extension:
  - Chrome/Edge: "Markdown Viewer" or "Markdown Preview Plus"
  - Firefox: "Markdown Viewer Webext"

  Then open the .md files directly in your browser.

  4. Generate PNG/SVG Images

  Generate visual images you can open in any image viewer:

  # This will create .png files alongside the .md files
  mix diagrams.generate --format png

  Then open the PNG files with any image viewer. Note: This requires either:
  - mmdc CLI (via npm install -g @mermaid-js/mermaid-cli)
  - Or uses Mermaid.ink online service (already configured)

  5. Zed IDE Markdown Preview

  Check if Zed has built-in markdown preview:
  - Press Cmd+Shift+P (Mac) or Ctrl+Shift+P (Linux/Windows)
  - Search for "markdown preview"

  If Zed doesn't have native Mermaid support, it might just show the raw code.

  Quick Test

  Let me show you one of your diagrams:

● Read(docs-dev/dev/docs/diagrams/application-architecture.md)
  ⎿  Read 66 lines

● My Recommendation for Zed IDE

  Since Zed may not have built-in Mermaid preview, here's what I suggest:

  Option 1: Generate PNGs (Easiest for Local Viewing)

  mix diagrams.generate --format png

  This creates PNG images in the same directories as the markdown files. Then just open them with your system image viewer or drag them into Zed.

  Option 2: Use Mermaid Live Editor (Best for Interactive Viewing)

  1. Open docs-dev/dev/docs/diagrams/application-architecture.md in Zed
  2. Copy lines 3-59 (the entire Mermaid code block)
  3. Go to https://mermaid.live/
  4. Paste it in - you'll see a beautiful rendered diagram
  5. You can zoom, pan, and even edit the diagram interactively

  Option 3: Push to GitHub (Best for Team Sharing)

  Your diagrams will render beautifully on GitHub automatically - perfect for PRs and documentation.

  What Your Architecture Shows

  Looking at your application architecture diagram, it shows:
  - 5 Domains: Enforcement (7 resources), Accounts (3 resources), Events (1 resource), Configuration (1 resource), Scraping (4 resources)
  - 16 Total Resources across your application
  - Data Layers: Most use PostgreSQL (AshPostgres), one uses in-memory (Simple)
  - Domain Boundaries: Clear separation between concerns

  This is a great high-level overview for onboarding and planning!

  Would you like me to generate the PNG versions now so you can view them immediately?
