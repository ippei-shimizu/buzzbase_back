# BUZZ BASE バックエンド

Rails API アプリケーション。

## 技術スタック

- **Ruby**: 3.2.2
- **Rails**: 7.1.x（API モード）
- **DB**: PostgreSQL 15.5
- **認証**: devise_token_auth（access-token, client, uid ヘッダー）
- **シリアライザ**: active_model_serializers
- **Linter**: RuboCop（rubocop-rails, rubocop-rspec, rubocop-performance）

## 開発コマンド（Docker経由）

すべてのコマンドはプロジェクトルートから `docker compose exec back` 経由で実行する。

```bash
docker compose exec back bundle exec rails console  # Railsコンソール
docker compose exec back bundle exec rails db:migrate  # マイグレーション実行
docker compose exec back bundle exec rails db:seed  # シードデータ投入
docker compose exec back bundle exec rails routes  # ルーティング確認
```

## テスト

```bash
docker compose exec back bundle exec rspec  # 全テスト実行
docker compose exec back bundle exec rspec spec/requests/  # リクエストスペックのみ
docker compose exec back bundle exec rspec spec/models/  # モデルスペックのみ
docker compose exec back bundle exec rspec <ファイルパス>  # 特定ファイル実行
```

## Lint

```bash
docker compose exec back bundle exec rubocop  # チェック
docker compose exec back bundle exec rubocop -A  # 自動修正
```

## コメント規約

- **コードを読めばわかること（WHAT）は書かない**。識別子・型・処理の流れはコード自身が語る。コメントが繰り返すと冗長になり、コード変更時に陳腐化する
- **コードからは読み取れない意図・前提・制約（WHY）だけを書く**。例: 性能上の理由で `pluck` を使っている / 仕様で空配列を許容しない / フロントの期待形式に合わせて〜している、など
- **issue 番号 / PR 番号 / ticket URL をコメントに書かない**。時間と共に陳腐化し、リーダーにとってノイズになる。経緯や参照リンクは PR description やコミットメッセージに残す
  - NG: `# 二重作成を防ぐ（issue #341）`
  - NG: `# ユーザーを取得する`（コードを見れば明らか）
  - OK: `# devise_token_auth の挙動上、create 時に session を残すと次回ログインで衝突する`
- yardoc (`@param` / `@return` / `@example`) は「責務」「引数・返り値の意味」を簡潔に書いてよい（保守性向上の資産として残す）

## ディレクトリ構造

```
app/
├── controllers/api/v1/  # APIエンドポイント（v1, v2）
│   └── api/v2/
├── models/              # ActiveRecordモデル
├── serializers/         # レスポンスJSON整形
├── services/            # ビジネスロジック
├── validators/          # カスタムバリデーション
├── uploaders/           # ファイルアップロード
└── jobs/                # バックグラウンドジョブ
spec/
├── requests/            # APIリクエストスペック
├── models/              # モデルスペック
├── services/            # サービススペック
├── serializers/         # シリアライザスペック
└── factories/           # FactoryBot定義
```
