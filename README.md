# lua-local-deleted-tool

このツールは Lua ソースから特定の `local` キーワードを取り除き、元の空行・改行・インデント・コメントをできるだけ保持します。

主要ファイル
- `main.lua` — 既存の AST ベース処理と行ベース変換器の両方を切り替えて使えるメインランナー。
- `rewrite_main.lua` — 試作の行ベース専用ランナー（補助）。
- `src/transformer_line.lua` — 行ベースの変換器（トークンを参照して該当する `local` を削除）。
- `run_all_modes.lua` — 全モードを一括実行して差分レポートを作るスクリプト。

使い方（簡易）

1. 単一モードで実行（行ベース変換器を使う）

```bash
lua54 main.lua --engine=line functionlocal test.lua
```

2. `localkw`（`local` キーワードのみ削除、スコープ指定可）

```bash
lua54 main.lua --engine=line localkw test.lua
lua54 main.lua --engine=line localkw function test.lua
lua54 main.lua --engine=line localkw global test.lua
```

3. `functionlocal`（`local function` と `local name = function(...)` の `local` のみ削除。スコープ指定可）

```bash
lua54 main.lua --engine=line functionlocal test.lua        # both scopes (default)
lua54 main.lua --engine=line functionlocal function test.lua
lua54 main.lua --engine=line functionlocal global test.lua
```

4. 文字列代入の `local` を削除する `localcyt`（`local a = "b"` のようなケース）

```bash
lua54 main.lua --engine=line localcyt test.lua           # both scopes (default)
lua54 main.lua --engine=line localcyt function test.lua
lua54 main.lua --engine=line localcyt global test.lua
```

5. ブール代入の `local` を削除する `localtur`（`local a = true` / `false` を対象）

```bash
lua54 main.lua --engine=line localtur test.lua           # both scopes (default)
lua54 main.lua --engine=line localtur function test.lua
lua54 main.lua --engine=line localtur global test.lua
```

動作の注意:
- `localtur` は行全体を削除せず、該当する `local` キーワードのみを除去します。
- インデントとその他の式は維持されます（例: `local x = true` → `x = true`）。
- 期待される挙動を確認するためのテストファイル `bool_test.lua` をプロジェクトルートに追加しています。

3. 型指定（boolean/string）での削除

```bash
lua54 main.lua --engine=line localte function test.lua   # boolean の代入を対象
lua54 main.lua --engine=line localc global test.lua      # string の代入を対象
```

4. すべてのモードを一括実行して差分レポートを生成

```bash
lua54 run_all_modes.lua
```

出力
- 変換結果は `output/<inputfilename>` に書き出されます。
- `run_all_modes.lua` の場合は `reports/` 配下に各モードの差分 `*.diff` が作成されます。

注意点とTips
- デフォルトでは `main.lua` は AST ベースの変換パイプラインを保持していますが、`--engine=line` を付けると `src/transformer_line.lua`（行ベース）を使います。
- 行ベースの変換器はトークンに基づいて `local function name` や `local name = function(...)` を検出しますが、極端に複雑な式や複数行にまたがる宣言では誤検出することがあります。
- まずは `--engine=line` で出力を確認し、問題があればテスト用スクリプトや差分レポート（`reports/`）を参照してください。

さらに改善したい場合
- 匿名関数検出やブロック深度の判定をさらに厳密にしたい場合は `src/transformer_line.lua` を調整してください。

ライセンス
- 適宜プロジェクトに合わせて追加してください。
