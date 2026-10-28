param(
    [Parameter(Mandatory)][string]$ProjectEndpoint,
    [Parameter(Mandatory)][string]$AgentName,
    [Parameter(Mandatory)][bool]$EnableM365PublicEndpoint,
    [ValidateSet('BotServiceRbac', 'BotServiceTenant')]
    [string]$AuthorizationScheme = 'BotServiceRbac'
)

$ErrorActionPreference = 'Stop'
$url = "$($ProjectEndpoint.TrimEnd('/'))/agents/$([Uri]::EscapeDataString($AgentName))?api-version=v1"
$response = az rest --method get --url $url --resource 'https://ai.azure.com' --output json
if ($LASTEXITCODE -ne 0) {
    throw "Reading agent endpoint configuration failed with exit code $LASTEXITCODE."
}

$agent = ($response -join "`n") | ConvertFrom-Json -AsHashtable
if (-not $agent.agent_endpoint) {
    throw 'The agent response did not contain agent_endpoint; endpoint configuration was not changed.'
}

$endpoint = $agent.agent_endpoint
$protocols = $endpoint.protocol_configuration
if ($null -eq $protocols) {
    $protocols = @{}
}
if (-not $EnableM365PublicEndpoint -and -not $protocols.ContainsKey('activity')) {
    Write-Host 'No Activity Protocol route exists; M365 public access remains disabled.'
    return
}

if (-not $protocols.ContainsKey('activity')) {
    $protocols.activity = @{}
}
$protocols.activity.enable_m365_public_endpoint = $EnableM365PublicEndpoint
$schemes = @($endpoint.authorization_schemes)
if ($EnableM365PublicEndpoint) {
    if (-not $protocols.ContainsKey('responses')) {
        $protocols.responses = @{}
    }
    $schemes = @($schemes | Where-Object {
        $null -ne $_ -and $_.type -notin @('BotServiceRbac', 'BotServiceTenant')
    })
    if (-not ($schemes | Where-Object { $_.type -in @('AzureRbac', 'Entra') })) {
        $schemes += @{ type = 'AzureRbac' }
    }
    $schemes += @{ type = $AuthorizationScheme }
}

$payload = @{
    agent_endpoint = @{
        protocol_configuration = $protocols
        authorization_schemes = $schemes
    }
}
$payloadFile = New-TemporaryFile
try {
    $payload | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $payloadFile.FullName -Encoding utf8NoBOM
    az rest --method patch --url $url --resource 'https://ai.azure.com' `
        --headers 'Content-Type=application/merge-patch+json' `
        --body "@$($payloadFile.FullName)" --output none
    if ($LASTEXITCODE -ne 0) {
        throw "Updating agent endpoint configuration failed with exit code $LASTEXITCODE."
    }
}
finally {
    Remove-Item -LiteralPath $payloadFile.FullName
}
