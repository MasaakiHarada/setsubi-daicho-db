// API3: 個体属性値一覧出力API（縦持ち）
// GET /functions/v1/export-individual-attributes?search=&system_category_kbn=&equipment_type_id=
// 設備側の絞り込み（API1と同じ条件）に一致する設備に、現在設置されている個体の属性値をすべて返す。
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
    headers: { "Content-Type": "application/json", ...CORS_HEADERS },
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

    const equipmentIds = equipments.map((e: any) => e.id);
    const { data: curInd, error: curErr } = await supabase
      .from("view_equipment_current_individuals")
      .select("*")
      .in("equipment_id", equipmentIds);
    if (curErr) return errorResponse(curErr.message, 500);

    if (!curInd || !curInd.length) {
      return jsonResponse({ generated_at: new Date().toISOString(), count: 0, items: [] });
    }

    const individualIds = [...new Set(curInd.map((r: any) => r.individual_id))];
    const indInfoMap = new Map(curInd.map((r: any) => [r.individual_id, r]));

    const { data: attrs, error: attrErr } = await supabase
      .from("view_individual_attributes")
      .select("*")
      .in("individual_id", individualIds)
      .order("individual_id", { ascending: true })
      .order("display_order", { ascending: true });
    if (attrErr) return errorResponse(attrErr.message, 500);

    const items = (attrs || []).map((a: any) => {
      const info: any = indInfoMap.get(a.individual_id) || {};
      return {
        individual_id: a.individual_id,
        individual_name: info.individual_name ?? null,
        product_category_name: info.product_category_name ?? null,
        maker_name: info.maker_name ?? null,
        model_number: info.model_number ?? null,
        serial_number: info.serial_number ?? null,
        attribute_name: a.attribute_name,
        attribute_value: a.attribute_value,
        unit: a.unit,
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
