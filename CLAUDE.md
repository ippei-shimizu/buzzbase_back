# BUZZ BASE バックエンド

Rails API アプリケーション。

## 技術スタック

- **Ruby**: 3.2.2
- **Rails**: 7.0.x（API モード）
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
