# モデル設計ルール

## 基本方針: Fat Model / Thin Controller

- ビジネスロジックはモデルに集約する
- コントローラーにドメインロジックを書かない
- モデルに表現的なメソッドを持たせる（`user.follow(other)`, `user.profile_visible_to?(viewer)`）

## Concerns

- **「has trait / acts as」のセマンティクスがある場合のみ**使う
- 任意のコード分割コンテナとして使わない
- `extend ActiveSupport::Concern` + `included`ブロックで定義
- 配置: `app/models/concerns/`

## バリデーション

- 標準バリデーションマクロを優先（`validates :name, presence: true, length: { maximum: 50 }`）
- カスタムバリデーションは`validate :method_name`で独立メソッドに切り出す
- 再利用可能なバリデータは`app/validators/`にクラスとして分離
- エラーメッセージは日本語（`errors.add(:base, '打撃成績が未入力です')`）

## enum / scope / delegate

- enumは整数マッピング: `enum status: { pending: 0, accepted: 1 }`
- scopeはラムダ形式: `scope :active, -> { where(active: true) }`
- `delegate :count, to: :following, prefix: true` で委譲パターンを活用

## コールバック

- **最小限に抑える** — 暗黙の副作用はバグの温床
- 外部サービス呼び出しは`after_commit`でサービスに委譲: `after_commit :notify_slack, on: :create`
- コールバック内に複雑なロジックを書かない

## クエリ

- 複雑なクエリはクラスメソッド（`self.aggregate_for_user`）で管理
- ソート可能カラムは`SORTABLE_COLUMNS`定数で許可リスト管理
