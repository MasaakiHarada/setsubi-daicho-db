<#
  外部インターフェースAPI 動作確認スクリプト

  実行例:
    .\test_api.ps1 -ApiKey "実際のAPIキー"

  APIキーはSupabaseのSecrets（EXTERNAL_API_KEY）に設定した値と同じものを指定してください。
  未設定・不一致の場合はすべて401になります。

  文字化けする場合:
    - Windows Terminal / PowerShell 7 (pwsh) での実行を推奨
    - 古いコンソール(conhost)の場合は、実行前に "chcp 65001" を実行してください
#>

param(
    [string]$ApiKey = "",
    [string]$BaseUrl = "https://nbahkykcxlulzkafrmkf.supabase.co/functions/v1"
)

try {
    [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
    $OutputEncoding = [System.Text.Encoding]::UTF8
} catch {}

function Build-Url {
    param(
        [string]$BaseUrl,
        [string]$Path,
        [hashtable]$Query = @{}
    )

    $builder = New-Object System.UriBuilder("$BaseUrl/$Path")
    $pairs = New-Object System.Collections.Generic.List[string]
    foreach ($k in $Query.Keys) {
        $pairs.Add("$k=$([uri]::EscapeDataString([string]$Query[$k]))")
    }
    if ($pairs.Count -gt 0) {
        $builder.Query = [string]::Join("&", $pairs)
    }
    return $builder.Uri.AbsoluteUri
}

function Invoke-Api {
    param(
        [string]$Name,
        [string]$Path,
        [hashtable]$Query = @{},
        [string]$Key = $ApiKey,
        [switch]$OmitKey
    )

    $url = Build-Url -BaseUrl $BaseUrl -Path $Path -Query $Query

    Write-Host ""
    Write-Host "=== $Name ===" -ForegroundColor Cyan
    Write-Host "GET $url"

    $headers = @{}
    if (-not $OmitKey -and $Key) { $headers["X-API-Key"] = $Key }

    try {
        $resp = Invoke-WebRequest -Uri $url -Headers $headers -Method Get -UseBasicParsing -ErrorAction Stop
        Write-Host "Status: $($resp.StatusCode)" -ForegroundColor Green
        $bytes = $resp.RawContentStream.ToArray()
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
        $text | ConvertFrom-Json | ConvertTo-Json -Depth 10
    } catch {
        $ex = $_.Exception
        $statusCode = $null
        $bodyText = $null

        if ($ex.Response) {
            try { $statusCode = [int]$ex.Response.StatusCode } catch {}
            try {
                $stream = $ex.Response.GetResponseStream()
                if ($stream) {
                    $reader = New-Object System.IO.StreamReader($stream, [System.Text.Encoding]::UTF8)
                    $bodyText = $reader.ReadToEnd()
                    $reader.Close()
                }
            } catch {}
        }

        if (-not $bodyText -and $_.ErrorDetails -and $_.ErrorDetails.Message) {
            $bodyText = $_.ErrorDetails.Message
        }

        Write-Host "Status: $statusCode" -ForegroundColor Yellow
        if ($bodyText) { $bodyText } else { $ex.Message }
    }
}

if ($ApiKey) {
    Write-Host "APIキー: 指定あり"
} else {
    Write-Host "APIキー: 未指定（-ApiKeyパラメータなし。正常系のテストは401になります）" -ForegroundColor Yellow
}

$tests = @(
    @{ Name = "API1: 設備一覧出力API（全件）"; Path = "export-equipments"; Query = @{} },
    @{ Name = "API1: 設備一覧出力API（系統=信通のみ）"; Path = "export-equipments"; Query = @{ system_category_kbn = "5" } },
    @{ Name = "API2: 個体設置明細出力API"; Path = "export-individual-installations"; Query = @{} },
    @{ Name = "API3: 個体属性値一覧出力API（縦持ち）"; Path = "export-individual-attributes"; Query = @{} },
    @{ Name = "API4: 設備個体属性値出力API（横持ち・equipment_id=1）"; Path = "export-equipment-individual-attributes"; Query = @{ equipment_id = "1" } },
    @{ Name = "異常系: APIキー未指定 -> 401想定"; Path = "export-equipments"; Query = @{}; OmitKey = $true },
    @{ Name = "異常系: APIキー不正値 -> 401想定"; Path = "export-equipments"; Query = @{}; Key = "invalid-key" },
    @{ Name = "異常系: system_category_kbnが範囲外(9) -> 400想定"; Path = "export-equipments"; Query = @{ system_category_kbn = "9" } },
    @{ Name = "異常系: equipment_id未指定（API4） -> 400想定"; Path = "export-equipment-individual-attributes"; Query = @{} },
    @{ Name = "異常系: equipment_idに該当設備なし（API4） -> 404想定"; Path = "export-equipment-individual-attributes"; Query = @{ equipment_id = "999999" } }
)

foreach ($t in $tests) {
    Invoke-Api @t
}

Write-Host ""
Write-Host "テスト完了" -ForegroundColor Cyan
