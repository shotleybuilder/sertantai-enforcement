---
name: writing-skills-md
description: Creates effective SKILLS.md files following Anthropic's official Agent Skills format. Use when documenting reusable patterns, creating skill documentation, or when users request creation of a SKILLS.md file. Ensures proper YAML frontmatter, concise instructional content, and progressive disclosure principles.
---

# Writing Effective SKILLS.md Files

This skill teaches how to create SKILLS.md files that follow Anthropic's official guidelines for Claude Code Agent Skills.

## What is a SKILLS.md File?

A SKILLS.md file teaches future Claude agents how to perform specific tasks. Think of it as an instructional manual, not a project tracker or history log.

**Purpose:**
- Teach repeatable patterns and workflows
- Provide working code examples
- Enable skills to be copied to other projects
- Help agents quickly understand "how to do X"

**Not for:**
- Project-specific documentation
- Implementation history or changelogs
- Task tracking or checkboxes
- Feature lists or roadmaps

## Required Structure

### 1. YAML Frontmatter

Every SKILLS.md must start with YAML frontmatter:

```yaml
---
name: skill-name-here
description: What the skill does and when to use it. Maximum 1024 characters.
---
```

**Name Requirements:**
- Maximum 64 characters
- Lowercase letters, numbers, hyphens only
- Use gerund form (verb + -ing): `processing-pdfs`, `analyzing-data`
- Cannot contain "anthropic", "claude", or XML tags

**Description Requirements:**
- Maximum 1024 characters
- Write in third person
- Specify BOTH what it does AND when to use it
- Cannot contain XML tags

**Good Example:**
```yaml
---
name: tanstack-table-svelte-advanced
description: Implements advanced TanStack Table v8 features in Svelte including column filtering, resizing, visibility, sorting, and pagination with localStorage persistence. Use when working with TanStack Table in Svelte or when users request table customization features.
---
```

**Bad Examples:**
```yaml
# Too vague
description: Helps with tables

# Missing "when to use"
description: Implements TanStack Table features

# Contains reserved words
name: claude-helper
```

### 2. Instructional Content

Write content that teaches, not documents.

**Key Principle:** Assume Claude's existing knowledge. Challenge each piece of information: "Does Claude really need this explanation?"

**Good - Concise and actionable:**
```markdown
## Extract PDF Text

Use pdfplumber for text extraction:

```python
import pdfplumber

with pdfplumber.open("file.pdf") as pdf:
    text = pdf.pages[0].extract_text()
```
```

**Bad - Verbose and obvious:**
```markdown
## What is a PDF?

PDFs are Portable Document Format files created by Adobe...

## Why Extract Text?

Sometimes you need to get text from PDFs because...

## Installing pdfplumber

First, you need to understand package managers...
```

## Content Organization

### Keep SKILLS.md Under 500 Lines

Use progressive disclosure to organize content hierarchically:

```
skill-directory/
├── SKILLS.md          # Overview and navigation (< 500 lines)
├── REFERENCE.md       # Detailed API docs
├── EXAMPLES.md        # Advanced examples
└── scripts/           # Helper scripts
```

**In SKILLS.md:**
```markdown
## Basic Usage

Quick example here...

**For advanced patterns:** See [EXAMPLES.md](EXAMPLES.md)
**For full API reference:** See [REFERENCE.md](REFERENCE.md)
```

**Important:** Keep references one level deep. Claude may only partially read nested file references.

### Add Table of Contents for Long Files

For files over 100 lines, add a table of contents:

```markdown
# Table of Contents

- [Installation](#installation)
- [Basic Setup](#basic-setup)
- [Advanced Features](#advanced-features)
- [Troubleshooting](#troubleshooting)
```

## Writing Style

### Degrees of Freedom Approach

Choose the right level of specificity for each task:

**High Freedom - Text Instructions**

Use when multiple approaches work:

```markdown
## Handle API Errors

Implement error handling that:
- Catches network failures
- Retries with exponential backoff
- Logs errors for debugging
- Returns user-friendly messages
```

**Medium Freedom - Pseudocode with Parameters**

Use when preferred patterns exist:

```markdown
## Retry Failed Requests

```python
def retry_request(url, max_retries=3):
    for attempt in range(max_retries):
        try:
            return requests.get(url, timeout=5)
        except RequestException:
            if attempt == max_retries - 1:
                raise
            time.sleep(2 ** attempt)
```
```

**Low Freedom - Exact Commands**

Use for fragile operations requiring exact sequence:

```markdown
## Deploy to Production

Run these commands in order:

```bash
npm run build
npm test
git tag v1.0.0
git push origin v1.0.0
./deploy.sh production
```
```

### Be Concise

Every token in SKILLS.md competes with conversation history and other context.

**Target:** ~50 tokens for effective examples vs 150+ for verbose explanations

**Good - 47 tokens:**
```markdown
## Filter DataFrame Rows

```python
df_filtered = df[df['age'] > 18]
df_filtered = df.query('age > 18 and city == "NYC"')
```
```

**Bad - 156 tokens:**
```markdown
## Filtering Rows in Pandas DataFrames

Pandas is a powerful data manipulation library in Python. One of the most common operations is filtering rows based on conditions. There are several ways to accomplish this...

First, you can use boolean indexing. This creates a mask...

The query method is another approach. It uses a string expression...
```

## Common Patterns

### Prerequisites Section

Keep it minimal:

```markdown
## Prerequisites

Install required package:

```bash
npm install @tanstack/svelte-table
```

Import from `@tanstack/svelte-table` and `svelte/store`.
```

Don't explain what npm is or how imports work.

### Code Examples

Provide working code without excessive explanation:

```markdown
## Create Table Instance

```typescript
import { writable } from 'svelte/store'
import { createSvelteTable, getCoreRowModel } from '@tanstack/svelte-table'

const options = writable({
  data: $data,
  columns,
  getCoreRowModel: getCoreRowModel()
})

const table = createSvelteTable(options)
```

Access table state with `$table` in templates.
```

### Troubleshooting Section

Include common errors and solutions:

```markdown
## Troubleshooting

**"Module not found" error:**
- Verify package is installed: `npm list package-name`
- Check import path matches package exports

**Function returns undefined:**
- Ensure async functions are awaited
- Check function is called after data loads
```

## What NOT to Include

### ❌ Project-Specific Tracking

**Wrong:**
```markdown
## Implementation Status

✅ Column filtering - Implemented in RecentActivityTable.svelte
✅ Column resizing - Implemented Nov 19, 2025
⬜ Column reordering - TODO for next sprint

See `frontend/src/lib/components/RecentActivityTable.svelte` for implementation.
```

**Right:**
```markdown
## Column Filtering

Implement column filtering with localStorage persistence:

```typescript
// Code example here
```
```

### ❌ Verbose Explanations

**Wrong:**
```markdown
## Understanding State Management

Before we dive into implementation, it's important to understand what state management is and why it matters. State represents data that changes over time...
```

**Right:**
```markdown
## State Management

Use Svelte stores for reactive state:

```typescript
let state = writable(initialValue)
```
```

### ❌ Historical Information

**Wrong:**
```markdown
## Changes in Version 2.0

We previously used react-dnd but switched to @dnd-kit/core in version 2.0 because of React 18 compatibility issues...
```

**Right:**
```markdown
## Column Reordering

Use `@dnd-kit/core` (modern, lightweight):

```bash
npm install @dnd-kit/core @dnd-kit/sortable
```

Note: Avoid react-dnd due to React 18 compatibility issues.
```

## Complete Example

Here's a well-structured SKILLS.md:

```markdown
---
name: pdf-text-extraction
description: Extracts text and tables from PDF files using pdfplumber. Use when processing PDF documents, extracting data from forms, or parsing PDF reports.
---

# PDF Text Extraction

Extract text and tables from PDF files using pdfplumber.

## Prerequisites

```bash
pip install pdfplumber
```

## Extract Text

```python
import pdfplumber

with pdfplumber.open("document.pdf") as pdf:
    # Extract from single page
    text = pdf.pages[0].extract_text()

    # Extract from all pages
    full_text = "\n".join(page.extract_text() for page in pdf.pages)
```

## Extract Tables

```python
with pdfplumber.open("document.pdf") as pdf:
    tables = pdf.pages[0].extract_tables()

    for table in tables:
        for row in table:
            print(row)
```

## Handle Encrypted PDFs

```python
with pdfplumber.open("encrypted.pdf", password="secret") as pdf:
    text = pdf.pages[0].extract_text()
```

## Troubleshooting

**Empty text extracted:**
- PDF may contain images instead of text
- Use OCR tool like pytesseract for image-based PDFs

**Unicode errors:**
- Specify encoding: `text.encode('utf-8', errors='ignore')`

## Advanced Options

For custom extraction settings, see [pdfplumber documentation](https://github.com/jsvine/pdfplumber).
```

## Best Practices Summary

1. **Required YAML frontmatter** - name (max 64 chars) and description (max 1024 chars)
2. **Concise is key** - ~50 tokens per example, assume Claude's knowledge
3. **Working code** - Provide examples that can be copied directly
4. **Progressive disclosure** - Keep main file under 500 lines, link to detailed docs
5. **Instructional format** - Teach how to do things, not what was done
6. **No project tracking** - No checkboxes, feature lists, or implementation history
7. **Troubleshooting section** - Include common errors and solutions
8. **Degrees of freedom** - Match specificity to task requirements

## Testing Your SKILLS.md

Ask yourself:

- Can I remove this explanation without losing actionable information?
- Would Claude already know this from its training data?
- Is this teaching a repeatable pattern or documenting project history?
- Could someone copy this to another project and follow it?
- Is the code example working and complete?

If you answer "no" to questions 1-2 or "yes" to question 3, revise the content.
