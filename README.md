# Architecture / 内部仕様（詳細版）

このドキュメントは、`lua-local-deleted-tool` の **実装準拠の技術資料** です。  
「何をしているか」だけでなく、「どのファイルが、どの順で、どこまで安全に処理するか」を追える形で記載します。

---

## 0. 目的と読み方

目的:

- 機能追加時に、既存処理を壊さず拡張できるようにする
- 不具合調査時に、処理境界（Lexer / Parser / Formatter / Compressor など）を即特定できるようにする
- コマンドごとの安全性レベル（構文検証・コンパイル検証・フォールバック）を明確にする

読み方:

1. まず「1. ディレクトリと責務」を確認
2. 次に「2. CLIフロー」でコマンド分岐を確認
3. 個別機能は該当セクション（`fom`, `coml`, `nmbun`, `rename`, `deleteout`, `nocode`, `lint`, `rrequire`, `preset`）を参照

---

## 1. ディレクトリと責務

主要ファイル:

- `main.lua`: CLI引数解釈、コマンド分岐、入出力、出力先管理
- `src/lexer.lua`: AST処理向けトークナイザ（コメント/改行は基本捨てる）
- `src/lexer_full.lua`: フォーマット/圧縮/コメント削除向け高忠実度トークナイザ（`newline`, `comment` を保持）
- `src/parser.lua`: 再帰下降パーサ、AST構築
- `src/ast.lua`: ASTノード定義
- `src/analyzer.lua`: スコープ/参照解析（統計用途含む）
- `src/transformer.lua`: ASTベース local 変換
- `src/transformer_line.lua`: 行ベース変換（既定エンジン）
- `src/codegen.lua`: AST -> コード再生成
- `src/formatter.lua`: 整形器（`fom`）
- `src/optimizer.lua`: 定数畳み込み/簡約/不要文除去（保守的）
- `src/compressor.lua`: 圧縮器（`coml`）
- `src/nmbun.lua`: 計算式簡約器（`nmbun`）
- `src/deleteout.lua`: 高精度コメント削除（`deleteout`）
- `src/renamer.lua`: ローカル識別子リネーム（`rename`）
- `src/nocode.lua`: 未使用ローカル削除（`nocode`）
- `src/linter.lua`: 静的解析（`lint`）
- `src/rrequire.lua`: require依存解析（`rrequire`）
- `src/preset.lua`: JSONプリセット段階実行（`preset`）
- `src/safety.lua`: 全コマンド共通の安全チェック（parse/compile/lint要約、フォールバック判定）

---

## 2. CLIフロー（`main.lua`）

大まかな流れ:

1. 引数解析（`--engine=` は AST/line 系のみ有効）
2. `mode_name` を内部 `mode` へマッピング
3. `process_file` でコマンド別実行
4. `output/<入力名>` に書き出し

### 2-1. コマンド種別

専用処理コマンド（`--engine` 非依存）:

- `fom`
- `coml`
- `nmbun`
- `rename`
- `deleteout`
- `nocode`
- `lint`
- `rrequire`
- `preset`

`local` 削除系（`--engine=line|ast` の対象）:

- `functionlocal`
- `localkw`
- `localte`
- `localc` / `localcyt`
- `localtabke`
- `outcode`

### 2-2. 出力整形の最終処理

`main.lua` は書き込み直前に改行トリムを行うが、以下モードはトリム対象外:

- `rename`
- `deleteout`
- `nocode`
- `lint`
- `rrequire`
- `preset`

理由: これらは「レイアウト保存寄り」または「置換精度」優先のため。`preset` は内部ステップの状態を維持するため、改行トリムを行わない。

---

## 3. データモデル

## 3-1. トークン（`src/lexer.lua`）

形:

- `type`（例: `LOCAL`, `IDENT`, `ASSIGN`）
- `value`
- `line`
- `col`

特徴:

- 空白/コメントは基本スキップ
- 文字列はエスケープ解釈して `STRING` へ
- 数値は `tonumber` 済み `NUMBER` へ
- AST構築に必要な情報だけ保持

## 3-2. トークン（`src/lexer_full.lua`）

形:

- `type`: `keyword`, `ident`, `number`, `string`, `long_string`, `symbol`, `comment`, `newline`
- `value`, `line`, `col`
- 追加属性（例: comment の `is_block`）

特徴:

- `newline` を保持する
- `--` と `--[[...]]` を区別して保持する
- 長括弧文字列 `[=[...]=]` を保持する
- 連続記号（`..`, `...`, `::`, `+=` 等）を symbol として扱う

用途:

- `formatter`, `compressor`, `deleteout` で使用

## 3-3. AST（`src/ast.lua`）

代表ノード:

- 文: `LocalDecl`, `LocalFunc`, `FunctionDecl`, `Assignment`, `If`, `While`, `Repeat`, `For`, `ForIn`, `Do`, `Return`, `Break`
- 式: `Identifier`, `BinaryOp`, `UnaryOp`, `FunctionCall`, `MethodCall`, `IndexExpr`, `PropertyExpr`, `Table`
- リテラル: `Number`, `String`, `Boolean`, `Nil`, `VarArgs`

補助メタ情報（Parserが一部付与）:

- `source_line`
- `name_token`, `name_tokens`
- `param_tokens`
- `var_token`, `var_tokens`

これらは `rename` や部分再出力で利用される。

---

## 4. Parser詳細（`src/parser.lua`）

方式:

- 再帰下降パーサ
- `parse_chunk` -> `parse_statement` -> 式パーサ

### 4-1. 対応文

- `local` 宣言 / `local function`
- `function ... end`
- `if / elseif / else / end`
- `while / repeat / until / for / do`
- `return`
- 代入文 / 呼び出し文

### 4-2. 式優先順位

上位 -> 下位:

1. `or`
2. `and`
3. `not`（単項）
4. 比較 (`< <= > >= == ~=`)
5. 連結 (`..`)
6. 加減 (`+ -`)
7. 乗除 (`* / // %`)
8. 単項 (`- not #`)
9. べき (`^`, 右結合)
10. postfix（呼び出し、添字、プロパティ、メソッド）

### 4-3. テーブル構文

- `[expr] = value`
- `ident = value`（内部的に `AST.String(key)` へ）
- 配列風 `value`

### 4-4. 注意点

- 対応優先は Lua 5.1 系記法
- `lexer_full` 側と完全同一トークン体系ではない（用途分離）

---

## 5. Analyzer詳細（`src/analyzer.lua`）

役割:

- スコープ木を作り、ローカル参照数を数える
- 統計レポート用 `all_locals` を作る

主要概念:

- `Scope.new(parent)`
- `declare(name)`
- `reference(name)`（親に再帰探索）

出力活用:

- CLI完了時の `total / in functions / global` 表示

設計意図:

- 厳密な最適化器というより「安全な削除判断の下支え」

---

## 6. Transformer（AST変換）

## 6-1. `src/transformer.lua`

用途:

- `local` 削除系モードを AST 上で実装

処理:

- ノードを再帰的に走査
- 対象 `LocalDecl` を `Assignment` へ変換
- 対象 `LocalFunc` を `FunctionDecl` へ変換
- `source_line`/`modified` を引き継ぎ

スコープ判定:

- `in_function` と `function_depth` で関数内/外を分ける

## 6-2. `src/transformer_line.lua`

用途:

- 既定 `--engine=line` の実編集
- 元行構造維持を重視

特徴:

- トークン行位置を使って `local` 部分をピンポイント削除
- `outcode` モードは行ベースでコメントアウトされたコードを除去

注意:

- 行ベース処理は文脈保持に強いが、AST変換ほど構文意味を厳密には追わない

---

## 7. CodeGen詳細（`src/codegen.lua`）

役割:

- AST を Lua コードへ再生成

動作モード:

- `CodeGen.new(source)` で元ソース照合型
- `CodeGen.new(nil)` で純生成型（`coml`, `nocode` で利用）

特徴:

- `source_lines` がある場合、同一文のインデントを寄せる
- `generate_chunk` は `modified` ノード行を置換し、未変更行を保持

トレードオフ:

- 保守性重視で、最短コード化は目的外（それは `compressor` 側）

---

## 8. Formatter詳細（`src/formatter.lua` / `fom`）

処理モデル:

- `lexer_full` でトークン列化
- 改行とインデントを再構成
- コメントは行単位で保存

### 8-1. インデント推定

- 入力の先頭空白を走査
- タブ優勢なら `\t`
- スペース優勢なら GCD から単位幅推定
- 推定不能時は4スペース

### 8-2. 空白挿入ロジック

中核:

- `needs_space(prev, next)`

主な保護:

- 単語同士の結合防止
- `number` + `.` の誤結合防止
- `..`, `...`, `::` 等の誤融合防止
- 二項演算子前後の自然な空白

### 8-3. 改行ロジック

- `then`, `do`, `repeat`, `end`, `elseif`, `else`, `until` でデント制御
- 文境界検知で改行
- トップレベルでは可読性のため空行を補助的に挿入

### 8-4. UIテーブル整形

`should_expand_call_table` で次を検知すると `{ ... }` を展開:

- 名前付きフィールド
- callback `function` を含む
- 既に改行を含む

効果:

- Roblox UI定義（Orion系を含む）で読みやすい複数行構造を作りやすい

---

## 9. Optimizer詳細（`src/optimizer.lua`）

役割:

- ASTの保守的最適化

主処理:

- 定数畳み込み（算術/比較/論理）
- 単項簡約（`not`, 数値 `-`, 文字列 `#`）
- `if true/false` のブランチ簡約
- `while false` 削除
- 空 `do ... end` 削除
- `return` / `break` 後の文を切り捨て

方針:

- 破壊的最適化より安全性を優先

---

## 10. Compressor詳細（`src/compressor.lua` / `coml`）

`coml` は「最適化 + ミニファイ + 検証 + フォールバック」の構成。

### 10-1. フェーズ1: AST最適化（任意）

- `can_parse_with_ast(source)` が真なら:
  1. `lexer` -> `parser` -> `optimizer`
  2. `codegen` で一度コード化

### 10-2. フェーズ2: トークン圧縮

- `lexer_full` トークンを1本に連結
- `comment/newline` を除去
- 必要なら文境界 `;` を挿入
- 既存 `;` はトップレベルで除去

### 10-3. 連結事故対策

- `needs_space` で複合トークン化事故を回避
- `- -1` が `--1` へ化けるケースを `force_space_for_minus` で保護

### 10-4. 検証とフォールバック

候補順:

1. 最適化版を圧縮した候補
2. 元ソース直接圧縮候補

各候補を以下で検証:

- `lexer_full` で再トークン化可能か
- 元がコンパイル可能なら候補もコンパイル可能か
- 元がコンパイル不可だが AST parse 可能なら、候補も parse 可能か

失敗時:

- 次候補へ
- 全滅時は **元ソースをそのまま返す**

---

## 11. DeleteOut詳細（`src/deleteout.lua` / `deleteout`）

目的:

- コメントのみを高精度に除去し、コード本体を壊さない

方式:

1. `lexer_full` で `comment` トークン位置を取得
2. 元文字列の byte 範囲で置換
3. コメント内部改行は保持（行崩れ防止）
4. 前後トークン連結で危険なら空白1個を補う

対象:

- 行コメント `-- ...`
- ブロックコメント `--[[ ... ]]`

---

## 12. Renamer詳細（`src/renamer.lua` / `rename`）

目的:

- ローカル変数名の短縮・ランダム化
- 宣言と参照を整合したまま置換
- 行数/空白/インデントはできるだけ維持

### 12-1. 名前生成戦略

- 1文字名を優先（`a-z`, `A-Z`, `_`）
- 衝突時は2文字以上へ拡張
- 長さごとにランダム開始位置 + 互いに素ステップで巡回
- 予約語と既使用名を回避

### 12-2. スコープ追跡

- `new_scope(parent)` で字句スコープを形成
- `scope_lookup` で参照時に外側へ解決

### 12-3. 置換対象

- `LocalDecl` 変数
- `LocalFunc` 名
- 関数引数
- `for` / `for in` 変数
- 対応参照ノード

### 12-4. 置換適用方式

- トークン行列位置から byte span へ変換
- 末尾側から逆順適用（オフセットずれ防止）

重要:

- `rename` は **再フォーマットしない**
- 「見た目維持 + 名前だけ変更」が基本仕様

---

## 13. NoCode詳細（`src/nocode.lua` / `nocode`）

目的:

- 未使用ローカル関連コードを安全側で除去

処理:

1. `lexer` + `parser` で AST化
2. `optimizer` で簡約
3. 解析 + 削除を反復（最大20回）
4. `codegen` で再出力

削除条件:

- 未参照 `LocalFunc` は削除
- `LocalDecl` は「宣言全体が未参照」かつ「初期化式が副作用なし」のとき削除

副作用判定:

- `Number/String/Boolean/Nil/Identifier/VarArgs` は純粋
- `Unary/Binary/Table/Function` は再帰的に純粋判定
- 呼び出し系などは純粋扱いしない（削除しない）

安全ガード:

- 元が parse/compile 可能なら、候補も同等条件を満たすか確認
- 失敗時は元ソースへフォールバック

---

## 13-1. Linter詳細（`src/linter.lua` / `lint`）

目的:

- 実行前にコード品質問題を検出し、レポート化する

検出カテゴリ:

- `unused-variable`: 未使用ローカル/引数/for変数/ローカル関数
- `undefined-reference`: 未定義参照（既知グローバルは除外）
- `type-mismatch`: 算術/連結/再代入時の型不一致ヒント
- `useless-expression`: 副作用のない式文

実装方針:

- `lexer` + `parser` で AST 化
- `linter` 内部スコープ解析で参照数と簡易型情報を追跡
- 到達不能コード、グローバル代入、非関数呼び出しも検出
- 入力コード本体は変更せず、`output/<input>.lint.json` にレポート出力

---

## 13-2. RRequire詳細（`src/rrequire.lua` / `rrequire`）

目的:

- `require(...)` 依存関係をファイル単位で可視化する

処理:

1. エントリーファイルを AST 解析
2. `require(\"...\")` 呼び出しを抽出
3. モジュール名を候補パス（`x.lua`, `x/init.lua`）へ解決
4. 解決できた依存を再帰追跡

出力:

- 依存エッジ一覧
- 未解決 require
- 動的 require（文字列リテラル以外）
- 解析エラー
- 依存サイクル

補足:

- `local rq = require` のようなエイリアス呼び出しを追跡
- `pcall(require, \"...\")` / `xpcall(require, ..., \"...\")` を検出

入力コード本体は変更せず、`output/<input>.rrequire.json` にレポート出力。

---

## 13-3. Preset詳細（`src/preset.lua` / `preset`）

目的:

- 複数コマンドを JSON 定義で段階実行する
- 同じ処理パイプラインを再現しやすくする

入力:

- `lua54 main.lua preset <inputfile> [presetfile]`
- 既定プリセット: ルートの `preset.json`

JSON 仕様（主要項目）:

- `version`: 数値（任意）
- `name`: 文字列（任意）
- `engine`: 既定エンジン（任意、`line`/`ast`）
- `write_step_outputs`: 各ステップ中間ファイル保存（既定: false）
- `stop_on_error`: ステップ失敗時に停止（既定: true）
- `steps`: 配列（必須）
- `steps[].mode`: 実行モード（必須）
- `steps[].scope`: スコープ（任意）
- `steps[].engine`: ステップ単位エンジン上書き（任意）
- `steps[].enabled`: false でスキップ（任意）

処理:

1. `preset.json` を `Json.decode` で読み込み
2. `steps` を上から順に実行
3. 各ステップ結果を次ステップへ上書きで引き継ぐ
4. 最終結果を `output/<input>` に保存
5. 実行レポートを `output/<input>.preset.json` に保存
6. `write_step_outputs: true` の場合のみ中間成果物を `output/preset_steps/` に保存

出力:

- 最終出力: `output/<input>`
- レポート: `output/<input>.preset.json`
- 中間出力: `output/preset_steps/<input>.stepXX_<name>.lua`

---

## 14. コマンド別安全性マトリクス

- 共通: `main.lua` の `process_file` は全モードで `src/safety.lua` を通し、`output/<file>.safety.json` を生成
- `fom`: lexer_full ベース整形、構文意味変更を避ける保守的空白制御
- `coml`: トークン検証 + 条件付き parse/compile 検証 + フォールバック
- `deleteout`: コメント位置置換 + 連結保護スペース
- `rename`: AST解決 + 位置置換、レイアウト非破壊
- `nmbun`: AST最適化（定数畳み込み）を反復適用して簡約
- `nocode`: 未使用判定 + 副作用判定 + parse/compile 検証
- `lint`: 静的検出のみ（コード非改変、レポート出力）
- `rrequire`: 依存追跡のみ（コード非改変、レポート出力）
- `preset`: JSON定義の段階実行 + ステップ別成果物/レポート

---

## 15. 既知の制約

- 主要ターゲットは Lua 5.1 系 + Luau 実用構文
- `lexer` と `lexer_full` は目的別で、完全同一挙動ではない
- `transformer_line` は高速/非破壊寄りだが、AST意味解析ほど厳密ではない
- `optimizer` は安全側のため、攻めた最適化（高度DCE/高度定数伝播）は未実装

---

## 16. 不具合調査の導線

現象別の最短確認ポイント:

- 構文エラーが出る: `src/compressor.lua` の `needs_space` / 文境界 `;` / 検証分岐
- local削除スコープ誤判定: `src/transformer_line.lua` の ASTベース判定と `local_token` 位置解決
- 整形崩れ: `src/formatter.lua` の `needs_space`, `should_expand_call_table`, デント更新
- 参照が壊れる: `src/renamer.lua` の scope 追跡と replacement span
- コメント削除後に壊れる: `src/deleteout.lua` の `needs_space(prev, nxt)` 判定
- 未使用削除が強すぎる/弱すぎる: `src/nocode.lua` の `is_pure_expr` と `analyze_ast`
- lint誤検知/漏れ: `src/linter.lua` のスコープ解決と簡易型推論
- 依存解決ミス: `src/rrequire.lua` の module path 解決規則

---

## 17. 新コマンド追加の実装ガイド

実装手順:

1. `src/<new>.lua` を作成（`function <Mod>.<entry>(source)`）
2. `main.lua` に `require` 追加
3. `process_file` に分岐追加
4. 引数解析と `mode` マッピング追加
5. `README.md` と本書更新

推奨ルール:

- レイアウト維持が必要な処理は「位置置換方式」を優先
- 意味変更を伴う処理は AST + 検証 + フォールバックを必ず付ける

---

## 18. 回帰確認コマンド

最小チェック:

```bash
lua54 main.lua fom test.lua
lua54 main.lua coml test.lua
lua54 main.lua nmbun test.lua
lua54 main.lua rename test.lua
lua54 main.lua deleteout test.lua
lua54 main.lua nocode test.lua
lua54 main.lua lint test.lua
lua54 main.lua rrequire test.lua
lua54 main.lua preset test.lua
lua54 tests/run_all_commands.lua
lua54 tests/local_precision.lua
```

構文確認例:

```bash
lua54 -e "assert(loadfile('output/test.lua'))"
```

---

## 19. 改訂メモ

この詳細版は、現行コード（`main.lua`, `src/*.lua`）の実装を再スキャンして作成。  
今後、パーサ拡張や最適化強化を行う場合は、まず本書の「15. 既知の制約」と「17. 新コマンド追加ガイド」を更新してから実装すると、保守負荷を下げられます。
