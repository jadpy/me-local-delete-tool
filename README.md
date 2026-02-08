# ARCHITECTURE.md

## 1. Purpose

This document is the implementation-level architecture for the current repository state.
It is intentionally grounded in actual code paths and function contracts.

This version documents:
- `main.lua`
- `src/*.lua`
- root config/document files that drive runtime behavior

This version intentionally excludes:
- `test/` directory
- sample input files used only as fixtures (`test.lua`)

---

## 2. Runtime Overview

At runtime, the tool is a single-process CLI pipeline:

1. Parse CLI arguments in `main.lua`
2. Load source file
3. Analyze source safety baseline (`src/safety.lua`)
4. Run selected command implementation
5. Run safety guard against regressions
6. Write transformed source to `output/<filename>`
7. Write report files (`.safety.json` and command-specific JSON when applicable)

Core architectural invariant:
- If input was parseable, output must stay parseable.
- If input was compilable, output must stay compilable.
- On regression, output is automatically reverted to original source.

---

## 3. Repository Inventory (Non-test)

### 3.1 Root files

| Path | Role |
|---|---|
| `main.lua` | CLI entrypoint, command dispatcher, report writer |
| `preset.json` | Default multi-step pipeline config |
| `README.md` | User-facing usage guide |
| `ARCHITECTURE.md` | This technical architecture spec |

### 3.2 Source modules

| Path | Role |
|---|---|
| `src/ast.lua` | AST node constructors |
| `src/lexer.lua` | parser-facing lexer (token classes like `LOCAL`, `IDENT`) |
| `src/lexer_full.lua` | full-fidelity lexer (comments/newlines/symbol streams) |
| `src/parser.lua` | recursive-descent parser |
| `src/codegen.lua` | AST -> Lua source generator |
| `src/analyzer.lua` | local symbol counting (summary usage) |
| `src/transformer.lua` | AST-based local-removal transformer |
| `src/transformer_line.lua` | line-preserving local-removal transformer (default engine) |
| `src/formatter.lua` | readability formatter (`fom`) |
| `src/compressor.lua` | minifier + AST optimization + safety validation (`coml`) |
| `src/optimizer.lua` | constant folding / control simplification |
| `src/nmbun.lua` | expression simplification command runner |
| `src/renamer.lua` | local variable rename engine |
| `src/deleteout.lua` | comment stripping with token-boundary safety |
| `src/nocode.lua` | conservative dead local code removal |
| `src/linter.lua` | static lint + dynamic lint integration |
| `src/lint_dynamic.lua` | runtime lint execution + result aggregation |
| `src/lint_sandbox.lua` | isolated runtime sandbox + dependency tracing |
| `src/rrequire.lua` | require/dependency graph analysis |
| `src/preset.lua` | preset pipeline runner |
| `src/safety.lua` | parse/compile/lint safety guard |
| `src/json.lua` | deterministic JSON encode/decode |
| `src/dialect.lua` | dialect resolver interface (currently single fixed profile) |

---

## 4. `main.lua` Deep Flow

### 4.1 CLI shape

Current accepted shape:

```bash
lua54 main.lua [--engine=line|ast] [--lint-dynamic=on|off] <mode> [scope] <inputfile> [presetfile]
```

Notes on option parsing behavior in current code:
- `--engine=...` is parsed and used.
- `--lint-dynamic=...` is parsed and used.
- `--dialect=...` is detected in argument loop but not applied to runtime dialect variable in `main.lua`.

### 4.2 Command dispatch

`process_file()` handles command groups:

- Direct handlers:
  - `fom`, `coml`, `nmbun`, `rename`, `deleteout`, `nocode`, `lint`, `rrequire`, `preset`
- Engine-backed handlers:
  - `functionlocal`, `localkw`, `localte`, `localc`, `localcyt`, `localnum`, `localtabke`, `outcode`, `localtur`

For engine-backed handlers:
- `line` engine -> `TransformerLine`
- `ast` engine -> `Lexer` -> `Parser` -> `Analyzer` -> `Transformer` -> `CodeGen`

### 4.3 Finalization wrapper

Every command result is wrapped by `finalize()`:

```lua
local guarded_output, safety_report = Safety.guard(mode, source, output_code, pre_analysis, { dialect = dialect.name })
```

Then `.safety.json` is appended to `meta.extra_reports` for output emission.

### 4.4 Output behavior

Main output:
- `output/<input_filename>`

Optional reports:
- `output/<input_filename>.lint.json`
- `output/<input_filename>.rrequire.json`
- `output/<input_filename>.preset.json`
- always `output/<input_filename>.safety.json`

Local summary is printed from `analyzer.all_locals` after write.

---

## 5. Shared Data Contracts

## 5.1 Parser-lexer token model (`src/lexer.lua`)

Shape:

```lua
{ type = 'IDENT', value = 'foo', line = 10, col = 5 }
```

Examples of emitted token types:
- keywords: `LOCAL`, `FUNCTION`, `IF`, `FOR`, ...
- symbols: `ASSIGN`, `LPAREN`, `RBRACE`, `CONCAT`, `IDIV`, `DBLCOLON`, ...
- literals: `NUMBER`, `STRING`
- control: `EOF`

## 5.2 Full-fidelity token model (`src/lexer_full.lua`)

Shape:

```lua
{ type = 'comment', value = '--[[x]]', line = 1, col = 1, is_block = true }
```

Token classes used by formatting/minification/comment stripping:
- `keyword`, `ident`, `number`, `string`, `long_string`
- `symbol`, `comment`, `newline`

## 5.3 AST model (`src/ast.lua`)

Core node constructors:
- structural: `Chunk`, `Block`
- declarations: `LocalDecl`, `LocalFunc`, `FunctionDecl`, `Function`
- statements: `Assignment`, `If`, `While`, `Repeat`, `For`, `ForIn`, `Do`, `Return`, `Break`, `Continue`, `Goto`, `Label`
- expressions: `Identifier`, `BinaryOp`, `UnaryOp`, `FunctionCall`, `MethodCall`, `IndexExpr`, `PropertyExpr`, `Table`, `TableField`, `VarArgs`, literals

Parser-attached metadata used downstream:
- `source_line`
- `local_token`, `name_token`, `name_tokens`
- `param_tokens`, `var_token`, `var_tokens`

---

## 6. Parsing and Code Generation

## 6.1 `src/parser.lua`

Parser style:
- recursive descent
- explicit precedence chain
- feature gate hooks (`feature_enabled`, `expect_feature`)

Expression precedence path:
- `or` -> `and` -> unary `not`
- comparison
- bitwise `| ~ & << >>`
- concat `..`
- additive `+ -`
- multiplicative `* / // %`
- unary `- not # ~`
- power `^`
- postfix calls/index/property/method
- primary

Statement support includes:
- local declarations/functions
- function declarations
- labels/goto/continue
- if/while/repeat/for/do
- assignment and expression statements
- return/break

Luau-oriented tolerant parsing helpers:
- local attributes (`<const>`) skipping
- optional type annotation skipping
- optional function generic skipping
- type declaration skipping

Code example (assignment target validation):

```lua
for _, target in ipairs(targets) do
  if not is_assignable_target(target) then
    error("Invalid assignment target")
  end
end
```

## 6.2 `src/codegen.lua`

Responsibilities:
- generate source from AST
- preserve existing indentation where possible when source lines are available
- safely quote strings (`quote_lua_string`)

Key behavior:
- `CodeGen.new(source)` stores `source_lines`
- `generate_chunk()` replaces only modified source lines when metadata exists
- pure regeneration mode via `CodeGen.new(nil)`

Code example (string escaping):

```lua
elseif b < 32 or b == 127 then
  out[#out + 1] = string.format('\\%03d', b)
end
```

---

## 7. Transformation Engines

## 7.1 `src/transformer_line.lua` (default)

Design target:
- remove selected `local` tokens while preserving line layout

Algorithm:
1. Parse AST if possible
2. Collect exact `local_token` positions to remove
3. Fallback to token heuristics if AST parse fails
4. Apply removals right-to-left per line

Also includes `outcode` logic for line-based comment-out stripping.

Scope model:
- `all`, `function`, `global`

Typed local removal support:
- boolean, string, number, table

## 7.2 `src/transformer.lua` (AST engine)

Design target:
- rewrite AST nodes for local-removal modes

Core behavior:
- converts eligible `LocalDecl` into `Assignment`
- converts eligible `LocalFunc` into `FunctionDecl`
- tracks function depth via `in_function` and `function_depth`

Current status:
- line engine is default and more operationally trusted for layout-sensitive commands.

## 7.3 `src/analyzer.lua`

Purpose:
- collect local declarations/reference counts for CLI summary output

Important implementation note:
- `walk_chunk()` currently iterates `node.body` directly, while `Chunk.body` is a `Block` object.
- This can reduce accuracy of analyzer summaries in some AST-engine paths.

---

## 8. Command Modules

## 8.1 `src/formatter.lua` (`fom`)

Pipeline:
- tokenize with `lexer_full`
- detect indent style from source
- stream tokens with spacing and newline policies
- preserve block readability (`if/then/end`, function headers, table literals)

Special readability behavior:
- expands table argument formatting for UI-style calls
- adds top-level blank lines before structural blocks

Code example:

```lua
if should_expand_call_table(tokens, idx) then
  flush_line(true)
  indent = indent + 1
end
```

## 8.2 `src/compressor.lua` (`coml`)

Pipeline:
1. Check source parse/compile capability
2. Optional AST optimize (`Optimizer`) + codegen candidate
3. Build token-stream minify candidate
4. Validate candidate with tokenization + parse/compile invariants
5. Return first valid candidate else original

Safety checks are conservative and explicit.

Code example:

```lua
if source_compile_ok then
  if not can_compile(candidate) then return false end
elseif source_parse_ok then
  if not can_parse_with_ast(candidate, dialect) then return false end
end
```

## 8.3 `src/deleteout.lua` (`deleteout`)

Behavior:
- remove all comments (`--`, long bracket comments)
- preserve line structure by keeping newline bytes from comments
- inject a single separating space when token concatenation would become unsafe

## 8.4 `src/optimizer.lua` + `src/nmbun.lua` (`nmbun`)

`Optimizer`:
- constant folds literal binary/unary expressions
- simplifies conditionals (`if` pruning)
- removes guaranteed-dead loops/empty `do` blocks
- truncates block after guaranteed termination statements

`Nmbun.run`:
- parse -> run optimizer 3 passes -> codegen
- fallback to original source on any failure

## 8.5 `src/renamer.lua` (`rename`)

Design:
- lexical-scope-aware renaming for local variables/params/for-vars
- short random names with collision avoidance
- reverse-order byte-span replacement to avoid overlap corruption

Important constraints:
- does not rename globals intentionally
- supports protected names (`options.protected_names`)

Code example:

```lua
if source:sub(start_pos, end_pos) == rep.old then
  spans[#spans + 1] = { start_pos = start_pos, end_pos = end_pos, new = rep.new }
end
```

## 8.6 `src/nocode.lua` (`nocode`)

Goal:
- conservative dead local code elimination

Pipeline:
1. Parse AST
2. Optimize AST
3. Analyze symbol refs and side-effect risk
4. Iteratively prune (`max 20` iterations)
5. Re-generate and validate parse/compile regressions

Removal rules are conservative:
- remove unused `LocalFunc`
- remove `LocalDecl` only when all declared symbols are unused and initializer expressions are pure

---

## 9. Lint Architecture

## 9.1 `src/linter.lua` static lint

Static checks include:
- `duplicate-local`
- `shadowing`
- `unused-variable`
- `undefined-reference`
- `type-mismatch`
- `suspicious-compare`
- `call-non-function`
- `self-assignment`
- `global-write`
- `global-overwrite`
- `useless-expression`
- `unreachable-code`

Static analysis components:
- scope creation/lookup
- symbol declaration/reference counting
- lightweight type inference
- side-effect detection for expression statements
- termination analysis for unreachable code

## 9.2 `src/lint_dynamic.lua` + `src/lint_sandbox.lua`

Dynamic lint model:
- execute input in isolated sandbox env
- enforce instruction budget via `debug.sethook`
- optionally probe callable targets
- aggregate runtime events and dependency traces

Sandbox traces include:
- all/resolved/unresolved/undefined global reads
- global writes
- proxy root and nested proxy reads
- `require` calls
- metatable gets/sets/metamethod usage
- event stream and chronological history

Dynamic report object contains:
- `dependencies.globals`
- `dependencies.metatable`
- `dependencies.proxies`
- `dependencies.require`
- `history` + `history_stats`
- `map_stats` truncation information
- `execution` probe metrics
- `runtime.main` status/error

Code example (dependency block in dynamic output):

```lua
dependencies = {
  globals = { reads = ..., resolved_reads = ..., unresolved_reads = ... },
  metatable = { gets = ..., sets = ..., metamethod_keys = ... },
  proxies = { roots = ..., reads = ... },
  require = ...
}
```

---

## 10. Dependency Analysis (`src/rrequire.lua`)

Goal:
- build `require` dependency graph from entry file

Flow:
1. Parse a file and collect require calls (AST path)
2. If AST path fails, fallback token scan (`lexer_full`)
3. Resolve module names to file paths via:
   - caller-relative candidates
   - root-dir candidates
   - `.lua` and `init.lua` variants
   - `package.path` pattern candidates
4. Traverse graph breadth-first
5. Detect cycles via DFS back-edge tracking

Output structure:
- `nodes`, `edges`, `adjacency`, `cycles`
- `unresolved`, `dynamic`, `parse_errors`
- `summary`

---

## 11. Preset Pipeline (`src/preset.lua` + `preset.json`)

Preset runner executes steps sequentially on a single in-memory source buffer.

Step contract fields:
- `name`, `mode`, `enabled`
- optional `scope`, `engine`, `dialect`, `lint_dynamic`, `write_output`

Preset-level fields:
- `engine`
- `write_step_outputs`
- `stop_on_error`
- `steps`

Sequential overwrite contract:
- output of step `N` is input of step `N+1`
- no branch fanout unless step snapshots are explicitly written

Per-step safety:
- each step runs `Safety.guard`
- step report stores fallback status and reason

Output files:
- final: `output/<file>`
- report: `output/<file>.preset.json`
- optional snapshots: `output/preset_steps/<file>.stepXX_<name>.lua`

---

## 12. Safety System (`src/safety.lua`)

`Safety.analyze_source` computes:
- parse status
- compile status
- static lint summary

`Safety.guard` enforces:
- parse regression prevention
- compile regression prevention
- fallback to original source on invariant failure

Safety report schema:

```json
{
  "type": "safety-report",
  "mode": "...",
  "dialect": "auto",
  "before": { "parse_ok": true, "compile_ok": true, "lint_summary": {} },
  "after": { "parse_ok": true, "compile_ok": true, "lint_summary": {} },
  "fallback_applied": false,
  "fallback_reason": null
}
```

---

## 13. Utility Modules

## 13.1 `src/json.lua`

Encoder:
- deterministic key sort for objects
- pretty mode enabled by default
- cycle-safe output via `"<cycle>"`
- arrays detected by contiguous `1..N` integer keys

Decoder:
- strict parser for object/array/string/number/bool/null
- explicit error positions on malformed input

## 13.2 `src/dialect.lua`

Current implementation is intentionally simplified:
- `resolve(_)` always returns one fixed profile (`auto`)
- `is_valid(_)` always `true`
- `list()` returns only `{ "auto" }`

Implication:
- parser/lexer feature gating exists in code, but runtime dialect choice is effectively fixed in current state.

---

## 14. End-to-end Command Matrix

| CLI mode | Core module(s) | Output mutation | Extra report |
|---|---|---|---|
| `functionlocal` | `transformer_line` / `transformer` | yes | safety |
| `localkw` | `transformer_line` / `transformer` | yes | safety |
| `localte` | `transformer_line` / `transformer` | yes | safety |
| `localc` / `localcyt` | `transformer_line` / `transformer` | yes | safety |
| `localnum` | `transformer_line` / `transformer` | yes | safety |
| `localtabke` | `transformer_line` / `transformer` | yes | safety |
| `outcode` | `transformer_line` | yes | safety |
| `deleteout` | `deleteout` | yes | safety |
| `fom` | `formatter` | yes | safety |
| `coml` | `compressor` | yes | safety |
| `nmbun` | `nmbun` + `optimizer` | yes | safety |
| `rename` | `renamer` | yes | safety |
| `nocode` | `nocode` + `optimizer` | yes | safety |
| `lint` | `linter` + optional dynamic | no (returns source) | `.lint.json` + safety |
| `rrequire` | `rrequire` | no (returns source) | `.rrequire.json` + safety |
| `preset` | `preset` | yes (step pipeline) | `.preset.json` + safety |

---

## 15. Practical Code-path Examples

## 15.1 Main dispatch example

```lua
elseif mode == 'coml' then
  local output_code = Compressor.compress(source, { dialect = dialect.name })
  return finalize(output_code, { all_locals = {} })
end
```

## 15.2 Preset sequential overwrite example

```lua
local guarded_output, safety_report = Safety.guard(internal_mode, current_source, out_code, step_before, { dialect = step_dialect })
current_source = guarded_output
```

## 15.3 Dynamic lint trace example

```lua
record(trace.require_calls, key)
push_history(trace, 'require', key)
record_event(trace, 'info', 'require-call', "require('" .. key .. "')")
```

---

## 16. Current Technical Debt / Accuracy Notes

1. `main.lua` argument parser currently consumes `--dialect=...` without wiring it to runtime dialect selection.
2. `src/dialect.lua` is currently single-profile (`auto`) and does not enforce per-version mode separation.
3. `src/analyzer.lua` chunk walker shape differs from `AST.Chunk` shape (`node.body` vs `node.body.statements`).
4. AST transformer path has narrower practical use than line transformer for local-removal operations.

These are implementation facts, not hypothetical risks.

---

## 17. Extension Checklist (How to add a new command)

1. Add module `src/<feature>.lua`.
2. Require module in `main.lua`.
3. Add branch in `process_file()`.
4. Add CLI parse block for mode and arguments.
5. Add mode mapping to internal mode string if needed.
6. Add report output contract if command emits JSON report.
7. Ensure command output goes through `Safety.guard`.
8. Update `README.md` and this file.

Minimal example branch pattern:

```lua
elseif mode == '<newmode>' then
  local output_code, analyzer, meta = NewModule.run(source, { dialect = dialect.name })
  return finalize(output_code, analyzer, meta)
end
```

---

## 18. File-by-file API Contract (Non-test)

This section is an implementation index: each non-test file, its callable entrypoints, I/O, and safety profile.

### 18.1 Root files

#### `main.lua`
- Public functions:
  - `read_file(filepath)`
  - `write_file(filepath, content)`
  - `ensure_dir(dirpath)`
  - `process_file(input_filepath, mode, engine, options)`
  - `show_usage()`
  - `main()`
- Input:
  - CLI args + source file bytes.
- Output:
  - transformed source file in `output/`.
  - optional report files (`.lint.json`, `.rrequire.json`, `.preset.json`, always `.safety.json`).
- Failure model:
  - file I/O error -> hard error.
  - command regression -> `Safety.guard` fallback.

#### `preset.json`
- Role:
  - declarative step pipeline for `preset` command.
- Contract:
  - top-level defaults + ordered `steps[]`.
  - per-step override of mode/scope/engine/dialect/dynamic lint flags.

#### `README.md`
- Role:
  - user-facing command contract and examples.
- Requirement:
  - must stay synchronized with `show_usage()` and dispatch table in `main.lua`.

#### `ARCHITECTURE.md`
- Role:
  - implementation-oriented behavior and contract map.

### 18.2 Core syntax stack

#### `src/ast.lua`
- Export:
  - AST constructor table (`AST.<Node>()`).
- Contract:
  - constructors are pure; they build node tables and do no I/O.
- Used by:
  - parser, optimizer, transformers, generator.

#### `src/lexer.lua`
- Export:
  - `Lexer.new(source, options)` and tokenizing methods.
- Output token shape:
  - `{ type, value, line, col }`.
- Failure model:
  - malformed token (string/number) -> lexer error.

#### `src/lexer_full.lua`
- Export:
  - `LexerFull.new(source, options)`, `:tokenize()`.
- Output token shape:
  - includes trivia (`comment`, `newline`) and symbols for layout-sensitive transforms.
- Used by:
  - formatter, compressor, deleteout, fallback scanners.

#### `src/parser.lua`
- Export:
  - `Parser.new(tokens, options)`, `:parse()`.
- Input:
  - parser-lexer token stream.
- Output:
  - `AST.Chunk`.
- Failure model:
  - syntax or feature-gate violation -> error with token context.

#### `src/codegen.lua`
- Export:
  - `CodeGen.new(source)`, `:generate(ast)`.
- Input:
  - AST (+ optional original source for indent preservation).
- Output:
  - regenerated Lua text.
- Safety:
  - string escaping is explicit (`quote_lua_string`).

### 18.3 Analysis and transformation

#### `src/analyzer.lua`
- Export:
  - `Analyzer.new()`, `:analyze(ast)`, `:get_local_info()`.
- Output:
  - local symbol usage map for summary output.
- Note:
  - current chunk walk shape mismatch can lower precision in some AST flows.

#### `src/transformer.lua`
- Export:
  - `Transformer.new(options)`, `:transform(ast)`.
- Behavior:
  - AST rewrite for local-removal modes.

#### `src/transformer_line.lua`
- Export:
  - `TransformerLine.new(source, tokens, options)`, `:apply()`.
- Behavior:
  - line/column targeted `local` removal with layout preservation.
- Why default:
  - more robust for whitespace-sensitive user expectations.

#### `src/formatter.lua`
- Export:
  - `Formatter.format(source, options)`.
- Behavior:
  - readability reflow, indentation normalization, call/table readability improvements.

#### `src/compressor.lua`
- Export:
  - `Compressor.compress(source, options)`.
- Behavior:
  - AST optimization candidate + token minify candidate + strict parse/compile validation.
- Failure model:
  - invalid candidate is rejected; returns safe original/candidate fallback only.

#### `src/optimizer.lua`
- Export:
  - `Optimizer.optimize(chunk)`.
- Behavior:
  - constant folding and control-flow simplification on AST.

#### `src/nmbun.lua`
- Export:
  - `Nmbun.run(source, options)`.
- Behavior:
  - parser + optimizer passes + codegen.
- Output:
  - simplified source + analyzer-like summary object.

#### `src/renamer.lua`
- Export:
  - `Renamer.rename(source, options)`.
- Behavior:
  - lexical-scope local renaming with collision-safe short names.
- Safety:
  - byte-span replacements validated against original identifiers before write.

#### `src/deleteout.lua`
- Export:
  - `DeleteOut.strip(source, options)`.
- Behavior:
  - remove comments while preserving token boundary safety and line structure.

#### `src/nocode.lua`
- Export:
  - `NoCode.clean(source, options)`.
- Behavior:
  - conservative dead local removal with side-effect checks and parse/compile validation.

### 18.4 Diagnostics, graphing, safety, runtime

#### `src/linter.lua`
- Export:
  - `Linter.run(source, options)`, `Linter.format_report(result, input_filepath)`.
- Behavior:
  - static diagnostics + optional dynamic integration.
- Output:
  - structured lint result object consumed by `main.lua`.

#### `src/lint_dynamic.lua`
- Export:
  - `LintDynamic.run(source, options)`.
- Behavior:
  - runtime execution with budgets, event aggregation, dependency summarization.

#### `src/lint_sandbox.lua`
- Export:
  - `LintSandbox.build(options)`.
- Behavior:
  - instrumented environment/proxy layer for dynamic lint.
- Output:
  - trace maps/events/history/dependency details.

#### `src/rrequire.lua`
- Export:
  - `RRequire.analyze(entry_file, options)`, `RRequire.format_report(result)`.
- Behavior:
  - require graph extraction + module path resolution + cycle detection.

#### `src/safety.lua`
- Export:
  - `Safety.analyze_source(source, options)`, `Safety.guard(mode, source, output, before_analysis, options)`.
- Contract:
  - prevents parse/compile regressions by fallback.

#### `src/preset.lua`
- Export:
  - `Preset.run(input_filepath, preset_filepath, default_engine, options)`.
- Behavior:
  - ordered in-memory step execution with per-step safety guarding and JSON reporting.

### 18.5 Utilities

#### `src/json.lua`
- Export:
  - `Json.encode(value, pretty)`, `Json.decode(input)`.
- Behavior:
  - deterministic pretty JSON + strict decode parser.

#### `src/dialect.lua`
- Export:
  - `Dialect.resolve(_)`, `Dialect.is_valid(_)`, `Dialect.list()`.
- Current contract:
  - runtime behavior is fixed to one profile (`auto`) in current implementation.

---

## 19. Command Failure/Fallback Guarantees

All mutating commands in `main.lua` are wrapped by `finalize()` -> `Safety.guard()`.

Guarantees:
1. If source parses before transform, parseability regression is blocked.
2. If source compiles before transform, compile regression is blocked.
3. On blocked regression, emitted output is original source and reason is in `.safety.json`.

Operational implication:
- aggressive transforms (`coml`, `nocode`, `nmbun`, AST/line local rewrites) are fail-closed.
- non-mutating commands (`lint`, `rrequire`) still emit safety report for uniform observability.

---

## 20. Summary

This codebase is a safety-first source-to-source transformation and analysis CLI.
The architecture combines:
- token-level layout-sensitive editing,
- AST-level semantic rewriting,
- conservative safety fallback,
- structured JSON observability for lint/dependency/preset execution.

For implementation-level details, this file should be treated as the authoritative map of current non-test runtime behavior.
