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

### 既存モデルへ後から制約を足すとき

既存レコードが制約違反のまま残るため、次の3点を必ず確認する。

1. **その属性を変更しない更新で発火しないか** — `if: :note_changed?` や `on: :create` で既存データを grandfather する。しないと、ユーザーが無関係な項目を更新しただけで422になる
2. **ユーザーが値を直す経路があるか** — strong params が当該属性を除外していると（例: `update_params` に `metric_key` が無い）、修復手段が無く完全に詰む
3. **一括処理が1件の失敗で止まらないか** — `find_each` + `update!` のバッチに rescue が無いと、1件の不正データで全ユーザーの処理が停止する

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

## find_or_create の競合対策

同時実行の重複対策は、レビューで繰り返し指摘が出ている箇所なので以下を定型とする。

- **update パスと create パスの両方**を見る。「既存行があれば更新」に `with_lock` を入れても、`find_by` が nil を引く create パスは無防備。DB の一意制約（部分インデックス可）+ `rescue ActiveRecord::RecordNotUnique` で塞ぐ
- 外側にトランザクションがある場合は `ActiveRecord::Base.transaction(requires_new: true)` のセーブポイントで囲む。囲まないと PostgreSQL がトランザクション全体を aborted にし、rescue 節の復旧クエリ自体が落ちる
- **勝者の引き直しには所有者スコープを掛ける**（`current_api_v1_user.match_results.find_by(...)`）。一意インデックスが所有者カラムを含まない単独キーだと、`Model.find_by(key)` は他ユーザーの行を勝者として返し 201 で中身ごと流出する。スコープを掛けて引けないときは `raise` して 409 に倒す
- 一意制約の rescue がある箇所へ**同条件のモデルバリデーションを後から足すときは注意**。先行トランザクションがコミット済みだと INSERT に到達せず `RecordInvalid` が飛び、既存の rescue をすり抜けて 500 になる。rescue を両方の例外に広げ、引き直しに失敗したら `raise` で投げ直す
