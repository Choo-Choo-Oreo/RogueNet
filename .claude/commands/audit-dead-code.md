---
description: Find dead code, dead data and duplication in RogueNet, report it to docs/TODO.md, and remove it only when asked
---

Run a dead code and duplication audit of RogueNet using the method below. Extra focus: $ARGUMENTS

## How to run it here (RogueNet, Godot + GDScript)

- **Report first; don't delete or merge until asked.** List what you find in `docs/TODO.md`,
  in a new "Dead code and duplication audit, round N (date)" section, as `[✗]` lines with
  file:line and the single place each copy should live, in [brackets]. Skip anything an
  earlier round already listed. Remove or merge only when the person running this says so,
  and follow `.claude/CLAUDE.md` (teach, don't implement) and `docs/OWNERSHIP.md`.
- **Look at data, not just code**: JSON keys nothing reads (`game/`, `resources/`), values that
  can be worked out from something else (a folder already says it), and docs describing
  removed things.
- **Before calling something unused in Godot**, search for these ways it can still be called:
  - `call("name")`, `has_method("name")` or `Callable(obj, "name")`.
  - An `rpc` called by its name as a string.
  - A signal connected in a `.tscn` `[connection]` or a `@export` set in a `.tscn`.
  - A `"res://..."` or node path written as a string.
  - An autoload, or `test/` (GUT tests and `test/sim/` scripts).
- **Don't merge things just because they look alike.** If two copies would need to change
  separately later (players vs minions, light vs sound), leave them apart and say why in
  the "Look alike, keep apart" line.
- **After any removal, check nothing broke**:
  - `--import` (no script errors).
  - GUT (`godot --headless -s res://addons/gut/gut_cmdln.gd`).
  - The sims in `test/sim/` with `--fixed-fps 60`, and `run_sim.bat`.

  Then mark the TODO lines `[✓]` with what replaced each one. Anything that changes network
  messages also needs a two-player test; say so.
- The tools in section 1 are for other languages and don't read GDScript. Instead, search
  for each name with Grep/ripgrep, and compare suspected copies by reading them side by side.

## Method

# Identifying Dead Code, Unused Functions, and Code Duplication

## 1. Automated Detection Tooling

### Static Code Analysis & AST Walkers
* Abstract Syntax Tree (AST) Duplicate Scanners: Use tools like jscpd, SonarQube, or PMD's Copy-Paste Detector (CPD). Unlike simple string comparison, AST-based tools identify structural duplication even when variables, whitespace, or comments differ.
* Dead Code Eliminators & Linters:
  - JavaScript/TypeScript: knip, ts-prune, unimported, ESLint (no-unused-vars)
  - Python: vulture, flake8
  - Go: deadcode, staticcheck
  - Java/C#: archunit, ReSharper, Roslyn analyzers
* Dependency & Export Tracking: Run unused-export tools to detect public methods or module exports that are no longer imported anywhere in the repository.

### Dynamic Analysis & Coverage Reports
* Test Coverage Gaps: Run unit and integration test suites with code coverage enabled (e.g., istanbul/nyc, coverage.py, JaCoCo). Code with 0% coverage across exhaustive integration test suites often indicates dead paths or uncalled feature branches.
* Production Telemetry & Profiling: Use Application Performance Monitoring (APM) tools, tracing (OpenTelemetry), or runtime instrumentation to log function execution in production over a set duration (30 to 90 days). Static analysis often misses dynamic call sites, whereas production logs reveal code paths that are reachable in theory but never executed in practice.


## 2. Visual Code Smells & Architectural Clues

### Indicators of Dead or Uncalled Code
* Dangling Feature Flags: Search for legacy feature toggles where the flag condition is permanently hardcoded to true or false, leaving the non-active branch unreachable.
* Orphaned Version Suffixes: Look for methods or files named with versioning artifacts (processOrder_v2, calculateTaxOld, UserHandler2). Frequently, the newer implementation replaced the older one in primary flows, but the legacy implementation was retained "just in case."
* Commented-Out Blocks & TODOs: Large blocks of commented-out logic often represent deprecated features. Track down associated functions using global symbol searches.
* Single-Caller Functions in Deleted Contexts: When a major component or endpoint is removed, utility functions written specifically for that component often remain in shared utils or helpers modules because they were missed during the initial deletion pull request.

### Indicators of Duplicated Sub-Operations
* Over-Populated utils/ or common/ Directory: Developers often re-implement helper logic (date formatting, string sanitization, token parsing, object deep-clones) when utility functions are disorganized or poorly documented, leading to multiple subtly different implementations across the codebase.
* Parallel Transformation Pipelines: Search for places where data models are transformed for external boundaries (e.g., converting a database entity to a DTO/API response). The same field-mapping logic, null-checking, and field-formatting steps often recur across multiple controller endpoints or background jobs.
* Repeated Control Flow Structures: Look for identical try/catch setups, identical fallback/retry loops, or repeated authorization checks wrapped around different core business operations.


## 3. Pattern Matching Techniques for Sub-Operation Duplication

| Pattern | Common Locations | Typical Refactoring Target |
| :--- | :--- | :--- |
| Validation Chains | Top of handler or service functions | Extract to dedicated validator schema, middleware, or policy class |
| Setup & Teardown Boilerplate | DB connections, locks, file handles, transaction management | Extract using Higher-Order Functions, Execute-Around methods, or Context Managers (with/using) |
| Error Handling & Normalization | API call wrappers, external integration services | Extract to a unified HTTP client middleware or centralized error-handling decorator |
| State Inspection / Predicates | Complex multi-variable if conditions checking object status | Extract to a domain model method (e.g., order.canBeRefunded()) |


## 4. Pitfalls & False Positive Hazards

* Dynamic Invocations & Reflection: Static tools often mark functions as "unused" if they are invoked dynamically via reflection, string manipulation, dependency injection containers, event buses, or framework routing annotations (e.g., string-based RPC dispatchers or magic methods like PHP's __call).
* Public APIs and SDKs: In libraries or shared packages, functions without internal call sites are often intended for consumption by downstream external callers.
* Over-Abstraction (Premature DRYing): Consolidating two blocks of code that look identical today but serve fundamentally different business domains creates tight coupling. If domain A needs to change its logic independently of domain B in the future, sharing a single abstracted function forces conditional logic inside the shared function. Code duplication is cheaper than the wrong abstraction.
* Cascade Deletions: Deleting an uncalled function often exposes other functions that were only called by that deleted function. Run static analysis tools iteratively after each round of removals to reveal secondary dead code.
