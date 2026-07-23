#!/usr/bin/env bash
# 設備台帳管理システム: 外部インターフェースAPI（Edge Functions）をセルフホストスタックへ配置
#
# セルフホスト版Supabaseでは、Edge Functionsは volumes/functions/<関数名>/index.ts に
# 配置するだけで有効になる（supabase functions deploy は不要。
# 移行計画書5.5節・Supabase公式ドキュメント「Accessing Edge Functions」参照）。
#
# 使い方:
#   STACK_DIR=/path/to/setsubi-daicho-stack ./deploy-functions.sh
#
# STACK_DIR は、公式docker-compose.ymlが置かれているセルフホストスタックのディレクトリ
# （中に volumes/functions/ があるディレクトリ）。
#
# 配置後は、functionsコンテナを再作成して反映させること:
#   cd "$STACK_DIR" && sh run.sh recreate functions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
FUNCTIONS_SRC_DIR="${REPO_ROOT}/supabase/functions"

if [ -z "${STACK_DIR:-}" ]; then
  echo "エラー: 環境変数 STACK_DIR を設定してください（セルフホストスタックのディレクトリ）。" >&2
  echo '例: STACK_DIR=/opt/setsubi-daicho-stack ./deploy-functions.sh' >&2
  exit 1
fi

TARGET_DIR="${STACK_DIR}/volumes/functions"

if [ ! -d "${TARGET_DIR}" ]; then
  echo "エラー: ${TARGET_DIR} が見つかりません。STACK_DIRの指定が正しいか確認してください。" >&2
  exit 1
fi

if [ ! -d "${FUNCTIONS_SRC_DIR}" ]; then
  echo "エラー: ${FUNCTIONS_SRC_DIR} が見つかりません。" >&2
  exit 1
fi

echo "配置元: ${FUNCTIONS_SRC_DIR}"
echo "配置先: ${TARGET_DIR}"

for dir in "${FUNCTIONS_SRC_DIR}"/*/; do
  name="$(basename "${dir}")"
  echo "  配置中: ${name}"
  mkdir -p "${TARGET_DIR}/${name}"
  cp -f "${dir}index.ts" "${TARGET_DIR}/${name}/index.ts"
done

echo "完了しました。反映には次を実行してください:"
echo "  cd \"${STACK_DIR}\" && sh run.sh recreate functions"
