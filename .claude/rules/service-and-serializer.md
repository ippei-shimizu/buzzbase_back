# サービスオブジェクト / シリアライザ ルール

## サービスオブジェクト

### 状態を持つサービス — `initialize` + `call` パターン

```ruby
class Stats::BattingAggregator
  def initialize(user:, year: nil)
    @user = user
    @year = year
  end

  def call
    # 処理
  end
end
```

### 状態を持たないサービス — クラスメソッド

```ruby
class PushNotificationService
  class << self
    def send_to_user(user, title:, body:)
      # 処理
    end
  end
end
```

### 規約

- Stats系は`Stats::`名前空間 + `TableServiceConcern`で共通ロジック（`safe_divide`, `scope_for_year`）を共有
- エラーハンドリング: カスタム例外クラスを内部定義（`class InvalidToken < StandardError; end`）
- ビジネスロジックがモデルに収まるならサービスに切り出さない（Fat Model優先）

## シリアライザ

- `ActiveModel::Serializer`を継承
- v2は`V2::`名前空間、Adminは`Admin::`名前空間
- ネストしたリソースは`has_one` / `has_many`で定義してN+1を回避
- 日付フォーマットはシリアライザ内で変換: `object.published_at&.strftime('%Y-%m-%d')`
- v1のas_json直接返却パターンは新機能では使わない
