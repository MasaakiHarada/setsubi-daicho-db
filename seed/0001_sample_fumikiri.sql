-- サンプルデータ：〇〇踏切（設備種別＝踏切）1台分
-- 「20251106 設備台帳管理システムに関する鉄道総研様お打合せ資料.pptx」に登場する
-- 名称・構成（上りS方遮断機、下りS方遮断機、踏切制御箱、障検制御箱(3Dセンサ式)等）に基づく。
--
-- 要件④（個体の設置場所が変わることを想定し履歴を管理）の例として、
-- 上りS方遮断機の個体は旧個体(id=15, 2018年設置→2021年撤去)から
-- 新個体(id=1, 2021年設置、現在設置中)への更新履歴を含む。
--
-- 0004マイグレーション以降、設備名称・個体名称は専用列(equipment_name/individual_name)
-- に分離しているため、本シードでもそちらに値を設定し、備考(note)はNULLとしている。

-- 1. 設備種別
INSERT INTO equipment_types (id, equipment_type_name, system_category_kbn, equipment_form_kbn) VALUES
(1, '踏切', 5, 1);

-- 2. 場所
INSERT INTO locations (id, location_type_kbn, location_name, parent_location_id, kilo_post, display_order) VALUES
(1, 3, '〇〇踏切', NULL, 12.500, 1);

-- 3. 製品種別
INSERT INTO product_categories (id, product_category_name) VALUES
(1, '遮断機本体'),
(2, 'リレー'),
(3, '踏切制御箱本体'),
(4, '障検制御箱本体(3Dセンサ式)'),
(5, '3Dセンサ');

-- 4. 設備
INSERT INTO equipments (id, equipment_name, equipment_type_id, location_id_from, location_id_to, install_date, note) VALUES
(1, '〇〇踏切', 1, 1, NULL, '2021-03-01', NULL);

-- 5. 構成要素
INSERT INTO equipment_type_components (id, equipment_type_id, parent_component_id, component_name, display_order) VALUES
(1, 1, NULL, '上りS方遮断機', 1),
(2, 1, NULL, '下りS方遮断機', 2),
(3, 1, NULL, '踏切制御箱', 3),
(4, 1, NULL, '障検制御箱(3Dセンサ式)', 4),
(5, 1, 1, 'CR1リレー', 1),
(6, 1, 1, 'CR2リレー', 2),
(7, 1, 2, 'CR1リレー', 1),
(8, 1, 2, 'CR2リレー', 2),
(9, 1, 3, '△△リレー①', 1),
(10, 1, 3, '△△リレー②', 2),
(11, 1, 3, '△△リレー③', 3),
(12, 1, 4, '3DLRセンサ1', 1),
(13, 1, 4, '3DLRセンサ2', 2),
(14, 1, 4, '◇◇リレー', 3);

-- 6. 属性定義
INSERT INTO attribute_definitions (id, product_category_id, attribute_name, data_type_kbn, unit, display_order) VALUES
(1, 1, '定格電流', 1, 'A', 1),
(2, 1, '保持電流', 1, 'A', 2),
(3, 2, '接点構成', 2, NULL, 1),
(4, 2, '動作電圧', 1, 'V', 2),
(5, 3, '電源電圧', 1, 'V', 1),
(6, 3, '回線数', 1, '回線', 2),
(7, 4, '検知方式', 2, NULL, 1),
(8, 4, '検知範囲', 1, 'm', 2),
(9, 5, '検知距離', 1, 'm', 1),
(10, 5, '視野角', 1, '度', 2);

-- 7. 個体
INSERT INTO individuals (id, individual_name, product_category_id, maker_name, model_number, serial_number, manufactured_month, note) VALUES
(1, '上りS方遮断機用本体', 1, '日信', '〇〇型', 'SN-2021-0301', '2021-02-01', NULL),
(2, '下りS方遮断機用本体', 1, '日信', '〇〇型', 'SN-2021-0302', '2021-02-01', NULL),
(3, '上りCR1リレー', 2, NULL, NULL, 'RY-2021-101', '2021-02-01', NULL),
(4, '上りCR2リレー', 2, NULL, NULL, 'RY-2021-102', '2021-02-01', NULL),
(5, '下りCR1リレー', 2, NULL, NULL, 'RY-2021-103', '2021-02-01', NULL),
(6, '下りCR2リレー', 2, NULL, NULL, 'RY-2021-104', '2021-02-01', NULL),
(7, '踏切制御箱本体', 3, '〇〇電工', '〇〇型', 'SN-2021-0101', '2021-01-01', NULL),
(8, '踏切制御箱△△リレー①', 2, NULL, NULL, 'RY-2021-201', '2021-01-01', NULL),
(9, '踏切制御箱△△リレー②', 2, NULL, NULL, 'RY-2021-202', '2021-01-01', NULL),
(10, '踏切制御箱△△リレー③', 2, NULL, NULL, 'RY-2021-203', '2021-01-01', NULL),
(11, '障検制御箱本体', 4, 'IHI', '〇〇型', 'SN-2021-0102', '2021-01-01', NULL),
(12, '3DLRセンサ1', 5, 'IHI', '3DLR型', 'SN-2021-0103', '2021-01-01', NULL),
(13, '3DLRセンサ2', 5, 'IHI', '3DLR型', 'SN-2021-0104', '2021-01-01', NULL),
(14, '障検制御箱◇◇リレー', 2, NULL, NULL, 'RY-2021-204', '2021-01-01', NULL),
(15, '旧・上りS方遮断機用本体（更新済）', 1, '日信', '△△型', 'SN-2018-0099', '2018-05-01', NULL);

-- 8. 個体属性値
INSERT INTO individual_attribute_values (individual_id, attribute_definition_id, attribute_value) VALUES
(1, 1, '100'), (1, 2, '5'),
(2, 1, '100'), (2, 2, '5'),
(7, 5, '100'), (7, 6, '4'),
(11, 7, '3Dセンサ式'), (11, 8, '15'),
(12, 9, '20'), (12, 10, '90'),
(13, 9, '20'), (13, 10, '90');

-- 9. 個体設置履歴
INSERT INTO individual_installation_histories (id, individual_id, equipment_id, component_id, installed_date, removed_date, note) VALUES
(1, 1, 1, 1, '2021-03-01', NULL, NULL),
(2, 2, 1, 2, '2021-03-01', NULL, NULL),
(3, 3, 1, 5, '2021-03-01', NULL, NULL),
(4, 4, 1, 6, '2021-03-01', NULL, NULL),
(5, 5, 1, 7, '2021-03-01', NULL, NULL),
(6, 6, 1, 8, '2021-03-01', NULL, NULL),
(7, 7, 1, 3, '2021-02-15', NULL, NULL),
(8, 8, 1, 9, '2021-02-15', NULL, NULL),
(9, 9, 1, 10, '2021-02-15', NULL, NULL),
(10, 10, 1, 11, '2021-02-15', NULL, NULL),
(11, 11, 1, 4, '2021-02-15', NULL, NULL),
(12, 12, 1, 12, '2021-02-15', NULL, NULL),
(13, 13, 1, 13, '2021-02-15', NULL, NULL),
(14, 14, 1, 14, '2021-02-15', NULL, NULL),
(15, 15, 1, 1, '2018-06-01', '2021-02-28', 'モーター部老朽化により更新（要件④の例）');

-- シーケンスを投入済みの最大IDに合わせる（このファイルを空のDBに適用した場合用）
SELECT setval(pg_get_serial_sequence('equipment_types','id'), (SELECT MAX(id) FROM equipment_types));
SELECT setval(pg_get_serial_sequence('locations','id'), (SELECT MAX(id) FROM locations));
SELECT setval(pg_get_serial_sequence('product_categories','id'), (SELECT MAX(id) FROM product_categories));
SELECT setval(pg_get_serial_sequence('equipments','id'), (SELECT MAX(id) FROM equipments));
SELECT setval(pg_get_serial_sequence('equipment_type_components','id'), (SELECT MAX(id) FROM equipment_type_components));
SELECT setval(pg_get_serial_sequence('attribute_definitions','id'), (SELECT MAX(id) FROM attribute_definitions));
SELECT setval(pg_get_serial_sequence('individuals','id'), (SELECT MAX(id) FROM individuals));
SELECT setval(pg_get_serial_sequence('individual_installation_histories','id'), (SELECT MAX(id) FROM individual_installation_histories));
