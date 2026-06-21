#!/usr/bin/env bash
#
# 本番ダンプを匿名化して開発DB(app_development)に投入する。
#
# 安全方針:
#   未マスクの本番データ（device_tokens 等の PII を含む）は「一時DB」にしか置かず、
#   匿名化・検証が完了してから初めて app_development に置き換える。
#   よって開発環境に生の本番 PII が入る瞬間が無く、push 通知の誤送信事故
#   （2026-05-18）と同種のリスクを構造的に排除する。
#
# フロー:
#   一時DBへ復元 → qa:anonymize → 匿名化検証 → app_development を一時DBで置換 → db:migrate
#
# 使い方:
#   back/bin/load_masked_prod_to_dev.sh <dump-file> [-y]
#     <dump-file> : pg_dump カスタム形式(.dump)。例: back/tmp/db_dumps/dump-xxx.dump
#     -y          : 確認プロンプトをスキップ
#
set -euo pipefail

DUMP_FILE="${1:-}"
ASSUME_YES="${2:-}"

if [[ -z "$DUMP_FILE" ]]; then
  echo "Usage: $0 <dump-file> [-y]" >&2
  exit 1
fi
if [[ ! -f "$DUMP_FILE" ]]; then
  echo "ダンプファイルが見つかりません: $DUMP_FILE" >&2
  exit 1
fi

# リポジトリルート（このスクリプトは back/bin 配下）から docker compose を実行する。
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
COMPOSE="docker compose -f $REPO_ROOT/docker-compose.yml"

DEV_DB="app_development"
TMP_DB="app_development_import"
DB_USER="user"
DB_PASS="password"
DB="$COMPOSE exec -e PGPASSWORD=$DB_PASS -T db"

echo "対象ダンプ : $DUMP_FILE"
echo "投入先     : $DEV_DB（既存データは破棄され、匿名化済み本番データで置き換わります）"
if [[ "$ASSUME_YES" != "-y" ]]; then
  read -r -p "続行しますか？ [y/N] " answer
  [[ "$answer" == "y" || "$answer" == "Y" ]] || { echo "中止しました"; exit 0; }
fi

echo "==> 1/6 一時DB($TMP_DB)を作成"
$DB dropdb -U "$DB_USER" --if-exists "$TMP_DB"
$DB createdb -U "$DB_USER" "$TMP_DB"

echo "==> 2/6 ダンプを一時DBへ復元（'schema public already exists' は無害）"
# pg_restore は public スキーマ重複で exit 1 を返すことがあるため、許容して続行する。
$DB pg_restore --no-owner --no-acl -U "$DB_USER" -d "$TMP_DB" < "$DUMP_FILE" || true

echo "==> 3/6 一時DBを匿名化（device_tokens 全削除 + PII マスク）"
$COMPOSE exec -e DATABASE_URL="postgres://$DB_USER:$DB_PASS@db:5432/$TMP_DB" -T back \
  bundle exec rails qa:anonymize

echo "==> 4/6 匿名化を検証（未マスクなら中止し、開発DBは置き換えない）"
unmasked="$($DB psql -U "$DB_USER" -d "$TMP_DB" -tAq -c \
  "SELECT (SELECT count(*) FROM device_tokens) + (SELECT count(*) FROM users WHERE email NOT LIKE 'user_%@example.com');" \
  | tr -dc '0-9')"
if [[ "$unmasked" != "0" ]]; then
  echo "匿名化が不完全です（device_tokens 残存 or 未マスク users）。開発DBは変更していません。" >&2
  echo "一時DB $TMP_DB を確認してください。" >&2
  exit 1
fi
echo "    OK: device_tokens=0 / 未マスク users=0"

echo "==> 5/6 app_development を匿名化済み一時DBで置き換え"
# rename には対象DBへの接続が無いことが必要。dev/tmp への接続を切断する。
$DB psql -U "$DB_USER" -d postgres -c \
  "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname IN ('$DEV_DB','$TMP_DB') AND pid <> pg_backend_pid();" >/dev/null
# --force で残存コネクションごと切断して drop（PostgreSQL 13+）。
$DB dropdb -U "$DB_USER" --if-exists --force "$DEV_DB"
$DB psql -U "$DB_USER" -d postgres -c "ALTER DATABASE \"$TMP_DB\" RENAME TO \"$DEV_DB\";" >/dev/null

echo "==> 6/6 db:migrate を実行（本番状態の masked データに当リリースの migration を適用）"
$COMPOSE exec -T back bundle exec rails db:migrate

echo ""
echo "完了: 匿名化済み本番データを $DEV_DB に投入し、migration 適用まで終えました。"
echo "ヒント: 取得元のダンプ($DUMP_FILE)は PII を含むため、不要になったら削除してください。"
