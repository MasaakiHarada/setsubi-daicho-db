#!/usr/bin/env bash
# 設備台帳管理システム: セルフホストDBへのマイグレーション・サンプルデータ適用
#
# 使い方:
#   DATABASE_URL="postgres://postgres.<POOLER_TENANT_ID>:<POSTGRES_PASSWORD>@<domain>:5432/postgres" \
#     ./apply-migrations.sh
#
#   サンプルデータ（seed/0001_sample_fumikiri.sql）も一緒に投入する場合:
#   APPLY_SEED=1 DATABASE_URL="postgres://..." ./apply-migrations.sh
#
# DATABASE_URL は、セルフホストSupabaseの .env にある POSTGRES_PASSWORD と
# POOLER_TENANT_ID（既定値 your-tenant-id）から組み立てる
# （移行計画書5.2節・Supabase公式ドキュメント「Accessing Postgres」参照）。
#
# 冪等性はない。初回適用専用（2回目以降に流すとCREATE TABLE等が失敗する）。
# 再実行が必要な場合は、DBを初期状態に戻してから流すこと。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
MIGRATIONS_DIR="${REPO_ROOT}/migrations"
SEED_DIR="${REPO_ROOT}/seed"

if [ -z "${DATABASE_URL:-}" ]; then
  echo "エラー: 環境変数 DATABASE_URL を設定してください。" >&2
  echo '例: export DATABASE_URL="postgres://postgres.your-tenant-id:<POSTGRES_PASSWORD>@<domain>:5432/postgres"' >&2
  exit 1
fi

if ! command -v psql >/dev/null 2>&1; then
  echo "エラー: psql コマンドが見つかりません。PostgreSQLクライアントをインストールしてください。" >&2
  exit 1
fi

echo "接続確認中..."
psql "${DATABASE_URL}" -c "select 1;" >/dev/null

echo "マイグレーションを番号順に適用します（${MIGRATIONS_DIR}）"
for f in "${MIGRATIONS_DIR}"/*.sql; do
  echo "  適用中: $(basename "${f}")"
  psql "${DATABASE_URL}" -v ON_ERROR_STOP=1 -f "${f}"
done

if [ "${APPLY_SEED:-0}" = "1" ]; then
  echo "サンプルデータを適用します（${SEED_DIR}）"
  for f in "${SEED_DIR}"/*.sql; do
    echo "  適用中: $(basename "${f}")"
    psql "${DATABASE_URL}" -v ON_ERROR_STOP=1 -f "${f}"
  done
fi

echo "完了しました。"
