-- ============================================================
-- 設備台帳管理システム データベース 物理設計（PostgreSQL）
-- ============================================================
-- 論理設計で確定した9テーブルをそのままPostgreSQLに実装する。
-- 物理設計での追加事項:
--   1) 全テーブルに共通の作成日時(created_at)・更新日時(updated_at)列を追加
--   2) PKはBIGSERIAL、FKはBIGINTで統一
--   3) 区分(_kbn)列にCHECK制約で許容値を明示
--   4) FK列にインデックスを付与（検索性能のため）
--   5) 個体設置履歴に「現在有効な設置は1件のみ」を保証する部分UNIQUEインデックスを追加
--   6) equipments のUNIQUE制約は、線ものの終点(location_id_to)がNULLになる場合
--      （箱もの）でも正しく重複を防げるよう、COALESCEを使った関数インデックスにした
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. 設備種別 (equipment_types) : マスタ。設備の"クラス"
-- ------------------------------------------------------------
CREATE TABLE equipment_types (
    id                    BIGSERIAL PRIMARY KEY,
    equipment_type_name   VARCHAR(100) NOT NULL,
    system_category_kbn   INTEGER NOT NULL CHECK (system_category_kbn IN (1,2,3,4,5)),
        -- 1:施設 2:保線 3:機械 4:電力 5:信通
    equipment_form_kbn    INTEGER NOT NULL CHECK (equipment_form_kbn IN (1,2)),
        -- 1:箱もの 2:線もの
    created_at            TIMESTAMP(6) NOT NULL DEFAULT now(),
    updated_at            TIMESTAMP(6) NOT NULL DEFAULT now()
);
COMMENT ON TABLE  equipment_types IS '設備種別マスタ（転てつ機、踏切など。オブジェクト指向で言う"クラス"）';
COMMENT ON COLUMN equipment_types.system_category_kbn IS '1:施設 2:保線 3:機械 4:電力 5:信通';
COMMENT ON COLUMN equipment_types.equipment_form_kbn IS '1:箱もの 2:線もの';

-- ------------------------------------------------------------
-- 2. 場所 (locations) : マスタ。駅・機器室・キロ程・支持物
-- ------------------------------------------------------------
CREATE TABLE locations (
    id                    BIGSERIAL PRIMARY KEY,
    location_type_kbn     INTEGER NOT NULL CHECK (location_type_kbn IN (1,2,3,4)),
        -- 1:駅 2:機器室 3:キロ程 4:支持物
    location_name         VARCHAR(200) NOT NULL,
    parent_location_id    BIGINT REFERENCES locations(id) ON DELETE RESTRICT,
    kilo_post             NUMERIC(8,3),
    display_order         INTEGER,
    created_at            TIMESTAMP(6) NOT NULL DEFAULT now(),
    updated_at            TIMESTAMP(6) NOT NULL DEFAULT now()
);
COMMENT ON TABLE  locations IS '場所マスタ（駅・機器室・キロ程・支持物）。親場所IDで階層を表現';
COMMENT ON COLUMN locations.location_type_kbn IS '1:駅 2:機器室 3:キロ程 4:支持物';
CREATE INDEX ix_locations_parent ON locations(parent_location_id);

-- ------------------------------------------------------------
-- 3. 製品種別 (product_categories) : マスタ。個体の属性スキーマ分類
-- ------------------------------------------------------------
CREATE TABLE product_categories (
    id                       BIGSERIAL PRIMARY KEY,
    product_category_name    VARCHAR(100) NOT NULL UNIQUE,
    created_at               TIMESTAMP(6) NOT NULL DEFAULT now(),
    updated_at                TIMESTAMP(6) NOT NULL DEFAULT now()
);
COMMENT ON TABLE product_categories IS '製品種別マスタ（リレー、遮断機本体、空調機室内ユニット等）。個体の属性スキーマを決める';

-- ------------------------------------------------------------
-- 4. 設備 (equipments) : 設備種別×場所で決まるインスタンス
-- ------------------------------------------------------------
CREATE TABLE equipments (
    id                    BIGSERIAL PRIMARY KEY,
    equipment_type_id     BIGINT NOT NULL REFERENCES equipment_types(id) ON DELETE RESTRICT,
    location_id_from      BIGINT NOT NULL REFERENCES locations(id) ON DELETE RESTRICT,
    location_id_to        BIGINT REFERENCES locations(id) ON DELETE RESTRICT,
        -- 箱ものはNULL（単独の場所）。線ものは終点を指定
    install_date          DATE,
    note                   VARCHAR(500),
    created_at             TIMESTAMP(6) NOT NULL DEFAULT now(),
    updated_at             TIMESTAMP(6) NOT NULL DEFAULT now()
);
COMMENT ON TABLE equipments IS '設備（設備種別×場所で決まるインスタンス。i-CORUSの設備マスタとの連携キーとなる想定）';
CREATE INDEX ix_equipments_type ON equipments(equipment_type_id);
CREATE INDEX ix_equipments_loc_from ON equipments(location_id_from);
CREATE INDEX ix_equipments_loc_to ON equipments(location_id_to);

-- 箱もの(location_id_to IS NULL)の場合も重複防止できるよう、
-- location_id_to が NULL のときは location_id_from と同一視して一意性を判定する
CREATE UNIQUE INDEX ux_equipments_type_location
    ON equipments (equipment_type_id, location_id_from, COALESCE(location_id_to, location_id_from));

-- ------------------------------------------------------------
-- 5. 構成要素 (equipment_type_components) : 設備種別を構成する主装置/付属部品
-- ------------------------------------------------------------
CREATE TABLE equipment_type_components (
    id                    BIGSERIAL PRIMARY KEY,
    equipment_type_id     BIGINT NOT NULL REFERENCES equipment_types(id) ON DELETE RESTRICT,
    parent_component_id   BIGINT REFERENCES equipment_type_components(id) ON DELETE RESTRICT,
        -- NULL:主装置（トップレベル）  非NULL:付属部品（親の下位）
    component_name        VARCHAR(100) NOT NULL,
    display_order          INTEGER,
    created_at             TIMESTAMP(6) NOT NULL DEFAULT now(),
    updated_at             TIMESTAMP(6) NOT NULL DEFAULT now()
);
COMMENT ON TABLE equipment_type_components IS '構成要素マスタ（設備種別を構成する主装置・付属部品。親構成要素IDで階層を表現）';
CREATE INDEX ix_components_type ON equipment_type_components(equipment_type_id);
CREATE INDEX ix_components_parent ON equipment_type_components(parent_component_id);

-- ------------------------------------------------------------
-- 6. 属性定義 (attribute_definitions) : 製品種別ごとの管理項目定義
-- ------------------------------------------------------------
CREATE TABLE attribute_definitions (
    id                    BIGSERIAL PRIMARY KEY,
    product_category_id   BIGINT NOT NULL REFERENCES product_categories(id) ON DELETE RESTRICT,
    attribute_name         VARCHAR(100) NOT NULL,
    data_type_kbn          INTEGER NOT NULL CHECK (data_type_kbn IN (1,2,3,4)),
        -- 1:数値 2:文字 3:日付 4:真偽
    unit                    VARCHAR(20),
    display_order           INTEGER,
    created_at               TIMESTAMP(6) NOT NULL DEFAULT now(),
    updated_at               TIMESTAMP(6) NOT NULL DEFAULT now(),
    UNIQUE (product_category_id, attribute_name)
);
COMMENT ON TABLE attribute_definitions IS '属性定義マスタ（製品種別ごとに管理項目を定義。要件②対応）';
COMMENT ON COLUMN attribute_definitions.data_type_kbn IS '1:数値 2:文字 3:日付 4:真偽';
CREATE INDEX ix_attrdefs_category ON attribute_definitions(product_category_id);

-- ------------------------------------------------------------
-- 7. 個体 (individuals) : 現地に設置される物理製品
-- ------------------------------------------------------------
CREATE TABLE individuals (
    id                    BIGSERIAL PRIMARY KEY,
    product_category_id   BIGINT NOT NULL REFERENCES product_categories(id) ON DELETE RESTRICT,
    maker_name              VARCHAR(100),
    model_number             VARCHAR(100),
    serial_number             VARCHAR(100),
    manufactured_month        DATE,
    note                       VARCHAR(500),
    created_at                 TIMESTAMP(6) NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMP(6) NOT NULL DEFAULT now()
);
COMMENT ON TABLE individuals IS '個体（主装置・付属部品として現地に設置される物理製品。メーカー・型式・製造番号を持つ）';
CREATE INDEX ix_individuals_category ON individuals(product_category_id);

-- ------------------------------------------------------------
-- 8. 個体属性値 (individual_attribute_values) : EAV方式の可変属性値
-- ------------------------------------------------------------
CREATE TABLE individual_attribute_values (
    individual_id           BIGINT NOT NULL REFERENCES individuals(id) ON DELETE CASCADE,
    attribute_definition_id  BIGINT NOT NULL REFERENCES attribute_definitions(id) ON DELETE RESTRICT,
    attribute_value           VARCHAR(500),
    created_at                 TIMESTAMP(6) NOT NULL DEFAULT now(),
    updated_at                  TIMESTAMP(6) NOT NULL DEFAULT now(),
    PRIMARY KEY (individual_id, attribute_definition_id)
);
COMMENT ON TABLE individual_attribute_values IS '個体属性値（製品ごとに可変な管理項目の値。EAV方式。要件②対応）';
CREATE INDEX ix_attrvalues_attrdef ON individual_attribute_values(attribute_definition_id);

-- ------------------------------------------------------------
-- 9. 個体設置履歴 (individual_installation_histories) : 設置スロットの変更履歴
-- ------------------------------------------------------------
CREATE TABLE individual_installation_histories (
    id                    BIGSERIAL PRIMARY KEY,
    individual_id          BIGINT NOT NULL REFERENCES individuals(id) ON DELETE CASCADE,
    equipment_id            BIGINT NOT NULL REFERENCES equipments(id) ON DELETE RESTRICT,
    component_id             BIGINT NOT NULL REFERENCES equipment_type_components(id) ON DELETE RESTRICT,
    installed_date            DATE NOT NULL,
    removed_date               DATE,
        -- NULL:現在設置中
    note                        VARCHAR(500),
    created_at                   TIMESTAMP(6) NOT NULL DEFAULT now(),
    updated_at                    TIMESTAMP(6) NOT NULL DEFAULT now(),
    CHECK (removed_date IS NULL OR removed_date >= installed_date)
);
COMMENT ON TABLE individual_installation_histories IS '個体設置履歴（個体がどの設備・構成要素スロットにいつ設置されていたか。要件④対応）';
CREATE INDEX ix_histories_individual ON individual_installation_histories(individual_id);
CREATE INDEX ix_histories_equipment ON individual_installation_histories(equipment_id);
CREATE INDEX ix_histories_component ON individual_installation_histories(component_id);

-- 同一スロット(設備×構成要素)に同時に有効な設置は1件のみ
CREATE UNIQUE INDEX ux_histories_active_slot
    ON individual_installation_histories (equipment_id, component_id)
    WHERE removed_date IS NULL;

-- 同一個体が同時に複数箇所に設置されていることを防ぐ
CREATE UNIQUE INDEX ux_histories_active_individual
    ON individual_installation_histories (individual_id)
    WHERE removed_date IS NULL;

COMMIT;
