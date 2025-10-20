defmodule Mix.Tasks.Diagrams.Generate do
  @moduledoc """
  Generate Ash diagrams for the EHS Enforcement application.

  ## Usage

      mix diagrams.generate                        # Generate all diagrams
      mix diagrams.generate --domain enforcement   # Single domain
      mix diagrams.generate --format mermaid       # Mermaid markdown only
      mix diagrams.generate --format png           # PNG images
      mix diagrams.generate --format svg           # SVG images

  ## Examples

      # Generate all diagrams in Mermaid markdown format
      mix diagrams.generate

      # Generate diagrams for enforcement domain only
      mix diagrams.generate --domain enforcement

      # Generate PNG images (requires mmdc installed or uses Mermaid.ink)
      mix diagrams.generate --format png

  ## Diagram Types

  This task generates the following diagram types:
  - **Entity Relationship**: Shows relationships between resources
  - **Class Diagrams**: Shows resource structure with attributes and actions
  - **Architecture Diagrams**: C4 architecture overview of the application

  ## Output Locations

  - Application-wide diagrams: `docs-dev/dev/docs/diagrams/`
  - Domain-specific diagrams: `docs-dev/dev/{domain}/diagrams/`
  """

  use Mix.Task

  @shortdoc "Generate Ash Framework diagrams"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")

    {opts, _, _} =
      OptionParser.parse(args,
        switches: [domain: :string, format: :string],
        aliases: [d: :domain, f: :format]
      )

    format = opts[:format] || "mermaid"
    domain = opts[:domain]

    case domain do
      nil -> generate_all_diagrams(format)
      domain_name -> generate_domain_diagrams(domain_name, format)
    end

    Mix.shell().info("\n✓ Diagram generation complete!")
  end

  defp generate_all_diagrams(format) do
    Mix.shell().info("Generating diagrams for all domains...")

    domains = [
      EhsEnforcement.Enforcement,
      EhsEnforcement.Scraping,
      EhsEnforcement.Accounts,
      EhsEnforcement.Configuration,
      EhsEnforcement.Events
    ]

    Enum.each(domains, &generate_domain_diagrams(&1, format))
    generate_application_diagrams(format)
  end

  defp generate_domain_diagrams(domain, format) when is_atom(domain) do
    domain_name = domain |> Module.split() |> List.last()
    Mix.shell().info("\nGenerating diagrams for #{domain_name} domain...")

    # Generate ER diagram
    er_diagram = AshDiagram.Data.EntityRelationship.for_domains([domain])
    save_diagram(er_diagram, domain, "entity-relationship", format)

    # Generate class diagram
    class_diagram = AshDiagram.Data.Class.for_domains([domain])
    save_diagram(class_diagram, domain, "class", format)
  end

  defp generate_domain_diagrams(domain_name, format) when is_binary(domain_name) do
    # Map string domain names to actual domain modules
    domain_module =
      case String.downcase(domain_name) do
        "enforcement" -> EhsEnforcement.Enforcement
        "scraping" -> EhsEnforcement.Scraping
        "accounts" -> EhsEnforcement.Accounts
        "configuration" -> EhsEnforcement.Configuration
        "events" -> EhsEnforcement.Events
        _ -> raise "Unknown domain: #{domain_name}"
      end

    generate_domain_diagrams(domain_module, format)
  end

  defp generate_application_diagrams(format) do
    Mix.shell().info("\nGenerating application-wide diagrams...")

    # Generate application-wide architecture
    arch_diagram = AshDiagram.Data.Architecture.for_applications([:ehs_enforcement])
    save_diagram(arch_diagram, "application", "architecture", format)

    # Generate full ER diagram
    er_diagram = AshDiagram.Data.EntityRelationship.for_applications([:ehs_enforcement])
    save_diagram(er_diagram, "application", "entity-relationship", format)
  end

  defp save_diagram(diagram, domain, type, format) do
    output_dir = diagram_output_dir(domain)
    File.mkdir_p!(output_dir)

    base_filename = "#{domain_slug(domain)}-#{type}"
    filename = Path.join(output_dir, "#{base_filename}.md")

    # Convert diagram struct to Mermaid string using AshDiagram.compose/1
    mermaid_string = diagram |> AshDiagram.compose() |> IO.iodata_to_binary()

    case format do
      "mermaid" ->
        mermaid_content = build_mermaid_content(domain, type, mermaid_string)
        File.write!(filename, mermaid_content)
        Mix.shell().info("  ✓ Generated: #{filename}")

      "png" ->
        png_data = AshDiagram.render(diagram, format: :png)
        png_file = Path.join(output_dir, "#{base_filename}.png")
        File.write!(png_file, png_data)

        # Also create the markdown file with embedded image
        mermaid_content = build_mermaid_content(domain, type, mermaid_string)
        File.write!(filename, mermaid_content)
        Mix.shell().info("  ✓ Generated: #{png_file}")
        Mix.shell().info("  ✓ Generated: #{filename}")

      "svg" ->
        svg_data = AshDiagram.render(diagram, format: :svg)
        svg_file = Path.join(output_dir, "#{base_filename}.svg")
        File.write!(svg_file, svg_data)

        # Also create the markdown file
        mermaid_content = build_mermaid_content(domain, type, mermaid_string)
        File.write!(filename, mermaid_content)
        Mix.shell().info("  ✓ Generated: #{svg_file}")
        Mix.shell().info("  ✓ Generated: #{filename}")
    end
  end

  defp build_mermaid_content(domain, type, mermaid_string) do
    """
    # #{domain_name(domain)} - #{type |> String.replace("-", " ") |> String.capitalize()}

    ```mermaid
    #{mermaid_string}
    ```

    ---

    **Generated**: #{DateTime.utc_now() |> DateTime.to_string()}

    **Regenerate**: `mix diagrams.generate --domain #{domain_slug(domain)}`
    """
  end

  defp diagram_output_dir(domain) when is_atom(domain) do
    domain_slug = domain_slug(domain)
    "docs-dev/dev/#{domain_slug}/diagrams"
  end

  defp diagram_output_dir("application") do
    "docs-dev/dev/docs/diagrams"
  end

  defp domain_slug(domain) when is_atom(domain) do
    domain
    |> Module.split()
    |> List.last()
    |> Macro.underscore()
  end

  defp domain_slug(domain) when is_binary(domain), do: domain

  defp domain_name(domain) when is_atom(domain) do
    domain |> Module.split() |> List.last()
  end

  defp domain_name(domain) when is_binary(domain) do
    domain |> String.capitalize()
  end
end
