Start a new development session by creating a session file in `.claude/sessions/` with the filename format `YYYY-MM-DD-$ARGUMENTS.md` (or just `YYYY-MM-DD.md` if no session name provided).  Use system date.

The session file should begin with:
1. Session name as the title
2. Filename of the session file
3. Session overview section with start time
4. Goals section (ask user for goals if not clear)
5. Empty progress section ready for updates

After creating the file, create or update `.claude/sessions/.current-session` to track the active session filename.

Confirm the session has started and remind the user they can:
- Update it with `/project:session-update`
- End it with `/project:session-end`

- READ CLAUDE.md
This is an Elixir Ash project.
**Strictly follow Ash conventions and patterns.**
