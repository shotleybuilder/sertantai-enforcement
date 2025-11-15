Create a GitHub Issue using `gh` CLI.

---
**LABEL LIST LAST UPDATED**: 2025-11-15
**Repository**: TBD (update when GitHub repo is configured)

**CURRENT LABELS**:
- `bug` - Something isn't working
- `documentation` - Improvements or additions to documentation
- `duplicate` - This issue or pull request already exists
- `enhancement` - New feature or request
- `good first issue` - Good for newcomers
- `help wanted` - Extra attention is needed
- `invalid` - This doesn't seem right
- `question` - Further information is requested
- `wontfix` - This will not be worked on
- `migration` - Related to local-first migration work
- `template-adoption` - Adopting patterns from template

---

## Instructions

### 1. Check Label Freshness

**IMPORTANT**: Before creating the issue, check if the label list above is stale:

```bash
# Calculate days since last update (2025-11-15)
# If >30 days old, REFRESH LABELS FIRST
```

**If labels are stale (>30 days old)**:
1. Fetch fresh labels:
   ```bash
   gh label list --limit 100 --json name,description,color
   ```
2. Update this command file (`.claude/commands/github-create-issue.md`) with:
   - New timestamp (today's date in YYYY-MM-DD format)
   - Updated label list

### 2. Gather Issue Information

Ask user for (or extract from context):
- **Title**: Clear, concise issue title
- **Body**: Issue description with context
- **Labels**: Select from CURRENT LABELS list above (avoid typos!)
- **Assignee**: (optional) GitHub username
- **Milestone**: (optional) Milestone name
- **Project**: (optional) Project name

### 3. Create the Issue

Use `gh issue create` with interactive or command-line mode:

**Interactive mode** (recommended):
```bash
gh issue create
# Follow prompts, paste description, select labels from list above
```

**Command-line mode** (faster):
```bash
gh issue create \
  --title "Issue title here" \
  --body "Issue description here" \
  --label "bug,enhancement" \
  --assignee @me
```

### 4. Verify Labels

**CRITICAL**: Before submitting, verify all labels exist in the CURRENT LABELS list above to avoid errors.

Common mistakes:
- ❌ `bugfix` (should be `bug`)
- ❌ `feature` (should be `enhancement`)
- ❌ `docs` (should be `documentation`)

### 5. Link to Session (if applicable)

If working in a session:
- The session will reference this new Issue #
- Use `/session-start` to begin tracking work on the Issue
- Remember: Session = lightweight tracker, Issue = detailed docs

### Example

```bash
# Create issue for local-first migration work
gh issue create \
  --title "Set up ElectricSQL sync service" \
  --body "Configure ElectricSQL for PostgreSQL logical replication sync.

## Requirements
- Add Electric to docker-compose
- Enable PostgreSQL logical replication
- Configure sync permissions
- Test basic shape streaming

## Acceptance Criteria
- [ ] Electric service running in docker-compose
- [ ] PostgreSQL configured for logical replication
- [ ] Basic shape stream working
- [ ] Documentation updated" \
  --label "enhancement,migration" \
  --assignee @me

# Output will show Issue # - use this to start a session
# /session-start
# (Claude will ask for the Issue # from above)
```

### Tips

- Use clear, actionable titles
- Include context and acceptance criteria in body
- Use markdown formatting (GitHub supports it)
- Attach labels that match the work type
- Assign to yourself if you'll work on it
- Reference related issues with `#123`

### Common Labels Usage

- `bug` - Something is broken, needs fixing
- `enhancement` - New feature or improvement
- `documentation` - README, docs, or code comments
- `question` - Need clarification or discussion
- `migration` - Work related to local-first architecture migration
- `template-adoption` - Adopting patterns from the template project
- `good first issue` - Simple task for new contributors
- `help wanted` - Stuck and need assistance

---

**Remember**: This command file contains a timestamped label list. If you get label errors, the list is probably stale - refresh it!
