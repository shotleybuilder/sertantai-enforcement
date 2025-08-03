End the current development session by:

1. Check `.claude/sessions/.current-session` for the active session
2. If no active session, inform user there's nothing to end
3. Empty the `.claude/sessions/.current-session` file (don't remove it, just clear its contents)
4. Inform user the session has been documented
