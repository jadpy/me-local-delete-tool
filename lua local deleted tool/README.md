# lua-local-deleted-tool

Luaソースコードから指定した `local` キーワードを削除するツールです。  
元のコードのインデント・空行・コメントをできるだけ保持しながら処理します。

## 🎯 主な用途

- **関数宣言の `local` 削除**: `local function foo()` → `function foo()`
- **代入式の `local` 削除**: 特定の型の代入のみをターゲット
  - テーブル: `local a = {}` → `a = {}`
  - 文字列: `local s = "text"` → `s = "text"`
  - ブール値: `local b = true` → `b = true`
- **コメントアウトコードの削除**: `--[[ ... ]]` 内のコード行を検出・削除

---

## 🚀 クイックスタート

### インストール

Lua 5.4 が必要です。以下のコマンドで実行可能です：

```bash
# 基本的な使用方法
lua54 main.lua <コマンド> [スコープ] <入力ファイル>
```

### 出力

入力ファイル: `test.lua`  
出力ファイル: `output/test.lua`

---

## 📋 コマンド一覧表

| コマンド | スコープ | 対象 | 例 |
|---------|---------|------|-----|
| `functionlocal` | ✅ | 関数宣言 | `lua54 main.lua functionlocal test.lua` |
| `localkw` | ✅ | すべての local | `lua54 main.lua localkw global test.lua` |
| `localtabke` | ✅ | テーブル初期化 | `lua54 main.lua localtabke function test.lua` |
| `localcyt` | ✅ | 文字列代入 | `lua54 main.lua localcyt test.lua` |
| `localte` | ✅ | ブール値代入 | `lua54 main.lua localte function test.lua` |
| `outcode` | ❌ | コメントアウトコード | `lua54 main.lua outcode test.lua` |

**✅ = スコープ指定可能 (デフォルト: 両方)**  
**❌ = スコープ指定不可**

---

## 📖 コマンド別クイックリファレンス

### `functionlocal` - 関数宣言の local を削除

```bash
lua54 main.lua functionlocal test.lua              # 両方のスコープ
lua54 main.lua functionlocal function test.lua     # 関数内のみ
lua54 main.lua functionlocal global test.lua       # グローバルのみ
```

### `localkw` - すべての local を削除

```bash
lua54 main.lua localkw test.lua                    # 両方のスコープ
lua54 main.lua localkw function test.lua           # 関数内のみ
lua54 main.lua localkw global test.lua             # グローバルのみ
```

### `localtabke` - テーブル初期化の local を削除 ⭐

```bash
lua54 main.lua localtabke test.lua                 # 両方のスコープ
lua54 main.lua localtabke function test.lua        # 関数内のみ
lua54 main.lua localtabke global test.lua          # グローバルのみ
```

### `localcyt` - 文字列代入の local を削除

```bash
lua54 main.lua localcyt test.lua                   # 両方のスコープ
lua54 main.lua localcyt function test.lua          # 関数内のみ
lua54 main.lua localcyt global test.lua            # グローバルのみ
```

### `localte` - ブール値代入の local を削除

```bash
lua54 main.lua localte test.lua                    # 両方のスコープ
lua54 main.lua localte function test.lua           # 関数内のみ
lua54 main.lua localte global test.lua             # グローバルのみ
```

### `outcode` - コメントアウトコードの削除

```bash
lua54 main.lua outcode test.lua
```

### エンジン指定（オプション）

```bash
# 行ベース処理（デフォルト・推奨）
lua54 main.lua localtabke test.lua

# 明示的に指定する場合
lua54 main.lua --engine=line localtabke test.lua

# AST ベース処理（フォールバック）
lua54 main.lua --engine=ast functionlocal test.lua
```

---

## 🔍 機能説明

### 1️⃣ `functionlocal` - 関数宣言の local を削除

**対象**:
- `local function name() ... end`
- `local name = function() ... end`

**変換例**:

```lua
-- 入力
local add = function(a, b)
  return a + b
end

function main()
  local helper = function(x) return x * 2 end
end

-- 出力（デフォルト）
add = function(a, b)
  return a + b
end

function main()
  helper = function(x) return x * 2 end
end
```

---

### 2️⃣ `localkw` - すべての local キーワードを削除

**対象**: すべての `local` 宣言

**変換例**:

```lua
-- 入力
local x = 10
local y = 20

function test()
  local a = 100
  local b = 200
end

-- 出力
x = 10
y = 20

function test()
  a = 100
  b = 200
end
```

---

### 3️⃣ `localtabke` - テーブル初期化の local を削除 ⭐ **新機能**

**対象**: テーブル代入のみ
- `local a = {}`
- `local config = {x = 1, y = 2}`

**削除されない例**:
- `local e = "string"` （文字列）
- `local f = 123` （数値）
- `local g = true` （ブール値）

**変換例**:

```lua
-- 入力
local config = {}
local colors = {red = 1, green = 2}

function init()
  local cache = {}
  local data = {a = 1}
end

local message = "hello"

-- 出力（全スコープ削除）
config = {}
colors = {red = 1, green = 2}

function init()
  cache = {}
  data = {a = 1}
end

local message = "hello"
```

**スコープ指定例**:

```lua
-- 入力
local config = {}

function init()
  local cache = {}
end

-- lua54 main.lua localtabke function test.lua
-- 出力（関数内のみ削除）
local config = {}

function init()
  cache = {}
end
```

---

### 4️⃣ `localcyt` - 文字列代入の local を削除

**対象**: 文字列値の代入のみ
- `local s = "text"`
- `local name = 'John'`

**削除されない例**:
- `local n = 42` （数値）
- `local t = {}` （テーブル）

**変換例**:

```lua
-- 入力
local greeting = "Hello"
local version = "1.0"

function getMessage()
  local msg = "Processing..."
  local error_text = "Error occurred"
  local count = 42
end

-- 出力（全スコープ削除）
greeting = "Hello"
version = "1.0"

function getMessage()
  msg = "Processing..."
  error_text = "Error occurred"
  local count = 42
end
```

---

### 5️⃣ `localte` - ブール値代入の local を削除

**対象**: ブール値（`true` / `false`）の代入のみ
- `local enabled = true`
- `local debug = false`

**削除されない例**:
- `local count = 10` （数値）
- `local data = {}` （テーブル）

**変換例**:

```lua
-- 入力
local debug_mode = true
local is_active = false

function setup()
  local initialized = true
  local ready = false
  local count = 10
end

-- 出力（全スコープ削除）
debug_mode = true
is_active = false

function setup()
  initialized = true
  ready = false
  local count = 10
end
```

---

### 6️⃣ `outcode` - コメントアウトコードの削除

**対象**:
- 単行コメント内のコード行: `-- local x = 10`
- ブロックコメント内のコード: `--[[ function() ... ]]`

**検出対象キーワード**: `local`, `function`, `=`, `return` など

**変換例**:

```lua
-- 入力
local x = 10
-- local old_code = 20
-- function deprecated() end
--[[ 
local unused_var = 30
function removed() end
]]
local y = 40

-- 出力
local x = 10
local y = 40
```

---

## 📊 スコープ指定について

ほとんどのコマンドで、削除対象を限定できます：

| オプション | 説明 | 削除対象 |
|-----------|------|---------|
| （なし）   | 両方のスコープ（デフォルト） | グローバル ＋ 関数内 |
| `function` | 関数内のみ | 関数内のみ |
| `global`   | グローバルスコープのみ | グローバル（トップレベル）のみ |

**使用例**:

```bash
# グローバルスコープのテーブル初期化のみ削除
lua54 main.lua localtabke global test.lua

# 関数内の文字列代入のみ削除
lua54 main.lua localcyt function test.lua

# 両方削除（デフォルト）
lua54 main.lua localtabke test.lua
```

---

## 💡 実践例・シナリオ

### シナリオ1: 関数を外部化する

**目的**: ローカル関数をグローバルに昇格

```lua
-- 元のコード
function module()
  local helper = function() return "help" end
  return helper()
end

-- 実行: lua54 main.lua functionlocal test.lua
-- 結果
function module()
  helper = function() return "help" end
  return helper()
end
```

### シナリオ2: グローバル変数の初期化をクリーンアップ

**目的**: グローバルテーブルのみクリーンアップ

```lua
-- 元のコード
local config = {version = "1.0"}
local active = true

-- 実行: lua54 main.lua localtabke global test.lua
-- 結果
config = {version = "1.0"}
local active = true
```

### シナリオ3: デバッグコードの削除

**目的**: コメント内のコード行を削除

```lua
-- 元のコード
local x = 10
-- local debug_x = x * 2
--[[ 
local old_version = "0.9"
function test() end
]]
local y = 20

-- 実行: lua54 main.lua outcode test.lua
-- 結果
local x = 10
local y = 20
```

### シナリオ4: 複数コマンドの組み合わせ

```bash
# 1. 関数宣言の local を削除
lua54 main.lua functionlocal source.lua

# 2. 出力をコピーして、次にグローバルテーブルをクリーンアップ
cp output/source.lua source2.lua
lua54 main.lua localtabke global source2.lua
```

---

## 🔧 入出力

### 入力形式

```bash
lua54 main.lua <コマンド> [スコープ] <入力ファイル>
```

| 部分 | 説明 |
|------|------|
| `<コマンド>` | `functionlocal`, `localkw`, `localtabke`, `localcyt`, `localte`, `outcode` |
| `[スコープ]` | 省略可。`function` または `global`（コマンドによって対応状況が異なる） |
| `<入力ファイル>` | Luaソースファイルパス |

### 出力形式

変換されたファイルは `output/` ディレクトリに保存されます：

```
output/<入力ファイル名>
```

**例**:
- 入力: `test.lua`
- 出力: `output/test.lua`

### ステータス出力

コマンド実行時、以下の情報が `stderr` に出力されます：

```
loading test.lua
mode: remove_local_table_all
scope: global

complete: output/test.lua

total local variables: 0
in functions: 0
global: 0
```

---

## ⚠️ トラブルシューティング

### Q: 想定と異なる行が削除されました

**A**: 行ベース処理では、複数行にまたがる複雑な式で誤検出する可能性があります。  
出力ファイル（`output/`）で確認して、必要に応じてコマンドを変更してください。

### Q: インデントが変わってしまった

**A**: 行ベースエンジンは元のインデントを保持します。AST エンジン（`--engine=ast`）を試してみてください。

### Q: コメント内の local も削除されてしまった

**A**: `outcode` コマンドはコメント内のコードを削除します。  
それ以外のコマンドではコメント内容は保持されます。

### Q: テーブル以外の代入も削除されてしまった

**A**: `localtabke` はテーブル初期化（`{}`）のみを対象としています。  
他の型（文字列・数値・ブール値）には反応しません。

### Q: 複数の異なる local を別のコマンドで処理したい

**A**: 出力ファイルを入力として再度処理できます：

```bash
lua54 main.lua functionlocal test.lua
cp output/test.lua test2.lua
lua54 main.lua localtabke test2.lua
```

---

## 🎓 内部構造（開発者向け）

### ファイル構成

```
.
├── main.lua                    # メインエントリーポイント
├── src/
│   ├── lexer.lua             # トークン化処理
│   ├── parser.lua            # AST解析
│   ├── analyzer.lua          # コード分析
│   ├── transformer.lua       # AST変換
│   ├── transformer_line.lua  # 行ベース変換（推奨）
│   ├── codegen.lua           # コード生成
│   └── ast.lua               # AST定義
├── output/                    # 出力先ディレクトリ
└── README.md                  # このファイル
```

### 処理フロー

#### 1. トークン化

`src/lexer.lua` がソースコードをトークンに分割します。

**例**: `local a = {}`

```
LOCAL → IDENT(a) → ASSIGN → LBRACE → RBRACE
```

#### 2. 行ベース変換（推奨エンジン）

`src/transformer_line.lua` がトークン列を参照しながら、削除対象の `local` を特定します。

**検出ロジック**:

```lua
-- テーブル初期化の検出
if valtok.type == 'LBRACE' then 
  remove = true
end

-- 文字列代入の検出
if valtok.type == 'STRING' then 
  remove = true
end

-- ブール値代入の検出
if valtok.type == 'TRUE' or valtok.type == 'FALSE' then 
  remove = true
end
```

#### 3. スコープ判定

```lua
-- 関数内か判定
local in_function = function_depth > 0

-- スコープに応じて削除判定
if mode == 'remove_local_table_function' then
  scope_ok = in_function
elseif mode == 'remove_local_table_global' then
  scope_ok = not in_function
end
```

#### 4. 出力生成

変換済みコードは行ごとに `replacements` テーブルに格納され、最終的に `output/` に書き込まれます。

### エンジン選択

| エンジン | 速度 | 精度 | インデント保持 | 推奨用途 |
|---------|------|------|---------------|---------|
| `line` | 高速 | 高 | ✅ | **通常の使用** |
| `ast` | 低速 | 最高 | △ | 複雑な構文の処理 |

---

## 📝 ライセンス

このプロジェクトはMITライセンス下で公開されています。

---

## 🤝 フィードバック

不具合や機能リクエストは、ログ出力（`stderr`）を参照して、  
テストケース（例: `test_localtabke.lua`）の出力と照合してください。
