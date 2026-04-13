# Ruby / Rails 全般ルール

## 設計原則

- **Rails標準機能を最大限活用する** — 外部gemの追加は最後の手段。Rails本体で解決できないか先に検討する
- メタプログラミングを避ける — 2-3ケースなら`case`文で十分
- 明示的なコードを書く — マジックより可読性を優先

## パフォーマンス

- `pluck(:field)` を `.map(&:field)` より優先
- N+1クエリを避ける — `includes` / `preload` を使う
- 大量レコードは `find_each` / `in_batches` で処理

## コーディングスタイル

- RuboCop準拠（`Layout/LineLength: 140`, `Metrics/MethodLength: 30`）
- クラスコメント不要（`Style/Documentation: Disabled`）
- `frozen_string_literal`コメントは既存ファイルに合わせる（強制しない）
- 定数は`FREEZE`する（`SORTABLE_COLUMNS = {...}.freeze`）

## セキュリティ

- SQLインジェクション対策: 許可リスト方式 + `Arel.sql`で安全な生SQL
- パラメータは`Strong Parameters`で絞る
- ユーザー入力を直接SQLに渡さない

## 開発環境

- コマンドはDocker経由: `docker compose exec back bundle exec ...`
- マイグレーション: `docker compose exec back bundle exec rails db:migrate`
- テスト: `docker compose exec back bundle exec rspec`
- Lint: `docker compose exec back bundle exec rubocop`
