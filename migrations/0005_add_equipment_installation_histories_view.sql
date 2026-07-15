-- ============================================================
-- 設備交換履歴画面向け ビュー
-- 設備配下の全構成要素・全期間（現在・過去すべて）の設置履歴を、
-- 個体名・メーカー名等の情報付きで equipment_id から直接取得できるようにする。
-- security_invoker=true により、ビュー経由でも呼び出したユーザーの
-- 権限・RLSポリシーがそのまま適用される（既存ビューと同じ方針）。
-- ============================================================
CREATE OR REPLACE VIEW view_equipment_installation_histories
WITH (security_invoker = true) AS
SELECT
    h.id AS history_id,
    h.equipment_id,
    h.component_id,
    c.component_name,
    c.parent_component_id,
    h.individual_id,
    i.individual_name,
    i.maker_name,
    i.model_number,
    i.serial_number,
    h.installed_date,
    h.removed_date,
    h.note
FROM individual_installation_histories h
JOIN equipment_type_components c ON c.id = h.component_id
JOIN individuals i ON i.id = h.individual_id;

COMMENT ON VIEW view_equipment_installation_histories IS '設備交換履歴画面：設備配下の全構成要素・全期間の設置履歴（個体名付き、交換ペア表示用）';
