<#
  外部インターフェースAPI 動作確認スクリプト

  実行例:
    .\test_api.ps1 -ApiKey "実際のAPIキー"

  APIキーはSupabaseのSecrets（EXTERNAL_API_KEY）に設定した値と同じものを指定してください。
  未設定・不一致の場合はすべて401になります。
#>

param(
    [string]$ApiKey = "",
    [string]$BaseUrl = "https://nbahkykcxlulzkafrmkf.supabase.co/functions/v1"
)

function Invoke-Api {
    param(
        [string]$Name,
        [string]$Path,
        [hashtable]$Query = @{},
        [string]$Key = $ApiKey,
        [switch]$OmitKey
    )

    $pairs = @()
    foreach ($k in $Query.Keys) {
        $pairs += "$k=$([uri]::EscapeDataString($Query[$k]))"
    }
    $qs = $pairs -join "&"
    $url = "$BaseUrl/$Path"
    if ($qs) { $url = "$url?$qs" }

    Write-Host ""
    Write-Host "=== $Name ===" -ForegroundColor Cyan
    Write-Host "GET $url"

    $headers = @{}
    if (-not $OmitKey -and $Key) { $headers["X-API-Key"] = $Key }

    try {
        $resp = Invoke-WebRequest -Uri $url -Headers $headers -Method Get -ErrorAction Stop
        Write-Host "Status: $($resp.StatusCode)" -ForegroundColor Green
        $resp.Content | ConvertFrom-Json | ConvertTo-Json -Depth 10
    } catch {
        $statusCode = $null
        if ($_.Exception.Response) {
            $statusCode = [int]$_.Exception.Response.StatusCode
        }
        Write-Host "Status: $statusCode" -ForegroundColor Yellow
        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
            $_.ErrorDetails.Message
        } else {
            $_.Exception.Message
        }
    }
}

if ($ApiKey) {
    Write-Host "APIキー: 指定あり"
} else {
    Write-Host "APIキー: 未指定（-ApiKeyパラメータなし。正常系のテストは401になります）" -ForegroundColor Yellow
}

# ---------- 正常系 ----------

Invoke-Api -Name "API1: 設備一覧出力API（全件）" `
    -Path "export-equipments"

Invoke-Api -Name "API1: 設備一覧出力API（系統=信通のみ）" `
    -Path "export-equipments" `
    -Query @{ system_category_kbn = "5" }

Invoke-Api -Name "API2: 個体設置明細出力API" `
    -Path "export-individual-installations"

Invoke-Api -Name "API3: 個体属性値一覧出力API（縦持ち）" `
    -Path "export-individual-attributes"

Invoke-Api -Name "API4: 設備個体属性値出力API（横持ち・equipment_id=1）" `
    -Path "export-equipment-individual-attributes" `
    -Query @{ equipment_id = "1" }

# ---------- 異常系 ----------

Invoke-Api -Name "異常系: APIキー未指定 -> 401想定" `
    -Path "export-equipments" `
    -OmitKey

Invoke-Api -Name "異常系: APIキー不正値 -> 401想定" `
    -Path "export-equipments" `
    -Key "invalid-key"

Invoke-Api -Name "異常系: system_category_kbnが範囲外(9) -> 400想定" `
    -Path "export-equipments" `
    -Query @{ system_category_kbn = "9" }

Invoke-Api -Name "異常系: equipment_id未指定（API4） -> 400想定" `
    -Path "export-equipment-individual-attributes"

Invoke-Api -Name "異常系: equipment_idに該当設備なし（API4） -> 404想定" `
    -Path "export-equipment-individual-attributes" `
    -Query @{ equipment_id = "999999" }

Write-Host ""
Write-Host "テスト完了" -ForegroundColor Cyan
