# Analytics Batch Processing

BUZZ BASE管理画面の統計データを集計するためのバッチ処理システム。

## 概要

日次、週次、月次の統計データを自動的に集計し、管理画面のダッシュボードで表示するためのデータを生成します。

## アーキテクチャ

### 主要コンポーネント

1. **Job Classes** (`app/jobs/admin/analytics/`)
   - `DailyStatisticsJob` - 日次統計データ集計

2. **Models** (`app/models/admin/`)
   - `DailyStatistic` - 日次統計データモデル
   - `WeeklyStatistic` - 週次統計データモデル
   - `MonthlyStatistic` - 月次統計データモデル

3. **Rake Tasks** (`lib/tasks/analytics.rake`)
   - 手動実行・デバッグ用のタスク群

4. **Cron Schedule** (`config/schedule.rb`)
   - 自動実行スケジュール設定

## 実行方法

### 手動実行

#### 日次統計データ

```bash
# 昨日分のデータを集計
bundle exec rake analytics:daily_job

# 特定の日付を指定
bundle exec rake analytics:daily_job_for_date[2024-09-20]

# 期間指定でバッチ実行
bundle exec rake analytics:daily_job_batch[2024-09-15,2024-09-20]

# 欠損データの補完
bundle exec rake analytics:backfill_daily_stats[30]
```

#### 週次・月次統計データ

```bash
# 今週の週次統計
bundle exec rake analytics:calculate_weekly

# 今月の月次統計
bundle exec rake analytics:calculate_monthly

# 期間指定
bundle exec rake analytics:calculate_weekly_batch[2024-09-01,2024-09-30]
bundle exec rake analytics:calculate_monthly_batch[2024-07-01,2024-09-30]
```

#### レポート生成

```bash
# 過去30日のレポート生成
bundle exec rake analytics:generate_report
```

### Background Job実行

```bash
# Jobキューに追加（バックグラウンド実行）
bundle exec rake analytics:queue_daily_job[2024-09-20]
```

### 自動実行（Cron）

```bash
# whenever gemを使用してcrontabを更新
bundle exec whenever --update-crontab

# crontabの確認
bundle exec whenever --crontab

# crontabの削除
bundle exec whenever --clear-crontab
```

## スケジュール

| 処理 | 実行時間 | 対象データ |
|------|----------|------------|
| 日次統計 | 毎日 06:00 | 前日分 |
| 週次統計 | 毎週月曜 07:00 | 前週分 |
| 月次統計 | 毎月1日 08:00 | 前月分 |
| データ補完 | 毎日 10:00 | 過去7日分の欠損チェック |
| レポート生成 | 毎週金曜 18:00 | 過去30日分 |

## データ構造

### DailyStatistic

```ruby
{
  date: Date,                    # 集計対象日
  total_users: Integer,          # その日時点での総ユーザー数
  new_users: Integer,            # その日の新規登録数
  active_users: Integer,         # その日のDAU
  total_games: Integer,          # その日の試合記録数
  total_batting_records: Integer, # その日の打撃記録数
  total_pitching_records: Integer, # その日の投手記録数
  total_posts: Integer           # その日の投稿総数
}
```

## エラーハンドリング

### ログ出力

- 成功時: `Rails.logger.info`
- エラー時: `Rails.logger.error` + スタックトレース

### リトライ機能

```ruby
# Job失敗時の再実行
Admin::Analytics::DailyStatisticsJob.perform_later(target_date)
```

### データ整合性チェック

```ruby
# 欠損データの自動検出・補完
Admin::Analytics::DailyStatisticsJob.backfill_missing_data(30)
```

## 本番環境での運用

### 1. 初回セットアップ

```bash
# 過去30日分のデータを初期生成
bundle exec rake analytics:daily_job_batch[$(date -d '30 days ago' '+%Y-%m-%d'),$(date -d '1 day ago' '+%Y-%m-%d')]

# crontabの設定
bundle exec whenever --update-crontab --set environment=production
```

### 2. 監視項目

- **Job実行状況**: ログファイル `log/cron.log`
- **データ欠損**: 日次データの連続性チェック
- **実行時間**: 大量データでの処理時間監視
- **ディスク容量**: 統計データの蓄積による容量増加

### 3. メンテナンス

```bash
# データの整合性チェック
bundle exec rake analytics:generate_report

# 注意: 統計データは長期保存・活用のため削除しない
# 過去データは成長分析・トレンド分析・予測モデルに重要
```

## トラブルシューティング

### よくある問題

1. **Job実行失敗**
   ```bash
   # 手動で再実行
   bundle exec rake analytics:daily_job_for_date[失敗した日付]
   ```

2. **データ欠損**
   ```bash
   # 自動補完実行
   bundle exec rake analytics:backfill_daily_stats[確認したい日数]
   ```

3. **パフォーマンス問題**
   - データベースインデックスの確認
   - 大量データ処理時のバッチサイズ調整

### ログ確認

```bash
# Cronログ
tail -f log/cron.log

# Railsログ
tail -f log/production.log | grep "Analytics"

# Job実行ログ
tail -f log/production.log | grep "DailyStatisticsJob"
```
