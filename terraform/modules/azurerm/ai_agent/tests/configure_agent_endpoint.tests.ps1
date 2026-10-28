$ErrorActionPreference = 'Stop'
$configureScript = Join-Path $PSScriptRoot '..\configure_agent_endpoint.ps1'
$testState = @{
    agentJson = ''
    patch = $null
    getExitCode = 0
    patchExitCode = 0
    payloadPath = ''
}

function az {
    $arguments = @($args)
    if ($arguments -contains 'get') {
        Set-Variable -Name LASTEXITCODE -Value $testState.getExitCode -Scope 1
        return $testState.agentJson
    }
    if ($arguments -notcontains 'patch') {
        throw 'Unexpected Azure CLI call.'
    }
    if ($arguments -notcontains 'Content-Type=application/merge-patch+json') {
        throw 'PATCH must use merge-patch content type.'
    }
    $bodyIndex = [Array]::IndexOf($arguments, '--body')
    $testState.payloadPath = $arguments[$bodyIndex + 1].Substring(1)
    $testState.patch = Get-Content -LiteralPath $testState.payloadPath -Raw | ConvertFrom-Json -AsHashtable
    Set-Variable -Name LASTEXITCODE -Value $testState.patchExitCode -Scope 1
}

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) {
        throw $Message
    }
}

function Invoke-Configuration([bool]$Enabled, [string]$Scheme = 'BotServiceRbac') {
    & $configureScript -ProjectEndpoint 'https://test.services.ai.azure.com/api/projects/test/' `
        -AgentName 'test-agent' -EnableM365PublicEndpoint $Enabled -AuthorizationScheme $Scheme
}

function Assert-Throws([scriptblock]$Action, [string]$Expected) {
    $message = ''
    try { & $Action } catch { $message = $_.Exception.Message }
    Assert-True ($message -like "*$Expected*") "Expected failure containing '$Expected', received '$message'."
}

$testState.agentJson = @'
{
  "agent_endpoint": {
    "protocol_configuration": {
      "responses": {"retained": true},
      "a2a": {},
      "activity": {"other_option": true}
    },
    "authorization_schemes": [
      {"type": "Entra", "retained": true},
      {"type": "BotServiceTenant"}
    ]
  }
}
'@

Invoke-Configuration $true
$endpoint = $testState.patch.agent_endpoint
Assert-True $endpoint.protocol_configuration.activity.enable_m365_public_endpoint 'M365 access must be enabled.'
Assert-True $endpoint.protocol_configuration.activity.other_option 'Existing Activity options must be preserved.'
Assert-True ($endpoint.protocol_configuration.ContainsKey('a2a')) 'Other protocols must be preserved.'
Assert-True $endpoint.protocol_configuration.responses.retained 'Responses configuration must be preserved.'
Assert-True ($endpoint.authorization_schemes.Count -eq 2) 'Replace the Bot Service scheme without duplicating direct-client authorization.'
Assert-True ($endpoint.authorization_schemes[0].type -eq 'Entra' -and $endpoint.authorization_schemes[0].retained) 'Preserve existing Entra authorization.'
Assert-True ($endpoint.authorization_schemes[1].type -eq 'BotServiceRbac') 'Shared publishing must use BotServiceRbac.'
Assert-True (-not (Test-Path -LiteralPath $testState.payloadPath)) 'Temporary payload must be removed after success.'

Invoke-Configuration $true 'BotServiceTenant'
Assert-True ($testState.patch.agent_endpoint.authorization_schemes[1].type -eq 'BotServiceTenant') 'Tenant publishing must use BotServiceTenant.'

Invoke-Configuration $false
Assert-True (-not $testState.patch.agent_endpoint.protocol_configuration.activity.enable_m365_public_endpoint) 'Turning the setting off must PATCH false.'
Assert-True ($testState.patch.agent_endpoint.authorization_schemes[1].type -eq 'BotServiceTenant') 'Disabling public access must preserve authorization.'

$testState.agentJson = '{"agent_endpoint":{"protocol_configuration":{"responses":{}},"authorization_schemes":[{"type":"AzureRbac"}]}}'
$testState.patch = $null
Invoke-Configuration $false
Assert-True ($null -eq $testState.patch) 'Disabled access on an unconfigured endpoint must not create Activity Protocol.'
Invoke-Configuration $true
Assert-True ($testState.patch.agent_endpoint.protocol_configuration.ContainsKey('activity')) 'Enabling must create the Activity Protocol configuration.'

$testState.agentJson = '{"agent_endpoint":{"protocol_configuration":{}}}'
Invoke-Configuration $true
Assert-True ($testState.patch.agent_endpoint.protocol_configuration.ContainsKey('responses')) 'Responses must remain available.'
Assert-True ($testState.patch.agent_endpoint.authorization_schemes[0].type -eq 'AzureRbac') 'Missing direct-client authorization must get AzureRbac.'

$testState.getExitCode = 1
Assert-Throws { Invoke-Configuration $true } 'Reading agent endpoint configuration failed'
$testState.getExitCode = 0
$testState.patchExitCode = 1
Assert-Throws { Invoke-Configuration $true } 'Updating agent endpoint configuration failed'
Assert-True (-not (Test-Path -LiteralPath $testState.payloadPath)) 'Temporary payload must be removed after failure.'
$testState.patchExitCode = 0
$testState.agentJson = '{}'
Assert-Throws { Invoke-Configuration $true } 'did not contain agent_endpoint'
$testState.agentJson = 'not-json'
Assert-Throws { Invoke-Configuration $true } 'Conversion from JSON failed'

Write-Host 'All Activity Protocol endpoint configuration tests passed.'
