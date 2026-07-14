-- ============================================================
-- equipments.equipment_name / individuals.individual_name を追加。
-- 従来は備考(note)欄に記載していた名称を専用列に分離する。
-- 備考は今後「名称以外の補足事項」用として残す（既存データはこちらに移行済みのためクリアする）。
-- ============================================================

ALTER TABLE equipments ADD COLUMN equipment_name VARCHAR(200);
UPDATE equipments SET equipment_name = note WHERE equipment_name IS NULL;
ALTER TABLE equipments ALTER COLUMN equipment_name SET NOT NULL;
UPDATE equipments SET note = NULL;
COMMENT ON COLUMN equipments.equipment_name IS '設備の名称（旧: 備考欄に記載していた内容をこちらに移行）';

ALTER TABLE individuals ADD COLUMN individual_name VARCHAR(200);
UPDATE individuals SET individual_name = note WHERE individual_name IS NULL;
ALTER TABLE individuals ALTER COLUMN individual_name SET NOT NULL;
UPDATE individuals SET note = NULL;
COMMENT ON COLUMN individuals.individual_name IS '個体の名称（旧: 備考欄に記載していた内容をこちらに移行）';

-- 台帳確認画面向けビューにも名称列を追加（既存列の位置は変更できないため末尾に追加）
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
    e.note,
    e.equipment_name
FROM equipments e
JOIN equipment_types et ON et.id = e.equipment_type_id
JOIN locations lf ON lf.id = e.location_id_from
LEFT JOIN locations lt ON lt.id = e.location_id_to;

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
    h.installed_date,
    i.individual_name
FROM individual_installation_histories h
JOIN equipment_type_components c ON c.id = h.component_id
JOIN individuals i ON i.id = h.individual_id
JOIN product_categories pc ON pc.id = i.product_category_id
WHERE h.removed_date IS NULL;
