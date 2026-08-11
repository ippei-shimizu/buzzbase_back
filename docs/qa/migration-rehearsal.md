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

### 5. rollback 可逆性確認（部分 rollback）

意図的に非可逆な migration が含まれるリリースでは、全件 rollback は必ず失敗する。
対象リリースで `down` が `ActiveRecord::IrreversibleMigration` を raise する migration を除いた
残りが、1本ずつ破綻なく rollback できることを確認する。

> **`db:rollback STEP=<本数>` や `db:migrate VERSION=<非可逆migrationのバージョン>` による
> 一括 rollback は使わない。** migration のバージョン番号（タイムスタンプ）はファイル作成日時であり、
> リリース順とは限らない。実際に release/pro-202605 では最古の新規 migration
> （`20260517100004`、Pro機能の開発着手時点で作成）より後の日付で、**別リリース（game-stats）の
> 既に本番適用済みの migration**（`20260530xxxxxx`〜`20260625xxxxxx`）が多数存在した。バージョン
> 番号だけを基準にした一括 rollback は、対象リリースと無関係なこれら適用済み migration まで
> 巻き込んで revert してしまう（実際に本手順の検証中に発生し、`pitchers` / `stadiums` 等の
> 本番稼働中テーブルを誤って drop する寸前だった）。

対象リリース**自身**の migration バージョンだけを新しい順に個別列挙し、非可逆な1本を除いて
1本ずつ `db:migrate:down VERSION=` で rollback する。

```bash
# 対象リリースの migration バージョンを新しい順に取得し、非可逆な1本を除外する
git -C back diff origin/main HEAD --name-only -- db/migrate/ \
  | grep -oE '^[0-9]{14}' | sort -rn | grep -v <非可逆migrationのバージョン> \
  > /tmp/reversible_versions.txt

while IFS= read -r v; do
  docker compose exec -T -e DATABASE_URL=postgres://user:password@db:5432/buzzbase_qa \
    back bundle exec rails db:migrate:down "VERSION=$v" < /dev/null || { echo "rollback失敗: $v"; break; }
done < /tmp/reversible_versions.txt
```

> `docker compose exec` は `-T`（pseudo-tty無効化）と `< /dev/null` を必ず付ける。付けないと
> while ループの標準入力（ファイル）を `docker compose exec` 側が横取りし、1回目のイテレーションで
> ループが終了してしまう。

エラーなく全件完了すれば OK。1回の rails 起動あたり数秒かかるため、対象リリースの migration
本数によっては数分かかる。

> 例（release/pro-202605）: `20260517100004_backfill_default_subscriptions_for_existing_users.rb` の
> `down` は「`status = 'free'` の一律削除は、Pro解約で free に戻った正規データを巻き込むため」raiseする設計。
> 上記コマンドで除外対象に指定する。
>
> なお、他にも `down` が例外を出さず no-op なだけの migration（子テーブルへのバックフィル系。例:
> `backfill_note_game_links` / `backfill_practice_session_theme_links` / `backfill_note_theme_links` /
> `backfill_practice_type_on_practice_sessions`）が複数含まれる場合がある。これらは rollback は「成功」するが
> バックフィルしたデータは復元されない（1件のレコードに対し複数の紐付けがある場合に一意の書き戻し先がない、
> または変更前の値を保持していないため）。本手順が保証するのは「rollback がクラッシュしないこと」であり、
> 「データが完全に元に戻ること」ではない点に注意する。

確認後は、後続の手順（開発環境への投入や目視確認）のためにスキーマをリリース時点まで戻しておく。

```bash
docker compose exec -e DATABASE_URL=postgres://user:password@db:5432/buzzbase_qa \
  back bundle exec rails db:migrate
```

### 6. 後片付け

```bash
rm -f back/tmp/db_dumps/*.dump
docker compose exec -e PGPASSWORD=password db dropdb -U user --if-exists buzzbase_qa
```

## 開発環境へ匿名化済み本番データを投入する（任意）

migration リハーサルとは別に、**本番相当データで開発環境を動かして不整合を確認**したい場合は
`bin/load_masked_prod_to_dev.sh` を使う。

```bash
back/bin/load_masked_prod_to_dev.sh back/tmp/db_dumps/<dump> [-y]
```

安全方針: 未マスクデータ（`device_tokens` 等の PII）は**一時DB(`app_development_import`)にしか
置かず、匿名化・検証が完了してから `app_development` に置き換える**。よって開発環境に生の本番
PII が入る瞬間が無い。フローは「一時DB復元 → `qa:anonymize` → 匿名化検証 → `app_development`
置換 → `db:migrate`」。

> **破壊的**: 既存の `app_development`（ローカルのシード・テストデータ）は置き換わる。
> 取得元ダンプは PII を含むため作業後に削除すること。

## リリース前チェックリスト

- [ ] 本番ダンプを取得し QA 専用 DB に復元した（開発 DB は壊していない）
- [ ] 復元直後に `qa:anonymize` を実行した（`device_tokens=0` / 全 users が `@example.com`）
- [ ] `qa:rehearse_migration` が `✓ 差分なし` で完了した
- [ ] 非可逆 migration の1つ手前までの部分 rollback が破綻なく通った
- [ ] 新規 seed を伴う migration は、参照する `db/data/master_seeds/*.yml` が**実在**することを確認した
- [ ] ダンプファイルと QA 専用 DB を削除した

## 既知の落とし穴

- **seed 漏れ**: master を撤廃して seed YAML を削除しても、それを参照する create+seed migration が
  残っていると、本番（未適用状態）からの `db:migrate` が seed 読み込みで失敗する。
  本リハーサルはこの種のクラッシュを検知できる（実際に hit_directions / hit_depths で検出した）。
- **pg_dump バージョン**: ローカルが本番より古いと `server version mismatch`。15 系バイナリを使う。
- **行ごと UPDATE は遅い**: Docker 経由だと往復が積み上がるため、anonymize は `update_all` の一括 SQL
  （`id` を参照）で行う。
- **`qa:rehearse_migration` の自動検証対象外にしているもの**: `backfill_practice_type_on_practice_sessions`
  のような、既存カラムへの直接 UPDATE で新しい値を導出するだけの migration（参照元データ自体は削除しない）は、
  自動 diff 対象に含めていない。中間テーブルへの退避・カラム削除を伴う migration（`note_game_links` 等）と違い、
  参照元（`practice_logs` / `schedules`）さえ残っていれば後からいつでも再導出できるため、データ消失リスクが
  質的に異なる。必要であれば `qa:rehearse_migration` 実行後に対象テーブルを個別に SELECT して目視確認する。
- **migration バージョン番号とリリース順は一致しない**: 並行開発中のブランチでは、後からリリースする側の
  migration が先にリリースする側より古いタイムスタンプを持つことがある（実例は手順5参照）。
  `db:rollback STEP=` や `db:migrate VERSION=` を「今回のリリース分だけ」のつもりで一括実行すると、
  無関係な既存 migration まで巻き込む。対象リリースの migration 一覧は `git diff <ベースブランチ> HEAD
  --name-only -- db/migrate/` で明示的に取得すること。
- **`change_table` の `bulk: true` はカラム追加とインデックス追加を同居させると rollback を壊す**:
  `change_table :table, bulk: true do |t| t.column ...; t.index ... end` の形で列追加とインデックス
  追加を同一ブロックに書くと、自動生成される `down` はカラム削除を先に実行してしまい
  （PostgreSQL がカラム削除時にそのカラムに依存するインデックスを CASCADE で自動削除するため）、
  続く `remove_index` が「対象インデックスが見つからない」で失敗する。本リハーサル中に
  `20260704010001_add_versioning_to_reflection_templates.rb` で実際に検出し、`bulk: true` を
  外すことで解消した（`bulk: true` は複数カラム変更を1つの `ALTER TABLE` にまとめる性能最適化に
  過ぎず、除去しても最終スキーマは変わらない）。同種のパターンを書く migration では要注意。
