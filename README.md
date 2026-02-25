# Kureha

Kureha は Ruby コードを minify するための Ruby gem です。`Prism` を使って Ruby をパースし、AST ベースで不要な空白や改行を削減します。

## Kurehaとは

- Ruby ソースコードを短くする minifier
- 構文を維持しながら空白・改行・コメントなどを削減することを目指す
- `Prism` によるパースを前提にした実装

## 目的

- Ruby コードを安全に minify できるようにする
- 「短くすること」よりも「元の処理を壊さないこと」を優先する
- 検証可能な基準（構文・実行結果・自己ホスト）を明文化して継続的に改善する

## 非目的（現時点で保証しないこと）

- すべての Ruby 構文の完全対応
- すべての Ruby バージョン差異を吸収した互換性保証
- 実行時間最適化
- 難読化
- `lib/**/*.rb` 以外（`exe/bin`, `test` など）を含む自己ホスト検証の網羅性保証

## 安全性の定義（初期版）

フェーズ1では、minify の安全性を次の条件で判定します。

- Minify 後コードが `Prism.parse` に成功すること（構文検証）
- 元コードと minify 後コードの実行結果が一致すること（差分実行検証）
- 比較項目は `stdout` / `stderr` / `exit status`

詳細は [docs/verification.md](docs/verification.md) を参照してください。

## 検証戦略の概要

- 既存 Minitest による文字列ベースの回帰テストを維持
- `test/fixtures/verification/` の小さな Ruby スクリプトを対象に差分実行検証を追加
- `lib/**/*.rb` を対象に自己ホスト検証を実装済み

## Installation

Bundler を使う場合:

```bash
bundle add kureha
```

Bundler を使わない場合:

```bash
gem install kureha
```

## 使い方

### ライブラリ API

```ruby
require "kureha"

source = <<~RUBY
  def hello(name)
    puts "Hello, #{name}"
  end
RUBY

minified = Kureha::Minifier.new.minify(source)
puts minified
```

### CLI

```bash
bundle exec ruby exe/ruby_minifier path/to/script.rb
```

インストール済み gem の実行ファイルを使う場合:

```bash
ruby_minifier path/to/script.rb
```

## 開発手順

```bash
bin/setup
bundle install
```

対話確認:

```bash
bin/console
```

## テスト / 検証コマンド

通常テスト:

```bash
bundle exec rake test
```

差分実行検証（fixtures）:

```bash
bundle exec rake verify:fixtures
```

自己ホスト検証（`lib/**/*.rb`）:

```bash
bundle exec rake verify:selfhost
```

総合検証（`test + verify:fixtures + verify:selfhost`）:

```bash
bundle exec rake verify
```

## 既知の制限

- AST visitor 実装が未対応の構文では正しく minify できない可能性があります
- 実行意味の同一性検証は現在 fixture ベースで、対象は限定的です
- CLI のヘルプ表示文言と実行ファイル名に差がある箇所があります

## ロードマップ

1. 差分実行検証の fixture を拡充する
2. 必要に応じて `exe/bin`, `test` へ自己ホスト検証対象を拡張する
3. CI に `rake verify`（または `verify:selfhost`）を統合する
4. 未対応構文の回帰 fixture を継続的に追加する

## Contributing

Issue / Pull Request は歓迎します。行動規範は [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) を参照してください。

## License

MIT License.

## Code of Conduct

このプロジェクトへの参加者は [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md) に従ってください。
