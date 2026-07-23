# Docker環境への移植 セットアップ手順

詳細な背景・設計判断は、プロジェクトフォルダの `移行計画_設備台帳管理システムのDocker環境への移植.md` を参照。ここは実行手順のみをまとめた早見表。

## このフォルダの内容

| ファイル | 役割 |
|---|---|
| `docker-compose.webapp.yml` | webapp配信コンテナの追加定義＋functionsサービスへの`EXTERNAL_API_KEY`追加 |
| `Caddyfile` | 公式`docker-compose.caddy.yml`が使うCaddyfileの置き換え内容（Studio退避＋webapp追加） |
| `.env.project.example` | 本システム固有の環境変数サンプル |
| `scripts/apply-migrations.sh` | `migrations/`・`seed/` をセルフホストDBに適用 |
| `scripts/deploy-functions.sh` | `supabase/functions/` をセルフホストスタックに配置 |
| `docker-compose.proxy.yml` | **非推奨・未使用**（ファイル内のコメント参照。公式`docker-compose.caddy.yml`を使う方針に変更） |

Supabase公式のdocker-compose本体（`docker-compose.yml`・`.env.example`・`kong.yml`・`docker-compose.caddy.yml`等）はここには含めていない。更新頻度が高い公式リポジトリからセットアップ時に直接取得する（陳腐化防止のため）。

## 手順

### 1. 公式Supabaseスタックを取得

```bash
git clone --filter=blob:none --no-checkout --depth=1 https://github.com/supabase/supabase
cd supabase && git sparse-checkout init --cone && git sparse-checkout set docker && git checkout
cd ..
mkdir setsubi-daicho-stack
cp -rf supabase/docker/* setsubi-daicho-stack/
cp supabase/docker/.env.example setsubi-daicho-stack/.env
cd setsubi-daicho-stack
```

db-repoも同じサーバー上にcloneしておく（例: `/home`配下）。

```bash
cd /home
git clone https://github.com/MasaakiHarada/setsubi-daicho-db.git db-repo
```

### 2. 鍵・URL・本システム固有設定

```bash
cd /home/setsubi-daicho-stack
sh utils/generate-keys.sh
sh utils/add-new-auth-keys.sh
```

続けて、下記を一度に設定する（`DB_REPO_DIR`・`PUBLIC_DOMAIN`・`EXTERNAL_API_KEY`は実際の値に置き換える）。

```bash
DB_REPO_DIR=/home/db-repo
PUBLIC_DOMAIN=dragonite.i-comons.com
EXTERNAL_API_KEY=<現行Supabase Cloudの値、または新規発行した値>

# 既存キーの値を書き換え（sedで置換。実行前に.envの現在値を確認しておくこと）
sed -i "s#^SUPABASE_PUBLIC_URL=.*#SUPABASE_PUBLIC_URL=https://${PUBLIC_DOMAIN}#" .env
sed -i "s#^API_EXTERNAL_URL=.*#API_EXTERNAL_URL=https://${PUBLIC_DOMAIN}/auth/v1#" .env
sed -i "s#^SITE_URL=.*#SITE_URL=https://${PUBLIC_DOMAIN}#" .env
sed -i "s#^PROXY_DOMAIN=.*#PROXY_DOMAIN=${PUBLIC_DOMAIN}#" .env
sed -i "s#^DASHBOARD_PASSWORD=.*#DASHBOARD_PASSWORD=$(openssl rand -base64 18)#" .env
sed -i "s#^COMPOSE_FILE=.*#COMPOSE_FILE=docker-compose.yml:docker-compose.caddy.yml:${DB_REPO_DIR}/docker/docker-compose.webapp.yml#" .env

# 本システム固有の項目を新規追記
cat >> .env <<EOF
EXTERNAL_API_KEY=${EXTERNAL_API_KEY}
DB_REPO_DIR=${DB_REPO_DIR}
WEBAPP_SOURCE_DIR=${DB_REPO_DIR}/webapp
EOF

# DASHBOARD_PASSWORDを控えておく（Studio管理画面のログインに必要）
grep '^DASHBOARD_' .env
```

Caddyfileを、db-repo側の内容で置き換える。

```bash
cp "${DB_REPO_DIR}/docker/Caddyfile" volumes/proxy/caddy/Caddyfile
```

DNS（`dragonite.i-comons.com`）がこのサーバーのIPを指すよう設定しておくこと（Let's Encrypt自動HTTPSに必要）。

### 3. 起動

```bash
sh run.sh start
docker compose ps   # 全サービスがhealthyになるまで待つ
```

### 4. スキーマ・サンプルデータを適用

```bash
export DATABASE_URL="postgres://postgres.your-tenant-id:<POSTGRES_PASSWORDの値>@localhost:5432/postgres"
"${DB_REPO_DIR}/docker/scripts/apply-migrations.sh"
```

サンプルデータも入れる場合は `APPLY_SEED=1` を付ける。`POOLER_TENANT_ID`が既定値`your-tenant-id`から変更されていないか`.env`で確認すること。

### 5. Webアプリ側の接続先を変更

`db-repo/webapp/index.html`（`docs/index.html`も同様）の `SUPABASE_URL` / `SUPABASE_ANON_KEY` を、新環境の値に変更する。

```bash
grep '^SUPABASE_PUBLIC_URL\|^ANON_KEY' .env
```

の出力を使って書き換える。

### 6. 動作確認

- `https://dragonite.i-comons.com/` → 設備台帳管理システムのWebアプリが表示されること
- `https://dragonite.i-comons.com/studio/` → Basic認証（`DASHBOARD_USERNAME`/`DASHBOARD_PASSWORD`）後、Supabase Studioが表示されること
- 外部インターフェースAPI:

```bash
cd "${DB_REPO_DIR}/scripts"
./test_api.ps1 -ApiKey "<EXTERNAL_API_KEYの値>"   # ベースURLもスクリプト内で新環境向けに変更する
```

Webアプリのログイン・台帳確認・Excel出力・製品確認・設備種別確認の各画面も一通り確認する。

### 7. MCPサーバーの向き先変更

利用者側の `SETSUBI_DAICHO_API_BASE_URL` を新環境の `https://dragonite.i-comons.com/functions/v1` に変更する。

## 注意事項

- `.env`（シークレット入り）はGit管理対象外にすること。`db-repo`にコミットしない。
- Supabase Studio（管理画面）は`/studio/*`に配置し、Basic認証で保護している（Caddyfile参照）。より厳重にする場合は社内ネットワーク限定アクセスも検討する。
- `docker-compose.proxy.yml`は使用しない（ファイル内コメント参照）。
