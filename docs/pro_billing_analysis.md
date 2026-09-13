# Pro 課金分析の前提と運用

課金指標（MRR / トライアル転換率 / 解約）を実態と合わせるためのルールと手順。

分析クエリは `back/tmp/pro_analysis.sql` に置いていたが、`tmp/` は gitignore 対象で共有できないため、この
ドキュメントに集約する。

## 手動付与は `internal_grant` で判別する

録画・審査・開発のために手動で Pro 化したアカウントは、`subscriptions.internal_grant` を `true` にし、
`internal_grant_reason` に目的を書く。課金分析はこのフラグが `false` のレコードだけを母数にする。

`started_at` が null のものを手動付与とみなす運用は採用しない。webhook の取りこぼしや RevenueCat 側の
データ欠損でも null になりうるため、意図的な付与と区別できないため。

- `Subscription.billable` — 実課金のみ（分析の母数）
- `Subscription.internal_grants` — 内部付与のみ

手動付与ユーザーが実際にストア課金へ切り替わった場合は `pro:unmark_internal` でフラグを外す。付与を取り消して
free に戻した後もフラグと理由は残す（過去の指標からも除外し続けるため）。

## 分析から除外する内部アカウント

本番 `users.id`。フラグの実体は DB 側にあるので、最新の一覧は `pro:audit` の出力を正とする。

| users.id | 除外理由 |
| --- | --- |
| 19 | 録画用の手動 Pro 化 |
| 3467 | 手動 Pro 付与 |
| 1059 | ストア審査用アカウント |
| 4 | 開発者本人のアカウント |
| 3031 | 課金情報なし（内部利用） |
| 6 | 課金情報なし（内部利用） |

## 運用コマンド

Heroku での実行はユーザー自身が行う（`heroku run rake "..." -a <アプリ名>`）。ローカルは
`docker compose exec back bundle exec rake "..."`。

```bash
# free 以外の契約を実課金 / 内部付与に分けて一覧表示する
rake pro:audit

# 内部付与としてマークする（第2引数は理由。必須）
rake "pro:mark_internal[19,録画用]"

# 実課金へ切り替わったアカウントのフラグを外す
rake "pro:unmark_internal[19]"

# 録画・審査が終わった手動付与を free に戻す（internal_grant のレコードのみ対象）
rake "pro:revoke_internal_grant[19]"
```

`pro:audit` は `started_at` が null なのに `internal_grant` が付いていないレコードを「要確認」として出力する。
手動付与のフラグ漏れはここで気付ける。

## 分析クエリ

いずれも `internal_grant = false` で内部付与を除外する。

### 現在の課金状況

```sql
SELECT s.id, s.user_id, u.user_id AS handle, s.status, s.plan_type, s.platform, s.started_at, s.expires_at
FROM subscriptions s
JOIN users u ON u.id = s.user_id
WHERE s.status <> 'free'
  AND s.internal_grant = false
ORDER BY s.id;
```

### MRR 概算

月額・年額の単価は App Store Connect / Stripe の実価格に合わせて更新する。

```sql
WITH price AS (
  SELECT 480::numeric AS monthly, 4800::numeric AS yearly
)
SELECT
  COUNT(*) FILTER (WHERE s.plan_type = 'monthly') AS monthly_count,
  COUNT(*) FILTER (WHERE s.plan_type = 'yearly') AS yearly_count,
  COUNT(*) FILTER (WHERE s.plan_type = 'monthly') * price.monthly
    + COUNT(*) FILTER (WHERE s.plan_type = 'yearly') * price.yearly / 12 AS mrr
FROM subscriptions s
CROSS JOIN price
WHERE s.status IN ('active', 'cancelled', 'billing_issue')
  AND s.internal_grant = false
  AND (s.expires_at IS NULL OR s.expires_at > NOW())
GROUP BY price.monthly, price.yearly;
```

`trial` は課金が発生していないため MRR に含めない。

### トライアル転換率

```sql
SELECT
  COUNT(*) AS trial_users,
  COUNT(*) FILTER (WHERE s.status = 'active') AS converted_users
FROM subscriptions s
WHERE s.has_used_trial = true
  AND s.internal_grant = false;
```

### 解約までの日数

```sql
SELECT
  COUNT(*) AS cancelled_users,
  AVG(EXTRACT(EPOCH FROM (s.cancelled_at - s.started_at)) / 86400) AS avg_days_to_cancel
FROM subscriptions s
WHERE s.cancelled_at IS NOT NULL
  AND s.started_at IS NOT NULL
  AND s.internal_grant = false;
```

母数が数件のうちは平均値を指標として扱わない。実課金が一桁のあいだは件数そのものを見る。
