-- RLSを有効化し、認証済みユーザー(authenticated)のみ全テーブルの読み書きを許可する
-- anon(未認証)は一切アクセスできない
--
-- 注意: 現状は「認証済みなら誰でも全行を読み書きできる」という単純なポリシーです。
-- 部門・役職ごとの閲覧・編集権限（打合せ資料の要件⑤）は未実装で、将来の課題です。

ALTER TABLE public.equipment_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.product_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.equipment_type_components ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attribute_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.individuals ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.individual_attribute_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.individual_installation_histories ENABLE ROW LEVEL SECURITY;

CREATE POLICY "authenticated_full_access" ON public.equipment_types
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access" ON public.locations
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access" ON public.product_categories
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access" ON public.equipments
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access" ON public.equipment_type_components
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access" ON public.attribute_definitions
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access" ON public.individuals
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access" ON public.individual_attribute_values
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
CREATE POLICY "authenticated_full_access" ON public.individual_installation_histories
    FOR ALL TO authenticated USING (true) WITH CHECK (true);
