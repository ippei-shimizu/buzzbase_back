# 本番DB相当データでの migration リハーサル手順

大規模 migration を本番に流す前に、本番由来データをローカルに復元し、PII を匿名化したうえで
`db:migrate` を一気通貫で検証する手順。既存ユーザーの集計値破壊やマスタ ID 不整合、
seed 漏れによる migration クラッシュを本番反映前に検知する。

## 安全運用の絶対ルール

- ダンプ取得は本番に対して **読み取りのみ**（`pg_dump` / DBeaver Backup は SELECT のみ。本番は壊れない）。
- 復元先は **必ずローカルの QA 専用 DB**。本番 URL に向けた `pg_restore` / `psql` / `db:reset` は厳禁。
- 復元直後（マスク前）に **アプリを起動しない**。`device_tokens` を残したまま起動すると本番ユーザーへ
  push 通知が誤送信される（2026-05-18 の誤爆事故と同じパターン）。**復元 → 即 `qa:anonymize`**。
- ダンプは PII を含むため `tmp/db_dumps/`（`.gitignore` 済み）に隔離し、**作業後に即削除**。
- 開発 DB（`app_development`）は壊さない。QA は専用 DB（`buzzbase_qa`）に隔離する。

## 全体フロー

```
[本番 DB] --(読み取り)--> [ローカル .dump] --(pg_restore)--> [buzzbase_qa（マスク前・起動禁止）]
  --> qa:anonymize（最初に device_tokens 削除）--> [buzzbase_qa（マスク済み）]
  --> qa:rehearse_migration（前スナップショット → db:migrate → 後スナップショット → 差分検証）
  --> db:rollback 可逆性確認 --> ダンプ削除
```

## 手順

### 0. 準備

```bash
# back/ で。隔離ディレクトリは .gitignore 済み
mkdir -p back/tmp/db_dumps
```

### 1. 本番ダンプ取得

`pg_dump` は本番（PostgreSQL 15.5）以上のバージョンが必要。ローカルが古い場合は
`/opt/homebrew/opt/postgresql@15/bin/pg_dump` を使う。

**A. heroku CLI が使える場合**

```bash
APP=<本番アプリ名>
heroku pg:backups:download --app $APP -o back/tmp/db_dumps/prod-$(date +%Y%m%d).dump
```

**B. heroku CLI が使えない場合（DBeaver GUI）** ← MFA 紛失等で CLI ログイン不能なときの代替

1. DBeaver で本番 DB に read 接続済みであること
2. ナビゲータで対象 DB を右クリック → **Tools → Backup（PostgreSQL dump）**
3. Objects: **`public` スキーマのみ**チェック（`_heroku` / `heroku_ext` は Heroku 内部用で復元時に不要）
4. **Local Client** に PostgreSQL 15 系（`/opt/homebrew/Cellar/postgresql@15/15.x`）を指定（本番との
   バージョン不一致回避）
5. Backup settings: Format = **Custom**、Output folder = `back/tmp/db_dumps/`、
   `Do not backup privileges` / `Discard objects owner` にチェック
6. Start

> read 権限のみでも pg_dump は SELECT だけなので本番は壊れない。負荷を避けるためオフピーク（朝など）推奨。

取得後の検証:

```bash
/opt/homebrew/opt/postgresql@15/bin/pg_restore -l back/tmp/db_dumps/<dump> | grep -c 'TABLE DATA'
```

### 2. QA 専用 DB へ復元

```bash
# コンテナの postgres ロールは user / パスワード password
docker compose exec -e PGPASSWORD=password db dropdb -U user --if-exists buzzbase_qa
docker compose exec -e PGPASSWORD=password db createdb -U user buzzbase_qa
docker compose exec -e PGPASSWORD=password -T db \
  pg_restore --no-owner --no-acl -U user -d buzzbase_qa < back/tmp/db_dumps/<dump>
```

> `ERROR: schema "public" already exists` は無害（新規 DB に既存の public があるだけ）。

### 3. マスキング（復元直後に即実行）

```bash
docker compose exec -e DATABASE_URL=postgres://user:password@db:5432/buzzbase_qa \
  back bundle exec rails qa:anonymize
```

`qa:anonymize` の内容（本番環境では実行不可ガードあり）:

- **`device_tokens` を全削除（最優先）**
- `users`: email / name / user_id / uid を id ベースのダミーに、画像・自己紹介・各種トークン・
  パスワードを無効化
- `admin_users`: email / name / password_digest を匿名化
- 自由記述メモ（`match_results.memo` / `plate_appearances.self_analysis_memo` /
  `opponent_memo` / `pitchers.memo` / `baseball_notes`）を NULL
- `groups`: name を id ベースに、icon / description を NULL
- `group_invite_links.code` を再生成（`varchar(8)` 制約・ユニーク制約を満たす id の16進ゼロ埋め）

> game-stats のような新規テーブル/カラムを含む release では、anonymize は **migration 前でも後でも
> 動くようテーブル/カラムの存在ガード付き**にしてある。

### 4. migration リハーサル

```bash
docker compose exec -e DATABASE_URL=postgres://user:password@db:5432/buzzbase_qa \
  back bundle exec rails qa:rehearse_migration
```

処理内容:

1. マスキング済みか検証（未マスクなら中断）
2. migration 前スナップショット取得（`batting_averages` の集計値、`plate_appearances` の
   `hit_direction_id` / `plate_result_id` / `batting_position_id`）
3. `db:migrate` 実行
4. migration 後スナップショット取得
5. 既存レコードの集計値・キー値に差分があれば `abort`（exit 1）

`✓ migration 前後で既存の集計値・キー値に差分なし` が出れば成功。

### 5. rollback 可逆性確認

```bash
docker compose exec -e DATABASE_URL=postgres://user:password@db:5432/buzzbase_qa \
  back bundle exec rails db:rollback STEP=<今回適用した migration 本数>
```

全 migration が `IrreversibleMigration` やエラーなく巻き戻ることを確認する。

### 6. 後片付け

```bash
rm -f back/tmp/db_dumps/*.dump
docker compose exec -e PGPASSWORD=password db dropdb -U user --if-exists buzzbase_qa
```

## リリース前チェックリスト

- [ ] 本番ダンプを取得し QA 専用 DB に復元した（開発 DB は壊していない）
- [ ] 復元直後に `qa:anonymize` を実行した（`device_tokens=0` / 全 users が `@example.com`）
- [ ] `qa:rehearse_migration` が `✓ 差分なし` で完了した
- [ ] `db:rollback` が破綻なく巻き戻った
- [ ] 新規 seed を伴う migration は、参照する `db/data/master_seeds/*.yml` が**実在**することを確認した
- [ ] ダンプファイルと QA 専用 DB を削除した

## 既知の落とし穴

- **seed 漏れ**: master を撤廃して seed YAML を削除しても、それを参照する create+seed migration が
  残っていると、本番（未適用状態）からの `db:migrate` が seed 読み込みで失敗する。
  本リハーサルはこの種のクラッシュを検知できる（実際に hit_directions / hit_depths で検出した）。
- **pg_dump バージョン**: ローカルが本番より古いと `server version mismatch`。15 系バイナリを使う。
- **行ごと UPDATE は遅い**: Docker 経由だと往復が積み上がるため、anonymize は `update_all` の一括 SQL
  （`id` を参照）で行う。
