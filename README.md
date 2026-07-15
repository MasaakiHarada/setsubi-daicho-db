# 設備台帳管理システム データベース

阪急阪神ITEC「設備台帳管理システム」のデータベース設計（PostgreSQL / Supabase）。
要件定義〜物理設計〜実装・テストの検討結果をリポジトリとして保存したもの。

## 構成

```
migrations/
  0001_create_schema.sql        -- 9テーブルのCREATE TABLE（論理設計→物理設計）
  0002_enable_rls.sql           -- Row Level Security（認証済みユーザーのみ読み書き可）
  0003_create_ledger_views.sql  -- 台帳確認画面向けビュー（テーブルをまたいだ表示用）
  0004_add_equipment_individual_names.sql  -- 設備名称・個体名称列を追加（旧: 備考欄の内容を移行）
  0005_add_equipment_installation_histories_view.sql  -- 設備交換履歴画面向けビューを追加
seed/
  0001_sample_fumikiri.sql -- サンプルデータ（〇〇踏切1台分）
docs/
  concept_er.png           -- 概念ER図
  index.html               -- デモWebアプリ（GitHub Pages公開用）
webapp/
  index.html               -- デモWebアプリ（docs/index.htmlと同一内容）
```

## テーブル構成（9テーブル）

- `equipment_types`（設備種別）: 転てつ機・踏切など、設備の"クラス"を定義するマスタ
- `locations`（場所）: 駅・機器室・キロ程・支持物
- `equipments`（設備）: 設備種別×場所で決まるインスタンス
- `equipment_type_components`（構成要素）: 主装置・付属部品（階層構造・自己参照）
- `product_categories`（製品種別）: 個体の属性スキーマ分類
- `attribute_definitions`（属性定義）: 製品種別ごとに管理項目を定義（EAV方式）
- `individuals`（個体）: 現地に設置される物理製品（メーカー・型式・製造番号）
- `individual_attribute_values`（個体属性値）: 個体ごとに可変な項目の値
- `individual_installation_histories`（個体設置履歴）: 個体の設置場所の変更履歴

詳細な設計判断（なぜ「設備→個体」ではなく「設備→個体設置履歴→個体」なのか等）は
プロジェクトフォルダ内の `設備台帳DB設計まとめ.xlsx` を参照。

## 台帳確認用ビュー（0003）

複数テーブルをまたいだ「台帳確認画面」向けに、以下のビューを用意している。
いずれも `security_invoker = true` を指定し、ビュー経由でもRLSポリシーが
呼び出したユーザーの権限で適用されるようにしている。

- `view_equipments_list`: 設備一覧（種別名・場所名付き）
- `view_equipment_current_individuals`: 設備の構成要素ごとに現在設置されている個体（`removed_date IS NULL`のみ）
- `view_individual_attributes`: 個体属性値（属性名・単位付き）
- `view_individual_installation_histories`: 個体の設置履歴（現在・過去すべて）
- `view_equipment_installation_histories`（0005）: 設備配下の全構成要素・全期間の設置履歴（個体名付き）。equipment_idから直接取得でき、「設備交換履歴」画面で旧→新の交換ペアを組み立てるのに使う

## 適用方法

Supabase（または任意のPostgreSQL）に対して、番号順に実行する。

```bash
psql "$DATABASE_URL" -f migrations/0001_create_schema.sql
psql "$DATABASE_URL" -f migrations/0002_enable_rls.sql
psql "$DATABASE_URL" -f migrations/0003_create_ledger_views.sql
psql "$DATABASE_URL" -f migrations/0004_add_equipment_individual_names.sql
psql "$DATABASE_URL" -f migrations/0005_add_equipment_installation_histories_view.sql
psql "$DATABASE_URL" -f seed/0001_sample_fumikiri.sql   # 任意（動作確認用サンプルデータ）
```

## 現在の適用先

Supabaseプロジェクト（リージョン: ap-northeast-2）に上記マイグレーション・サンプルデータを適用済み。
制約（一意制約・履歴の整合性チェック等）は実データで動作確認済み。

デモWebアプリ（ログイン+CRUD+台帳確認画面）はGitHub Pagesで公開中。

## 台帳確認画面（交換履歴表示・交換登録を統合）

当初「台帳確認」と「設備交換履歴」は別画面だったが、設備一覧・選択UIがほぼ同一だったため1画面に統合した。設備を選択すると、構成要素（主装置・付属部品）ごとに、初回設置から現在までの個体の交換を「旧→新」のカード形式で時系列表示する（`view_equipment_installation_histories`(0005) を構成要素ごとに設置日でソートし、隣り合う2件を交換ペアとして組み立てている）。現在設置中の個体をクリックすると属性値・全設置履歴を表示する。

各構成要素の下にある「個体を交換する」（現在設置中の個体がある場合）・「個体を設置する」（未設置の場合）ボタンから、個体設置履歴テーブルを直接SQLで触らずに交換・設置を登録できる（詳細は次項）。

## 個体交換登録（モーダル）

「個体設置履歴テーブルを直接修正するのは大変」という要望から追加。ボタンを押すと以下を入力するモーダルが開く。

- 個体: 既存の個体から選択、または新しい個体をその場で登録（`individuals`テーブルの項目定義を再利用して入力フォームを動的生成）
- 交換日（または設置日）: 現在設置中の個体がある場合は、その設置日より後の日付のみ許可
- 備考: 交換理由など（新しい履歴レコードに記録）

登録処理は次の順で実行する。

1. （新規個体を選んだ場合）`individuals` にINSERT
2. 現在設置中の履歴があれば、そのレコードの `removed_date` を交換日でUPDATE（クローズ）
3. `individual_installation_histories` に新しいレコードをINSERT（`installed_date` = 交換日）

## 今後の想定

- 部門・役職ごとの閲覧・編集権限（RLSのきめ細かい制御）
- 台帳データ更新時のワークフロー
- i-CORUS（点検管理システム）との連携（`equipments`, `locations`, `equipment_types` がキーになる想定）
- 台帳確認画面の絞り込み条件の拡充（場所での検索を追加）
- 個体交換登録: 個体の重複設置チェック（同じ個体が別スロットにも「現在設置中」のまま残っていないかの検証）
