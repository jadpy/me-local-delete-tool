# ARCHITECTURE.md

## 0. Document Scope

This document is the implementation-level architecture spec for `lua-local-deleted-tool`.
It is intentionally strict and maps directly to current code paths in:

- `main.lua`
- `src/*.lua`
- `test/*.lua`

Primary goals:

- Explain exact runtime flow from CLI input to output artifacts
- Define data contracts between lexer/parser/transformers
- Define safety invariants and fallback behavior
- Provide extension and regression strategy

Target runtime:

- Lua 5.4 CLI (`lua54`)
- Source language focus: Lua 5.1 style + practical Luau syntax seen in the codebase

---

## 1. System Context and Non-goals

### 1.1 What this tool does

- Local keyword transformations (`functionlocal`, `localkw`, `localtabke`, `localcyt`, `localte`, `localnum`, etc.)
- Formatting (`fom`)
- Minification/compression (`coml`)
- Numeric expression simplification (`nmbun`)
- Local identifier renaming (`rename`)
- Comment stripping (`deleteout`, `outcode`)
- Conservative dead local cleanup (`nocode`)
- Static analysis (`lint`)
- Require dependency graphing (`rrequire`)
- Step pipeline execution (`preset`)

### 1.2 Non-goals

- Full Lua compiler pipeline (bytecode backend)
- Whole-program type system
- Aggressive unsafe optimization
- Perfect semantic preservation under malformed input

---

## 2. Module Topology

### 2.1 Core runtime modules

- `main.lua`: CLI parser, mode mapping, orchestration, output/report writing
- `src/safety.lua`: parse/compile/lint safety gate used by all commands
- `src/json.lua`: deterministic JSON encode/decode helper

### 2.2 Parsing pipeline modules

- `src/lexer.lua`: compact tokenization for AST-oriented paths
- `src/parser.lua`: recursive-descent parser
- `src/ast.lua`: AST constructors
- `src/codegen.lua`: AST to Lua code generation

### 2.3 Transform/analysis modules

- `src/transformer.lua`: AST-based local transformations
- `src/transformer_line.lua`: position-based line-preserving local transformations
- `src/analyzer.lua`: local symbol stats collection (used for summary)
- `src/optimizer.lua`: conservative constant folding and control simplification

### 2.4 Feature modules

- `src/formatter.lua`
- `src/compressor.lua`
- `src/nmbun.lua`
- `src/renamer.lua`
- `src/deleteout.lua`
- `src/nocode.lua`
- `src/linter.lua`
- `src/rrequire.lua`
- `src/preset.lua`

### 2.5 Debug/test modules

- `test/debug_tokens.lua`
- `test/debug_parser.lua`
- `test/debug_ast.lua`
- `test/debug_parse_suite.lua`
- `test/debug_local_modes.lua`

---

## 3. CLI Contract (main.lua)

### 3.1 Input grammar

```text
lua54 main.lua [--engine=line|ast] <mode> [scope] <inputfile> [presetfile]
```

### 3.2 Mode classes

Direct command handlers in `process_file()`:

- `fom`
- `coml`
- `nmbun`
- `rename`
- `deleteout`
- `nocode`
- `lint`
- `rrequire`
- `preset`

Engine-backed transform family:

- `functionlocal`
- `localkw`
- `localtabke`
- `localcyt`
- `localc`
- `localte`
- `localnum`
- `localtur` (compat alias path in current parser)
- `outcode`

### 3.3 Mode mapping example

```lua
elseif mode_name == 'localnum' then
  if scope == 'function' then
    mode = 'remove_local_number_function'
  elseif scope == 'global' then
    mode = 'remove_local_number_global'
  else
    mode = 'remove_local_number_all'
  end
```

### 3.4 Engine semantics

- default: `line`
- `line`: `TransformerLine` (layout-preserving bias)
- `ast`: `Lexer -> Parser -> Analyzer -> Transformer -> CodeGen`

---

## 4. End-to-end Execution Flow

### 4.1 Canonical flow

1. `read_file(input)`
2. `pre_analysis = Safety.analyze_source(source)`
3. run mode-specific transform/analyze
4. `Safety.guard(mode, input, output, pre_analysis)`
5. write `output/<file>`
6. write optional report (`.lint.json`, `.rrequire.json`, `.preset.json`)
7. always write `.safety.json`

### 4.2 Guard wrapper (main.lua)

```lua
local function finalize(output_code, analyzer, meta)
  local guarded_output, safety_report = Safety.guard(mode, source, output_code, pre_analysis)
  local final_meta = meta or {}
  final_meta.extra_reports = final_meta.extra_reports or {}
  final_meta.extra_reports[#final_meta.extra_reports + 1] = {
    suffix = '.safety.json',
    data = safety_report
  }
  return guarded_output, analyzer or { all_locals = {} }, final_meta
end
```

### 4.3 Output trim policy

`main.lua` trims trailing newlines for most code-mutating modes, but skips trim for:

- `rename`
- `deleteout`
- `nocode`
- `lint`
- `rrequire`
- `preset`

Rationale: preserve intended layout/report behavior.

---

## 5. Token Models

## 5.1 `src/lexer.lua` token contract

Shape:

```lua
{ type = 'IDENT', value = 'x', line = 10, col = 5 }
```

Characteristics:

- Skips whitespace/comments
- Emits parser-facing token classes (`LOCAL`, `IDENT`, `ASSIGN`, ...)
- Converts numeric text using `tonumber(value)`
- Emits EOF token

### Risk note

`read_number()` accepts `[0-9a-fxA-FX.]` before exponent handling, so malformed edge strings can propagate to `tonumber(nil)` behavior depending on source text.

## 5.2 `src/lexer_full.lua` token contract

Shape:

```lua
{ type = 'comment', value = '--[[...]]', line = 1, col = 1, is_block = true }
```

Token kinds include:

- `keyword`, `ident`, `number`, `string`, `long_string`
- `symbol`
- `comment`
- `newline`

Key capability:

- Preserves comment/newline boundaries for formatter/minifier/comment-strip paths.

---

## 6. Parser and AST Contract

## 6.1 Recursive descent entrypoints

- `parse()` -> `parse_chunk()`
- `parse_statement()` dispatches statement forms
- `parse_expression()` dispatches precedence chain

## 6.2 Expression precedence (current implementation order)

1. `or`
2. `and`
3. `not`
4. comparison (`< <= > >= == ~=`)
5. concat (`..`)
6. additive (`+ -`)
7. multiplicative (`* / // %`)
8. unary (`- not #`)
9. power (`^`, right-associative)
10. postfix (`()`, `[]`, `.`, `:`)
11. primary

## 6.3 AST shape examples (`src/ast.lua`)

```lua
AST.LocalDecl(names, values)
AST.Assignment(targets, values)
AST.FunctionDecl(name, params, body, is_local)
AST.If(condition, then_body, elseif_parts, else_body)
AST.Table(fields)
```

Parser enriches some nodes with metadata used by later stages:

- `source_line`
- `local_token`
- `name_token`, `name_tokens`
- `param_tokens`
- `var_token`, `var_tokens`

These fields are critical for:

- line-precise local keyword removal
- byte-span identifier replacement in renaming

---

## 7. Engine Implementations

## 7.1 Line engine (`src/transformer_line.lua`)

Design intent:

- Keep original layout as much as possible
- Remove only targeted `local` tokens by line/column position

Pipeline:

1. Parse AST (preferred)
2. collect removable local-token positions
3. fallback to token scan if AST path fails
4. apply removals right-to-left per line

Key decision function:

```lua
local function should_remove_local(node, mode, in_function)
  ...
end
```

Scope logic:

- `all`, `function`, `global` via `scope_match()` and `get_scope_mode()`

Type-targeted modes:

- table/string/boolean/number by `decl_values_match_type()` and token fallback classifier.

## 7.2 AST engine (`src/transformer.lua`)

Design intent:

- Structural rewrite of AST nodes
- Convert `LocalDecl`/`LocalFunc` to assignment/function declarations based on mode

Flow:

- recursive `walk_node()` with function-depth tracking (`in_function`, `function_depth`)

Important behavior:

- Keeps nodes unchanged if mode/scope does not match
- marks transformed nodes with `modified = true`

### Technical debt note

`Transformer` currently has duplicated mode branches and only partial support for all mode combinations compared to line engine. Line engine is the authoritative default path.

---

## 8. Code Generation (`src/codegen.lua`)

## 8.1 Dual operation mode

- `CodeGen.new(source)` with source-line preservation attempt
- `CodeGen.new(nil)` pure regeneration mode

## 8.2 Modified-line replacement logic

`generate_chunk()` scans for nodes with `modified + source_line` and replaces matching source line content.

## 8.3 String emission

Uses `quote_lua_string()` to escape control bytes safely:

- `\n`, `\t`, `\r`, `\"`, `\\`
- non-printable bytes as `\ddd`

---

## 9. Command Internals

## 9.1 `fom` (`src/formatter.lua`)

Algorithm:

- tokenize with `lexer_full`
- infer indent style (`tabs` vs `spaces`, GCD width)
- stream tokens with spacing and line-break policy
- special multiline expansion for UI-style call tables

Critical merge safety:

```lua
if merge_pairs[prev.value .. nxt.value] then return true end
```

## 9.2 `coml` (`src/compressor.lua`)

Algorithm:

1. compute source parse/compile status
2. if parseable and optimize enabled: AST optimize + codegen candidate
3. always build raw minify candidate
4. validate candidate:
   - `lexer_full` re-tokenization must succeed
   - preserve compile ability if source compiled
   - else preserve parse ability if source parsed
5. first valid candidate wins; else return source

Comment/newline collapse uses semicolon insertion at statement boundaries when required.

## 9.3 `nmbun` (`src/nmbun.lua`)

- parse AST
- apply `Optimizer.optimize()` 3 passes
- emit code
- on failure return original source

## 9.4 `rename` (`src/renamer.lua`)

Renaming strategy:

- Collect used names to avoid collisions
- Generate short names with randomized cycle per length
- Build lexical scopes and map declarations/references consistently
- Apply text replacements by byte spans in reverse order

Span application invariant:

- replacements must match exact old text at computed positions
- overlapping replacements are naturally avoided by reverse ordering

## 9.5 `deleteout` (`src/deleteout.lua`)

- find comment spans via `lexer_full`
- replace comment bytes while preserving newline bytes
- if empty replacement would concatenate tokens unsafely, inject single space

## 9.6 `nocode` (`src/nocode.lua`)

Pipeline:

1. parse AST
2. optimizer pass
3. repeated prune loop (max 20)
4. regenerate
5. parse/compile regression checks against source

Pruning rule (conservative):

- remove `LocalFunc` with zero refs
- remove `LocalDecl` only when all symbols unused and initializer expressions are pure

## 9.7 `lint` (`src/linter.lua`)

Detects:

- `unused-variable`
- `undefined-reference`
- `duplicate-local`
- `shadowing`
- `type-mismatch`
- `global-write`
- `global-overwrite`
- `call-non-function`
- `self-assignment`
- `unreachable-code`
- `useless-expression`

Output is report-only; source text remains unchanged.

## 9.8 `rrequire` (`src/rrequire.lua`)

Two-stage extraction:

1. AST extraction of require calls and aliases
2. token fallback extraction if parser path fails

Resolution strategy:

- relative from caller dir
- root-dir fallback
- `.lua` and `init.lua` candidate patterns
- `package.path` pattern expansion support

Also records:

- unresolved requires
- dynamic require calls
- parse errors
- dependency cycles

## 9.9 `preset` (`src/preset.lua`)

- decode preset JSON
- execute steps sequentially on in-memory `current_source`
- each step may choose engine
- each step guarded by `Safety.guard`
- optional per-step output/report writing
- final preset report emitted

Sequential overwrite contract:

- step N output is exact input for step N+1
- no branch fan-out unless explicit output snapshots enabled

---

## 10. Safety Invariants

Global invariants enforced in `src/safety.lua`:

1. If input was parseable, output must remain parseable
2. If input was compilable, output must remain compilable
3. On invariant break, output falls back to original input

Guard decision core:

```lua
if before.parse_ok and not after.parse_ok then
  fallback_applied = true
elseif before.compile_ok and not after.compile_ok then
  fallback_applied = true
end
```

Lint summary is always produced for before/after context in safety report.

---

## 11. Output Artifacts

## 11.1 Main output

- `output/<filename>`

## 11.2 Safety report

- `output/<filename>.safety.json`

Schema (high-level):

```json
{
  "type": "safety-report",
  "mode": "string",
  "generated_at": "ISO-8601",
  "before": {
    "parse_ok": true,
    "compile_ok": true,
    "lint_summary": {"total": 0, "error": 0, "warning": 0, "info": 0}
  },
  "after": {"parse_ok": true, "compile_ok": true, "lint_summary": {}},
  "fallback_applied": false,
  "fallback_reason": null
}
```

## 11.3 Mode-specific reports

- `lint`: `output/<filename>.lint.json`
- `rrequire`: `output/<filename>.rrequire.json`
- `preset`: `output/<filename>.preset.json`

Optional preset step snapshots:

- `output/preset_steps/<filename>.stepXX_<name>.lua`
- `output/preset_steps/<filename>.stepXX_<name>.safety.json`

---

## 12. Performance Characteristics

Approximate complexity by dominant phase:

- Lexer/token stream passes: `O(n)`
- Parser: `O(n)` for valid code
- Formatter/compressor streaming: `O(n)`
- Renamer: `O(n)` AST walk + replacement sort `O(k log k)` where `k` is replacement count
- Nocode: up to 20 optimization/prune cycles; worst-case `O(20n)` plus codegen
- Rrequire graph traversal: `O(V + E)` across resolved files (plus parse cost per file)

Memory behavior:

- Most transforms hold full source and token list simultaneously
- AST-based modes additionally hold full AST

---

## 13. Debug and Regression Tooling

Use debug scripts in `test/`:

```bash
lua54 test/debug_tokens.lua test.lua
lua54 test/debug_parser.lua test.lua
lua54 test/debug_ast.lua test.lua
lua54 test/debug_parse_suite.lua
lua54 test/debug_local_modes.lua
```

Fixtures:

- `test/fixtures/parser_ok.lua`
- `test/fixtures/parser_error.lua`
- `test/fixtures/local_modes.lua`

Recommended CI-style smoke sequence:

1. parser suite
2. local mode matrix
3. selected command smoke (`fom`, `coml`, `rename`, `nocode`, `lint`, `rrequire`, `preset`)

---

## 14. Extension Protocol

When adding a new command:

1. implement `src/<feature>.lua`
2. add module require in `main.lua`
3. add `process_file()` branch
4. add CLI parse + mode mapping
5. add report output contract if report-producing
6. wire safety expectations (parse/compile invariants)
7. add debug fixture and runner in `test/`
8. update `README.md` and this file

Preferred design policy:

- If semantics change, use AST + safety fallback
- If formatting/layout preservation is primary, use token/position rewrite

---

## 15. Known Risks and Technical Debt

1. `Analyzer` implementation has mismatches with current AST chunk shape and is not the primary authority in line-engine default flow.
2. `Transformer` AST mode has duplicated conditional branches and weaker parity with `TransformerLine` for all mode variants.
3. Lexer/parser are practical but not a formally complete Luau grammar.
4. Some command aliases (`localtur`) remain for compatibility and should be normalized/cleaned in future refactor.

Mitigation currently in place:

- command outputs are guarded by `Safety.guard`
- fallback to input on parse/compile regression
- debug scripts for parser and local-mode matrix

---

## 16. Quick Operational Checklist

Before release:

1. run parser suite
2. run local mode matrix
3. run representative command matrix on real scripts
4. confirm safety reports show `fallback_applied = false` for healthy paths
5. inspect lint/rrequire JSON shape compatibility
6. verify preset sequential overwrite semantics

This document should be treated as the authoritative architecture contract until the next implementation change.
