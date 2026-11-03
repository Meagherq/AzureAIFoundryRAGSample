#!/usr/bin/env bash
set -euo pipefail

: "${FOUNDRY_PROJECT_ENDPOINT:?FOUNDRY_PROJECT_ENDPOINT is required}"
: "${FOUNDRY_AGENT_NAME:?FOUNDRY_AGENT_NAME is required}"
: "${ENABLE_M365_PUBLIC_ENDPOINT:?ENABLE_M365_PUBLIC_ENDPOINT is required}"
M365_AUTHORIZATION_SCHEME=${M365_AUTHORIZATION_SCHEME:-BotServiceRbac}

[[ "$FOUNDRY_PROJECT_ENDPOINT" =~ ^https://[^/?#[:space:]]+/[^?#[:space:]]+$ ]] || {
  printf 'FOUNDRY_PROJECT_ENDPOINT must use HTTPS and include a project path without a query string or fragment.\n' >&2
  exit 1
}
case "$ENABLE_M365_PUBLIC_ENDPOINT" in
  true|false) ;;
  *) printf 'ENABLE_M365_PUBLIC_ENDPOINT must be true or false.\n' >&2; exit 1 ;;
esac
case "$M365_AUTHORIZATION_SCHEME" in
  BotServiceRbac|BotServiceTenant) ;;
  *) printf 'M365_AUTHORIZATION_SCHEME must be BotServiceRbac or BotServiceTenant.\n' >&2; exit 1 ;;
esac
for dependency in az jq mktemp; do
  command -v "$dependency" >/dev/null || {
    printf 'Required command not found: %s\n' "$dependency" >&2
    exit 1
  }
done

agent_name=$(jq -rn --arg name "$FOUNDRY_AGENT_NAME" '$name | @uri')
url="${FOUNDRY_PROJECT_ENDPOINT%/}/agents/$agent_name?api-version=v1"
if response=$(az rest --method get --url "$url" --resource 'https://ai.azure.com' --output json); then
  :
else
  status=$?
  printf 'Reading agent endpoint configuration failed with exit code %s.\n' "$status" >&2
  exit "$status"
fi

if ! jq -e '
  .agent_endpoint | type == "object"
' <<< "$response" >/dev/null; then
  printf 'The agent response did not contain agent_endpoint as an object; endpoint configuration was not changed.\n' >&2
  exit 1
fi
if ! jq -e '
  .agent_endpoint |
  (.protocol_configuration == null or (.protocol_configuration | type == "object")) and
  (.protocol_configuration.activity == null or (.protocol_configuration.activity | type == "object")) and
  (.protocol_configuration.responses == null or (.protocol_configuration.responses | type == "object")) and
  (.authorization_schemes == null or (.authorization_schemes | type == "array" and all(.[]; type == "object" and (.type | type == "string"))))
' <<< "$response" >/dev/null; then
  printf 'The agent endpoint has invalid protocol or authorization configuration.\n' >&2
  exit 1
fi

if [[ "$ENABLE_M365_PUBLIC_ENDPOINT" == false ]] &&
  jq -e '.agent_endpoint.protocol_configuration // {} | has("activity") | not' <<< "$response" >/dev/null; then
  printf 'No Activity Protocol route exists; M365 public access remains disabled.\n'
  exit 0
fi

umask 077
payload_file=$(mktemp)
trap 'rm -f -- "$payload_file"' EXIT
jq --argjson enabled "$ENABLE_M365_PUBLIC_ENDPOINT" --arg scheme "$M365_AUTHORIZATION_SCHEME" '
  .agent_endpoint |
  {
    protocol_configuration: (.protocol_configuration // {}),
    authorization_schemes: (.authorization_schemes // [])
  } |
  .protocol_configuration.activity.enable_m365_public_endpoint = $enabled |
  if $enabled then
    .protocol_configuration.responses //= {} |
    .authorization_schemes |= map(select(.type != "BotServiceRbac" and .type != "BotServiceTenant")) |
    if any(.authorization_schemes[]; .type == "AzureRbac" or .type == "Entra") then .
    else .authorization_schemes += [{"type": "AzureRbac"}] end |
    .authorization_schemes += [{"type": $scheme}]
  else . end |
  {agent_endpoint: .}
' <<< "$response" > "$payload_file"

if az rest --method patch --url "$url" --resource 'https://ai.azure.com' \
  --headers 'Content-Type=application/merge-patch+json' --body "@$payload_file" --output none; then
  printf 'Agent endpoint configuration updated successfully.\n'
else
  status=$?
  printf 'Updating agent endpoint configuration failed with exit code %s.\n' "$status" >&2
  exit "$status"
fi
