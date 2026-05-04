Perform a Go code review for the GitLab MR at: $ARGUMENTS
Then post the findings as inline GitLab comments.

## Step 1 — Fetch MR data

Run:
```
~/.claude/scripts/gitlab-review "$ARGUMENTS"
```

## Step 2 — Review the code

Use the Go architecture rules from your global CLAUDE.md as the reference standard.

**Do NOT report:** empty lines, whitespace/indentation, extra spaces, formatting issues that `gofmt` would fix automatically.

### Architecture Compliance
Check that the code follows: `handlers/ → usecases/ → service → repository`

Violations to flag:
- Business logic inside HTTP handlers
- DB queries outside repository layer
- Handler calling repository directly
- Cross-domain dependencies

### Go Best Practices
- Error handling: every error must be handled or explicitly ignored with a comment
- `context.Context` must be first argument and propagated
- Goroutines must have a clear owner and shutdown path via context
- Interface usage: accept interfaces, return concrete types

### Error Handling Convention
- User-facing errors: use `gokittypes.NewBadRequest` / `gokittypes.NewNotFound`
- Plain `fmt.Errorf` → results in HTTP 500
- `gorm.ErrRecordNotFound` must map to 404, not 500

### Security
- No sensitive data in logs
- SQL only via GORM (no raw string concatenation)
- Input validation before processing

## Step 3 — Post findings as inline comments

Build a JSON array of findings. Only include items you can pin to a specific file and line number in the diff. Skip general/summary observations.

```json
{
  "findings": [
    {
      "file": "internal/api/handlers/barge.go",
      "line": 42,
      "line_type": "new",
      "severity": "critical",
      "body": "Error from `repo.Find()` is silently discarded. This will panic or return wrong data if the DB query fails."
    }
  ]
}
```

- `line_type`: `"new"` for added lines, `"old"` for removed lines (use `"new"` when unsure)
- `severity`: `"critical"`, `"warning"`, or `"suggestion"`
- `body`: clear explanation with correct Go code example when applicable

Then run:
```
echo '<JSON>' | ~/.claude/scripts/gitlab-review post "$ARGUMENTS"
```

Report how many comments were posted successfully.
