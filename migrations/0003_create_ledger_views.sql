-- ============================================================
-- 台帳確認画面向け ビュー
-- security_invoker=true により、ビュー経由でも呼び出したユーザーの
-- 権限・RLSポリシーがそのまま適用される（Supabase推奨設定）
-- ============================================================

-- 設備一覧（設備種別名・場所名付き）
CREATE OR REPLACE VIEW view_equipments_list
WITH (security_invoker = true) AS
SELECT
    e.id,
    e.equipment_type_id,
    et.equipment_type_name,
    et.system_category_kbn,
    et.equipment_form_kbn,
    e.location_id_from,
    lf.location_name AS location_name_from,
    e.location_id_to,
    lt.location_name AS location_name_to,
    e.install_date,
    e.note
FROM equipments e
JOIN equipment_types et ON et.id = e.equipment_type_id
JOIN locations lf ON lf.id = e.location_id_from
LEFT JOIN locations lt ON lt.id = e.location_id_to;

COMMENT ON VIEW view_equipments_list IS '台帳確認画面：設備一覧（種別名・場所名付き）';

-- 現在有効な設置（設備×構成要素にひも付く個体、removed_date IS NULLのみ）
CREATE OR REPLACE VIEW view_equipment_current_individuals
WITH (security_invoker = true) AS
SELECT
    h.id AS history_id,
    h.equipment_id,
    h.component_id,
    c.component_name,
    c.parent_component_id,
    h.individual_id,
    i.product_category_id,
    pc.product_category_name,
    i.maker_name,
    i.model_number,
    i.serial_number,
    i.manufactured_month,
    h.installed_date
FROM individual_installation_histories h
JOIN equipment_type_components c ON c.id = h.component_id
JOIN individuals i ON i.id = h.individual_id
JOIN product_categories pc ON pc.id = i.product_category_id
WHERE h.removed_date IS NULL;

COMMENT ON VIEW view_equipment_current_individuals IS '台帳確認画面：設備の構成要素ごとに現在設置されている個体';

-- 個体の属性値（属性名・単位付き）
CREATE OR REPLACE VIEW view_individual_attributes
WITH (security_invoker = true) AS
SELECT
    av.individual_id,
    ad.id AS attribute_definition_id,
    ad.attribute_name,
    ad.unit,
    ad.display_order,
    av.attribute_value
FROM individual_attribute_values av
JOIN attribute_definitions ad ON ad.id = av.attribute_definition_id;

COMMENT ON VIEW view_individual_attributes IS '台帳確認画面：個体属性値（属性名・単位付き。EAV方式の表示用）';

-- 個体の設置履歴（設備名・場所名・構成要素名付き、履歴含む全件）
CREATE OR REPLACE VIEW view_individual_installation_histories
WITH (security_invoker = true) AS
SELECT
    h.id AS history_id,
    h.individual_id,
    h.equipment_id,
    el.equipment_type_name,
    el.location_name_from,
    el.location_name_to,
    h.component_id,
    c.component_name,
    h.installed_date,
    h.removed_date,
    h.note
FROM individual_installation_histories h
JOIN view_equipments_list el ON el.id = h.equipment_id
JOIN equipment_type_components c ON c.id = h.component_id;

COMMENT ON VIEW view_individual_installation_histories IS '台帳確認画面：個体の設置履歴（現在・過去すべて）';
