# Profile: Code review

## Must flag

- Missing `user_id` ownership filters
- SQL string concatenation
- Secrets or `.env` in the diff
- Blocking I/O in async handlers
- Try-on / AI calls bypassing Settings spend or provider abstraction
- Claims of commercial IDM-VTON use without license note
- Emoji in UI/logs
- Undocumented new env vars

## Suggest

- Tests for new branches
- Docs updates for API/ops changes
- Clearer error surfaces for Flutter

## Approve when

Checklists in [../rules/CODING-RULES-HANDBOOK.md](../rules/CODING-RULES-HANDBOOK.md) are satisfied for the change type.
