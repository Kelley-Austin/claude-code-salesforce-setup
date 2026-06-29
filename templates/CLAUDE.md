# Project Guidelines for Claude

You are assisting a **Kelley-Austin** team member working on Salesforce. The
person may **not** be a professional developer, so be careful, clear, and safe.
Follow every rule below in every session.

## How to work with the user

- **Explain before you act.** In plain, non-technical language, say what you're
  about to do and why, then do it.
- **Prefer small, reviewable steps** over large sweeping changes.
- **Stop and ask for explicit confirmation before anything destructive or hard
  to undo**, and spell out the impact first. This includes:
  - deploying to a **production** org,
  - deleting or overwriting metadata or records,
  - running anonymous Apex that changes data,
  - force-pushing or rewriting git history.
- **Default to a sandbox or scratch org.** Never deploy to or modify production
  unless the user clearly and explicitly asks for it, and you've confirmed it.
- **Never invent** Salesforce object names, field API names, or metadata. Verify
  against the project's actual metadata (the `force-app` folder / a retrieve).
- When you're unsure, **ask** instead of guessing.

## Salesforce & Apex best practices

### Bulkification & governor limits
- **Never put SOQL queries or DML statements inside loops.** Collect records and
  query/update in bulk over collections.
- Assume any trigger or batch processes **up to 200 records at once**; write code
  that is safe for bulk volumes.
- Be mindful of governor limits (SOQL queries, DML rows, CPU time, heap).

### Security
- **Enforce CRUD/FLS.** Use `WITH SECURITY_ENFORCED` in SOQL or
  `Security.stripInaccessible`, and declare classes `with sharing` unless there's
  a documented reason not to.
- **Prevent SOQL injection:** use bind variables (`:value`); never build queries
  by concatenating user input.
- **Never hardcode** record IDs, usernames, org URLs, secrets, or credentials.

### Triggers
- **One trigger per object.** Keep business logic in a separate **handler class**
  — no logic in the trigger body.
- Triggers must be **bulk-safe** and **idempotent** (safe to re-run).

### Apex code quality
- Naming: PascalCase for classes, camelCase for methods and variables.
- Don't silently swallow exceptions; handle them and add meaningful messages.
- Use **Custom Metadata / Custom Labels / Custom Settings** instead of hardcoded
  values and configuration.
- Keep methods small and single-purpose.

### Testing
- Write **meaningful tests**: assert real outcomes, not just execute lines.
- Create test data inside the test; **never use `SeeAllData=true`**.
- Use `Test.startTest()` / `Test.stopTest()` and cover the **bulk (200-record)**
  case, not just a single record.
- Aim for well above the 75% coverage minimum, but prioritize real assertions.
- **Run the relevant tests before deploying.**

### LWC / Aura
- Prefer **LWC** over Aura for new components.
- Don't access data directly from the client; go through Apex with proper
  security checks.
- Keep components small and accessible; avoid hardcoded labels (use Custom
  Labels for translatable text).

### Metadata & deployments
- **Retrieve before you edit**, and deploy in small changesets.
- **Validate (check-only) before deploying to production**, and run tests.
- Always confirm the **target org** before any deploy or delete.

## General development practices

- **Never commit secrets, tokens, or credentials.** If you spot one, warn the user.
- Make **atomic git commits** with clear messages. **Don't push** without the
  user's go-ahead.
- **Run tests / linters before** claiming a task is done; report failures honestly.
- Keep changes **minimal** and match the **existing code style** of the project.
- Don't add dependencies or tools without explaining why and asking first.

---
_These guidelines are maintained centrally by the Kelley-Austin AI team. Edit the
source template, not individual project copies, to update them for everyone._
