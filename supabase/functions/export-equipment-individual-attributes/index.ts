// API4: 設備個体属性値出力API（横持ち）
// GET /functions/v1/export-equipment-individual-attributes?equipment_id=
// 選択した設備1台分の、現在設置されている個体の属性値を製品種別ごとにグルーピングして返す。
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
    const equipmentIdParam = url.searchParams.get("equipment_id");
    if (equipmentIdParam === null || !Number.isInteger(Number(equipmentIdParam))) {
      return errorResponse("equipment_idは必須です（整数で指定してください）", 400);
    }
    const equipmentId = Number(equipmentIdParam);

    const { data: eq, error: eqErr } = await supabase
      .from("view_equipments_list")
      .select("*")
      .eq("id", equipmentId)
      .maybeSingle();
    if (eqErr) return errorResponse(eqErr.message, 500);
    if (!eq) return errorResponse(`equipment_id=${equipmentId} の設備が見つかりません`, 404);

    const { data: curInd, error: curErr } = await supabase
      .from("view_equipment_current_individuals")
      .select("*")
      .eq("equipment_id", equipmentId)
      .order("component_id", { ascending: true });
    if (curErr) return errorResponse(curErr.message, 500);

    if (!curInd || !curInd.length) {
      return jsonResponse({
        generated_at: new Date().toISOString(),
        equipment_id: equipmentId,
        equipment_name: eq.equipment_name,
        categories: [],
      });
    }

    const individualIds = curInd.map((r: any) => r.individual_id);
    const { data: attrs, error: attrErr } = await supabase
      .from("view_individual_attributes")
      .select("*")
      .in("individual_id", individualIds)
      .order("display_order", { ascending: true });
    if (attrErr) return errorResponse(attrErr.message, 500);

    const attrsByIndividual = new Map<number, any[]>();
    (attrs || []).forEach((a: any) => {
      if (!attrsByIndividual.has(a.individual_id)) attrsByIndividual.set(a.individual_id, []);
      attrsByIndividual.get(a.individual_id)!.push(a);
    });

    const byCategory = new Map<string, any[]>();
    curInd.forEach((r: any) => {
      const key = r.product_category_name || "(未分類)";
      if (!byCategory.has(key)) byCategory.set(key, []);
      byCategory.get(key)!.push(r);
    });

    const categories = [...byCategory.entries()].map(([productCategoryName, individuals]) => ({
      product_category_name: productCategoryName,
      individuals: individuals.map((ind: any) => {
        const attrList = attrsByIndividual.get(ind.individual_id) || [];
        const attributes: Record<string, string | null> = {};
        attrList.forEach((a: any) => {
          attributes[a.attribute_name] = a.attribute_value;
        });
        return {
          individual_id: ind.individual_id,
          individual_name: ind.individual_name,
          component_name: ind.component_name,
          maker_name: ind.maker_name,
          model_number: ind.model_number,
          serial_number: ind.serial_number,
          attributes,
        };
      }),
    }));

    return jsonResponse({
      generated_at: new Date().toISOString(),
      equipment_id: equipmentId,
      equipment_name: eq.equipment_name,
      categories,
    });
  } catch (e) {
    return errorResponse(String((e as any)?.message ?? e), 500);
  }
});
