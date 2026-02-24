# 検証方針（フェーズ1 / フェーズ2）

## 検証の目的と成功条件

Kureha の目的は Ruby コードを短くすることではなく、元の処理を壊さずに minify することです。

フェーズ1の成功条件:

- Minify 後コードが `Prism.parse` に成功する
- 元コードと minify 後コードの `stdout` / `stderr` / `exit status` が一致する
- 既存の文字列ベース回帰テストが通る

フェーズ2の成功条件:

- フェーズ1の条件を満たす
- `lib/**/*.rb` を対象に自己ホスト検証が通る

## 差分実行検証の比較項目

対象は `test/fixtures/verification/` に配置した決定論的な Ruby スクリプトです。

各 fixture について次を行います。

1. 元コードを別プロセスで実行する
2. `Kureha::Minifier` で minify する
3. Minify 後コードが `Prism.parse` に成功することを確認する
4. Minify 後コードを別プロセスで実行する
5. 以下を比較する

- `stdout`
- `stderr`
- `exit status`

実行は `Open3.capture3` を使い、タイムアウトを設定します（既定 5 秒）。

## 構文検証の比較項目

フェーズ1の構文検証は次を満たすことです。

- `Kureha::Minifier#minify` が例外なく文字列を返す
- Minify 後コードに対して `Prism.parse(...).failure?` が `false` である

構文検証は意味同一性の保証ではなく、差分実行検証と組み合わせて使います。

## フィクスチャ作成ルール（決定論的コードのみ）

- 1 ファイル 1 シナリオを基本とする
- 意図がファイル名で分かるようにする
- 外部 I/O に依存しない
- 実行結果が環境や時間で変わらない
- 可能な限り小さくする

初期対象:

- `puts`
- 複数文とセミコロン挿入
- `if` / `unless`（modifier form を含む）
- `do ... end` ブロック
- 文字列補間
- 演算子優先順位
- `require` / `require_relative`
- `return`
- `case` / `when`
- 正規表現リテラル
- magic comment

## 除外ルール（時間・乱数・環境依存・外部I/O）

フェーズ1の fixture には次を含めません。

- `Time.now`, `Date.today` など時刻依存
- `rand` など乱数依存
- ネットワークアクセス
- 外部コマンド実行
- 環境変数やカレントディレクトリ前提の振る舞い
- ファイルシステムの状態に依存する振る舞い（fixture 内で閉じる場合を除く）

## 失敗時の切り分け手順

1. 元コードと minify 後コードの差分を確認する
2. Minify 後コードを単独で `Prism.parse` する
3. `stdout` / `stderr` / `exit status` のどれが不一致か確認する
4. AST visitor の該当ノード処理を確認する
5. 再現 fixture を最小化して回帰テストに追加する

## 自己ホスト検証の仕様（実装済み）

`rake verify:selfhost` で `lib/**/*.rb` を対象に自己ホスト検証を実行します。

### 対象範囲

- `lib/**/*.rb`

### 検証内容

1. 対象ファイルを minify する
2. 元の相対パス構造のまま一時ディレクトリへ出力する
3. 出力した全ファイルが `Prism.parse` に成功することを確認する
4. 一時ディレクトリの `lib` を `LOAD_PATH` に追加して `require "kureha"` する
5. `Kureha::Minifier.new.minify("x = 1 + 2\nputs x\n")` を実行し、異常終了しないことを確認する
6. `stdout` / `stderr` / `exit status` を検証する

### 将来拡張

- `exe/`, `bin/`
- `test/`
- CI への自己ホスト検証統合
