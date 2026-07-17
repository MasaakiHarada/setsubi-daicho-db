// API5: 撤去済み個体一覧出力API
// GET /functions/v1/export-removed-individuals?search=&system_category_kbn=&equipment_type_id=
// 設備側の絞り込み（API1と同じ条件）に一致する設備について、過去に撤去された（removed_dateが設定された）
// 個体設置履歴をすべて返す（現在設置中のものは対象外。API2・API3の「現在設置中」の逆にあたる）。
// 認証: リクエストヘッダー X-API-Key に、Secretsに設定したEXTERNAL_API_KEYと一致する値が必要。
import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const CORS_HEADERS: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "content-type, x-api-key",
  "Access-Control-Allow-Methods": "GET, OPTIONS",
};

function jsonResponse(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8", ...CORS_HEADERS },
  });
}

function errorResponse(message: string, status: number): Response {
  return jsonResponse({ error: message }, status);
}

function checkApiKey(req: Request): boolean {
  const key = req.headers.get("x-api-key");
  const expected = Deno.env.get("EXTERNAL_API_KEY");
  return !!expected && key === expected;
}

const SYSTEM_CATEGORY_LABELS: Record<number, string> = { 1: "施設", 2: "保線", 3: "機械", 4: "電力", 5: "信通" };

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { headers: CORS_HEADERS });
  }
  if (req.method !== "GET") {
    return errorResponse("GETメソッドのみ対応しています", 405);
  }
  if (!checkApiKey(req)) {
    return errorResponse("APIキーが無効です", 401);
  }

  try {
    const url = new URL(req.url);
    const search = (url.searchParams.get("search") || "").trim();
    const systemCategoryKbnParam = url.searchParams.get("system_category_kbn");
    const equipmentTypeIdParam = url.searchParams.get("equipment_type_id");

    if (systemCategoryKbnParam !== null && ![1, 2, 3, 4, 5].includes(Number(systemCategoryKbnParam))) {
      return errorResponse("system_category_kbnは1〜5の範囲で指定してください", 400);
    }
    if (equipmentTypeIdParam !== null && !Number.isInteger(Number(equipmentTypeIdParam))) {
      return errorResponse("equipment_type_idは整数で指定してください", 400);
    }

    // 設備側の絞り込み（API1と同じ条件）
    let eqQuery = supabase.from("view_equipments_list").select("*");
    if (systemCategoryKbnParam !== null) eqQuery = eqQuery.eq("system_category_kbn", Number(systemCategoryKbnParam));
    if (equipmentTypeIdParam !== null) eqQuery = eqQuery.eq("equipment_type_id", Number(equipmentTypeIdParam));

    const { data: eqData, error: eqError } = await eqQuery;
    if (eqError) return errorResponse(eqError.message, 500);

    let equipments = eqData || [];
    if (search) {
      const s = search.toLowerCase();
      equipments = equipments.filter((e: any) =>
        [e.equipment_name, e.location_name_from, e.location_name_to].filter(Boolean).join(" ").toLowerCase().includes(s)
      );
    }

    if (!equipments.length) {
      return jsonResponse({ generated_at: new Date().toISOString(), count: 0, items: [] });
    }

    const equipmentInfoMap = new Map(equipments.map((e: any) => [e.id, e]));
    const equipmentIds = equipments.map((e: any) => e.id);

    // 撤去済み（removed_dateが設定されている）履歴のみを対象とする
    const { data: histories, error: histErr } = await supabase
      .from("view_equipment_installation_histories")
      .select("*")
      .in("equipment_id", equipmentIds)
      .not("removed_date", "is", null)
      .order("removed_date", { ascending: false });
    if (histErr) return errorResponse(histErr.message, 500);

    const items = (histories || []).map((h: any) => {
      const eq: any = equipmentInfoMap.get(h.equipment_id) || {};
      return {
        history_id: h.history_id,
        individual_id: h.individual_id,
        individual_name: h.individual_name,
        maker_name: h.maker_name,
        model_number: h.model_number,
        serial_number: h.serial_number,
        equipment_id: h.equipment_id,
        equipment_name: eq.equipment_name ?? null,
        equipment_type_id: eq.equipment_type_id ?? null,
        equipment_type_name: eq.equipment_type_name ?? null,
        system_category_kbn: eq.system_category_kbn ?? null,
        system_category_name: eq.system_category_kbn != null ? SYSTEM_CATEGORY_LABELS[eq.system_category_kbn] ?? null : null,
        component_id: h.component_id,
        component_name: h.component_name,
        installed_date: h.installed_date,
        removed_date: h.removed_date,
        note: h.note,
      };
    });

    return jsonResponse({
      generated_at: new Date().toISOString(),
      count: items.length,
      items,
    });
  } catch (e) {
    return errorResponse(String((e as any)?.message ?? e), 500);
  }
});
