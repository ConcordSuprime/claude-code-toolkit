Review code by V.Korobov (Vladislav) for recurring patterns from past reviews.

First, run this shell command to fetch MR data:
```
~/.claude/scripts/gitlab-review "$ARGUMENTS"
```

Then review using the standard Go review instructions, **plus** the additional checks below that specifically target patterns flagged in his previous MRs.

---

## Standard review

Apply all checks from `/mr-review` (architecture, error handling, Go best practices, libraries, security, observability).

---

## Additional checks — V.Korobov patterns

### N+1 queries — batch inserts

Look for DB writes inside loops in repository layer:
```go
// WRONG — N roundtrips
for _, id := range ids {
    db.Create(&Row{ID: id})
}
// CORRECT — 1 roundtrip
rows := make([]Row, len(ids))
for i, id := range ids { rows[i] = Row{ID: id} }
db.Create(&rows)
```
Flag any `for` loop in the repository that contains a DB write.

### Do not recreate existing infrastructure

Before adding something new, check if it already exists:

| What you might write | What already exists |
|----------------------|---------------------|
| Custom error struct | `gokittypes.NewBadRequest()` / `gokittypes.NewNotFound()` |
| Deduplication helper | `sliceutil.Unique()` from go-kit |
| Manual input validation | `requestvalidator.Validate()` from go-kit |
| New file in `pkg/` | Check go-kit first |

Flag: any new `pkg/` file or custom error type that reimplements something from `go-kit`.

### app.go wiring order

New module init must be placed with its peers, not at the bottom of `initModules`:
```
repos → services → usecases → handlers
```
Flag: handler or service initialized far from its domain group.

### Naming clarity

Flag ambiguous names that require context to understand:
- Single-letter or generic variables outside a short loop (`scoped`, `result`, `data`)
- Struct used as service input/output but named like a DTO (e.g. `UnloaderObjectsResult`)
- Variable that could describe 3+ different things in the codebase

### Unnecessary defensive validation

Flag checks that duplicate guarantees already provided upstream:
- Duplicate detection in service when DB has a unique constraint
- Nil checks on pointers already validated by `requestvalidator`
- Re-validating fields the handler already checked

### AI-generated code smell

Flag code that appears AI-generated without adaptation to the project:
- Helper structs or functions used exactly once
- A method that could be replaced by an existing `GetByID` already on the interface
- Logic more complex than the problem requires
- Patterns inconsistent with how the same problem is solved in other modules

---

## Output Format

```markdown
# Code Review: <Title>

**Branch:** source → target
**Author:** V.Korobov
**Reviewed files:** N

## Summary
One paragraph overall impression.

## Architecture Violations 🏗️
## Critical Issues 🔴
## Warnings 🟡
## Suggestions 💡
## Library Recommendations 📦
## Positive Notes ✅
```

Save the review to `/tmp/mr-review-$MR_ID.md` and display the full content.
