Perform a pre-submit self-review of the current working diff against the Go architecture conventions of this project.

Run this command to see the diff:
```
git diff origin/master...HEAD
```

Then critically evaluate the code using the checklist below. For each section, explicitly answer: **pass** or **flag + explanation**.

---

## Checklist for V.Korobov — patterns from past reviews

### 1. Did you look at master before writing?

Before adding a new module/handler/route, check how the existing ones are structured in master:
- Handler registration: does it follow the pattern in `internal/api/router.go`?
- `app.go` wiring: is the new service/repo/handler placed in the right group (repos → services → usecases → handlers)?
- Module structure: does the new module have `model.go`, `service.go`, `repository.go`, `request_dto.go`, `response_dto.go` — like the others?

**Red flag:** Code placed at the bottom of `app.go` instead of near its domain peers. Routes registered differently from how other routes are done.

---

### 2. N+1 queries — batch inserts

If you're inserting multiple rows, never do it in a loop:
```go
// WRONG — N database roundtrips
for _, uuid := range uuids {
    db.Create(&Row{UUID: uuid})
}

// CORRECT — 1 roundtrip
rows := make([]Row, len(uuids))
for i, uuid := range uuids {
    rows[i] = Row{UUID: uuid}
}
db.Create(&rows)
```

Check every `for` loop in your repository layer. If it contains a DB write — replace with a batch insert.

---

### 3. Existing infrastructure — do not create what already exists

Before adding any new utility, check if it already exists:

| You want | Already exists |
|----------|---------------|
| Custom error types | `gokittypes.NewBadRequest()`, `gokittypes.NewNotFound()` in `go-kit` |
| Custom HTTP status wrapper | `gokittypes.ClientError` with `errors.As` in handler |
| Unique values | `sliceutil.Unique()` from go-kit |
| GetByID | Check if method already exists on the repository interface |

**Red flag:** Any new file in `pkg/` — ask yourself if this already exists in `go-kit` or another module before creating it.

---

### 4. Naming clarity

Names must be clear without context:
- `scoped` → `directoryScopedClient`
- `result` / `data` / `resp` → name what it actually is
- Struct named `UnloaderObjectsResult` that only holds two slices → probably just inline it or name it as what it represents

Rule: if the name could describe three different things in the codebase, it's wrong.

---

### 5. Remove duplicate/defensive validation that isn't needed

Before adding a check, ask: **can this state actually occur at this point?**

```go
// service.go — this check was flagged
if duplicateExists(craneUUIDs) {
    return error...
}
```

If the deduplication is already handled upstream (validator, unique DB constraint), don't re-check it in the service. Trust the layers above you.

---

### 6. Don't suppress errors silently — make them observable

Every error must either be returned or logged with enough context to debug:

```go
// WRONG — how do you know what happened?
if err != nil {
    return errors.New("internal error")
}

// CORRECT
if err != nil {
    return fmt.Errorf("unloader service: update cranes: %w", err)
}
```

In handlers, use `errors.As` to distinguish user-facing errors from internal ones:
```go
var clientErr *gokittypes.ClientError
if errors.As(err, &clientErr) {
    response.Error(w, clientErr.Status, clientErr.Message)
    return
}
response.Error(w, http.StatusInternalServerError, "internal error")
```

---

### 7. AI-generated code smell

If you used AI to generate a part of the solution, re-read it and ask:
- Is this simpler than what I would have written by hand?
- Does it use patterns consistent with the rest of the codebase?
- Are there abstractions here that exist only for the AI, not for the project?

Signs of AI code to watch for:
- Structs or helpers that exist only to wrap one value
- Unusually deep indentation or nested conditionals for simple logic
- Helper methods that are called once and add no clarity

If it looks foreign — rewrite it to match the project style.

---

### 8. Migrations — key naming

Foreign key constraint names must follow the pattern used in other migrations:
```sql
-- Check existing migrations for the naming convention, e.g.:
CONSTRAINT fk_operation_conveyors_operation_id
    FOREIGN KEY (operation_id) REFERENCES operations(id)
```

Never use auto-generated names without checking they match the project's convention.

---

## Output format

For each item above, answer:
- ✅ Pass
- ⚠️ Flag: [what exactly and where]

If any item is flagged — fix it before posting the MR.
