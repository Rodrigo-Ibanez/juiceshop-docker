param(
    [string]$BaseUrl = "https://127.0.0.1",
    [string]$HttpUrl = "http://127.0.0.1"
)

$ErrorActionPreference = "Continue"
$results = [System.Collections.Generic.List[object]]::new()

function Add-Result {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Details
    )

    $script:results.Add([pscustomobject]@{
        Teste = $Name
        Resultado = if ($Passed) { "PASSOU" } else { "FALHOU" }
        Detalhes = $Details
    })
}

Write-Host "`n=== Validacao Juice Shop / Nginx ===" -ForegroundColor Cyan

# 1. Cluster kind
try {
    $clusters = kind get clusters 2>&1
    $clusterOk = ($LASTEXITCODE -eq 0) -and ($clusters -contains "juiceshop-local")
    Add-Result "Cluster kind" $clusterOk ($clusters -join "; ")
}
catch {
    Add-Result "Cluster kind" $false $_.Exception.Message
}

# 2. Replicas Kubernetes
try {
    $deployment = kubectl get deployment juice-shop -n juiceshop `
        -o jsonpath="{.status.readyReplicas}/{.spec.replicas}" 2>&1
    $deploymentOk = ($LASTEXITCODE -eq 0) -and ("$deployment" -eq "2/2")
    Add-Result "Replicas Kubernetes" $deploymentOk "$deployment prontas"
}
catch {
    Add-Result "Replicas Kubernetes" $false $_.Exception.Message
}

# 3. Nginx e upstream
$nginxExists = docker container inspect juice-shop-nginx-edge 2>$null
if ($LASTEXITCODE -eq 0) {
    $nginxState = docker inspect -f "{{.State.Running}}" juice-shop-nginx-edge 2>$null

    if ($nginxState -eq "true") {
        docker exec juice-shop-nginx-edge nginx -t 2>&1 | Out-Host
        $nginxTestOk = $LASTEXITCODE -eq 0
        Add-Result "Configuracao Nginx" $nginxTestOk "Resultado de nginx -t"

        $nginxConfig = docker exec juice-shop-nginx-edge nginx -T 2>&1
        $upstreamOk = ($LASTEXITCODE -eq 0) -and (
            ($nginxConfig -join "`n") -match
            'proxy_pass\s+http://juiceshop-local-control-plane:30080;'
        )
        Add-Result "Upstream por nome" $upstreamOk "Nome do no do kind"

        $ports = docker port juice-shop-nginx-edge 2>&1
        $portsText = $ports -join "`n"
        $portsOk = ($LASTEXITCODE -eq 0) -and
            ($portsText -match '80/tcp\s+->\s+127\.0\.0\.1:80') -and
            ($portsText -match '443/tcp\s+->\s+127\.0\.0\.1:443')
        Add-Result "Portas somente locais" $portsOk $portsText
    }
    else {
        Add-Result "Configuracao Nginx" $false "Container existe, mas esta parado"
        Add-Result "Upstream por nome" $false "Nginx parado"
        Add-Result "Portas somente locais" $false "Nginx parado"
    }
}
else {
    Add-Result "Configuracao Nginx" $false "Container Nginx nao esta presente"
    Add-Result "Upstream por nome" $false "Nao foi possivel inspecionar o Nginx"
    Add-Result "Portas somente locais" $false "Nao foi possivel verificar as portas"
}

# 4. HTTP deve redirecionar para HTTPS
try {
    $httpOutput = curl.exe -sS -D - -o NUL `
        -H "Host: juiceshop.local" $HttpUrl 2>&1

    $httpExitCode = $LASTEXITCODE
    $httpText = $httpOutput -join "`n"

    $httpCode = 0
    $location = ""

    if ($httpText -match '(?m)^HTTP/\S+\s+(\d{3})') {
        $httpCode = [int]$Matches[1]
    }

    if ($httpText -match '(?im)^Location:\s*(.+?)\s*$') {
        $location = $Matches[1].Trim()
    }

    $httpOk = ($httpExitCode -eq 0) -and
        ($httpCode -eq 301) -and
        ($location -match '^https://juiceshop\.local/')

    Add-Result "Redirecionamento HTTP" $httpOk `
        "HTTP=$httpCode; Location=$location"
}
catch {
    Add-Result "Redirecionamento HTTP" $false $_.Exception.Message
}

# 5. HTTPS e cabecalhos
try {
    $response = Invoke-WebRequest -Uri $BaseUrl `
        -Headers @{ Host = "juiceshop.local" } `
        -TimeoutSec 15 -UseBasicParsing -SkipCertificateCheck `
        -ErrorAction Stop

    $code = [int]$response.StatusCode
    $headers = $response.Headers

    Add-Result "Resposta HTTPS" ($code -eq 200) "HTTPS=$code"

    $expectedHeaders = @{
        "X-Content-Type-Options" = "nosniff"
        "X-Frame-Options" = "SAMEORIGIN"
        "Referrer-Policy" = "strict-origin-when-cross-origin"
        "Strict-Transport-Security" = "max-age=300"
    }

    foreach ($headerName in $expectedHeaders.Keys) {
        $actual = [string]$headers[$headerName]
        $ok = $actual -eq $expectedHeaders[$headerName]
        Add-Result "Cabecalho $headerName" $ok `
            "Esperado='$($expectedHeaders[$headerName])'; recebido='$actual'"
    }

    $serverHeader = [string]$headers["Server"]
    $serverTokensOk = $serverHeader -notmatch "nginx/\d"
    Add-Result "Ocultacao versao Nginx" $serverTokensOk "Server='$serverHeader'"
}
catch {
    Add-Result "Resposta HTTPS" $false $_.Exception.Message
    Add-Result "Cabecalhos de seguranca" $false "Nao foi possivel ler os cabecalhos HTTPS"
}

# 6. Relatorio
Write-Host "`n=== Resultados ===" -ForegroundColor Cyan
$results | Format-Table -AutoSize -Wrap

$failed = @($results | Where-Object { $_.Resultado -eq "FALHOU" }).Count
$passed = @($results | Where-Object { $_.Resultado -eq "PASSOU" }).Count

$reportDir = Join-Path $PSScriptRoot "..\docs\evidencias"
New-Item -ItemType Directory -Force $reportDir | Out-Null
$reportPath = Join-Path $reportDir "E10-validacao-automatica.txt"

@(
    "Validacao automatica Juice Shop"
    "Data: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    "Passou: $passed"
    "Falhou: $failed"
    ""
    ($results | Format-Table -AutoSize -Wrap | Out-String)
) | Set-Content -Path $reportPath -Encoding utf8

Write-Host "Relatorio: $reportPath"
Write-Host "Passou: $passed | Falhou: $failed"

if ($failed -gt 0) {
    exit 1
}
else {
    exit 0
}