# 外部インターフェース仕様（API）

Excelファイル出力機能（台帳確認画面）の内容を、外部システム連携用のAPIとして提供する。

## 共通仕様

- **実装方式**: Supabase Edge Functions（Deno）。既存のSupabaseプロジェクト（`nbahkykcxlulzkafrmkf`）上にデプロイ済み。
- **ベースURL**: `https://nbahkykcxlulzkafrmkf.supabase.co/functions/v1/`
- **HTTPメソッド**: すべて `GET`（参照系のみのため）
- **認証**: 専用のAPIキーによる認証。リクエストヘッダー `X-API-Key: <発行したキー>` を必須とする。
  - APIキーはSupabaseのFunction Secrets（環境変数 `EXTERNAL_API_KEY`）に保存し、Edge Function内で照合する。
  - 認証に成功したリクエストは、Edge Function内部でSupabaseの **service_role** キーを使ってDBへ接続する（Webアプリのログインユーザーとは無関係）。
  - `verify_jwt` はfalse（Supabaseログイン済みユーザーのJWTは不要。専用APIキーのみで認証する構成のため）。
- **レスポンス形式**: JSON（Excelファイルではなく、同内容をJSONの項目・値として返却）。
  - 成功時（200）は下記の共通エンベロープを使用する。
    ```json
    { "generated_at": "2026-07-17T09:00:00.000Z", "count": 5, "items": [ { "...": "..." } ] }
    ```
  - エラー時は `{ "error": "エラーメッセージ" }` を返し、状況に応じたステータスコードを付す（`400`パラメータ不正 / `401`APIキー未指定・不正 / `404`リソースなし / `405`メソッド不正 / `500`サーバー内部エラー）。
- **CORS**: `Access-Control-Allow-Origin: *` を返却し、外部システムからのクロスオリジン呼び出しを許可する。
- **フィールド名**: JSONのキーはDB上の列名に準拠したsnake_case（英語）。

## API一覧

| # | 名称 | エンドポイント | 主なパラメータ |
|---|---|---|---|
| 1 | 設備一覧出力API | `GET /export-equipments` | `search` / `system_category_kbn` / `equipment_type_id`（すべて任意） |
| 2 | 個体設置明細出力API | `GET /export-individual-installations` | 同上 |
| 3 | 個体属性値一覧出力API（縦持ち） | `GET /export-individual-attributes` | 同上 |
| 4 | 設備個体属性値出力API（横持ち） | `GET /export-equipment-individual-attributes` | `equipment_id`（必須） |

各APIの詳細なレスポンス項目は、実装（`supabase/functions/*/index.ts`）およびソースコード先頭のコメントを参照。

## 呼び出し例

```bash
curl "https://nbahkykcxlulzkafrmkf.supabase.co/functions/v1/export-equipments?system_category_kbn=5" \
  -H "X-API-Key: <発行したAPIキー>"
```

## 運用メモ

- APIキーは `supabase secrets set --project-ref nbahkykcxlulzkafrmkf EXTERNAL_API_KEY=<値>` で設定する（未設定の間は全リクエストが401になる）。
- キーのローテーション・複数キー発行・レート制限は未実装（今後の検討事項）。
