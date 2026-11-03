#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
configure_script="$script_dir/../configure_agent_endpoint.sh"
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir "$test_dir/payloads"
export TMPDIR="$test_dir/payloads"
export TEST_CAPTURE="$test_dir"
export FOUNDRY_PROJECT_ENDPOINT='https://test.services.ai.azure.com/api/projects/test/'
export FOUNDRY_AGENT_NAME='test agent/with?symbols'
export ENABLE_M365_PUBLIC_ENDPOINT=true
export M365_AUTHORIZATION_SCHEME=BotServiceRbac
export GET_EXIT_CODE=0 PATCH_EXIT_CODE=0

az() {
  local method='' url='' resource='' headers='' body='' output=''
  [[ "${1:-}" == rest ]] || return 90
  shift
  while (($#)); do
    case "$1" in
      --method) method=$2 ;;
      --url) url=$2 ;;
      --resource) resource=$2 ;;
      --headers) headers=$2 ;;
      --body) body=$2 ;;
      --output) output=$2 ;;
      *) printf 'Unexpected Azure CLI argument: %s\n' "$1" >&2; return 91 ;;
    esac
    shift 2
  done
  [[ "$url" == 'https://test.services.ai.azure.com/api/projects/test/agents/test%20agent%2Fwith%3Fsymbols?api-version=v1' &&
    "$resource" == 'https://ai.azure.com' ]] || return 92
  printf '%s\n' "$method" >> "$TEST_CAPTURE/calls"
  case "$method" in
    get)
      [[ "$output" == json ]] || return 93
      printf '%s\n' "$AGENT_JSON"
      return "$GET_EXIT_CODE"
      ;;
    patch)
      [[ "$headers" == 'Content-Type=application/merge-patch+json' && "$output" == none && "$body" == @* ]] || return 94
      [[ "$(stat -c '%a' "${body#@}")" == 600 ]] || return 96
      printf '%s' "${body#@}" > "$TEST_CAPTURE/payload_path"
      cp -- "${body#@}" "$TEST_CAPTURE/patch.json"
      return "$PATCH_EXIT_CODE"
      ;;
    *) return 95 ;;
  esac
}
export -f az

assert_patch() {
  jq -e "$1" "$test_dir/patch.json" >/dev/null || {
    printf 'Payload assertion failed: %s\n' "$1" >&2
    exit 1
  }
}
assert_cleaned() {
  [[ ! -e "$(cat "$test_dir/payload_path")" ]] || {
    printf 'Temporary payload was not removed.\n' >&2
    exit 1
  }
}
assert_failure() {
  local expected=$1 status=0
  bash "$configure_script" > "$test_dir/output" 2>&1 || status=$?
  [[ "$status" -ne 0 ]] && grep -Fq "$expected" "$test_dir/output" || {
    printf 'Expected failure containing: %s\n' "$expected" >&2
    cat "$test_dir/output" >&2
    exit 1
  }
}

export AGENT_JSON='{
  "agent_endpoint": {
    "protocol_configuration": {
      "responses": {"retained": true}, "a2a": {}, "activity": {"other_option": true}
    },
    "authorization_schemes": [{"type": "Entra", "retained": true}, {"type": "BotServiceTenant"}]
  }
}'
bash "$configure_script"
assert_patch '.agent_endpoint |
  .protocol_configuration.activity.enable_m365_public_endpoint == true and
  .protocol_configuration.activity.other_option == true and
  .protocol_configuration.a2a == {} and
  .protocol_configuration.responses.retained == true and
  .authorization_schemes == [{"type":"Entra","retained":true},{"type":"BotServiceRbac"}]'
assert_cleaned

export M365_AUTHORIZATION_SCHEME=BotServiceTenant
bash "$configure_script"
assert_patch '.agent_endpoint.authorization_schemes[1].type == "BotServiceTenant"'
# Feed the patched state back to check repeated configuration is idempotent.
export AGENT_JSON
AGENT_JSON=$(cat "$test_dir/patch.json")
bash "$configure_script"
assert_patch '.agent_endpoint.authorization_schemes | length == 2'
export ENABLE_M365_PUBLIC_ENDPOINT=false
bash "$configure_script"
assert_patch '.agent_endpoint |
  .protocol_configuration.activity.enable_m365_public_endpoint == false and
  .authorization_schemes[1].type == "BotServiceTenant"'

export AGENT_JSON='{"agent_endpoint":{"protocol_configuration":{"responses":{}},"authorization_schemes":[{"type":"AzureRbac"}]}}'
rm -f -- "$test_dir/patch.json"
bash "$configure_script"
[[ ! -e "$test_dir/patch.json" ]]
export ENABLE_M365_PUBLIC_ENDPOINT=true
bash "$configure_script"
assert_patch '.agent_endpoint |
  .protocol_configuration.activity.enable_m365_public_endpoint == true and
  .authorization_schemes == [{"type":"AzureRbac"},{"type":"BotServiceTenant"}]'

export AGENT_JSON='{"agent_endpoint":{}}'
bash "$configure_script"
assert_patch '.agent_endpoint |
  .protocol_configuration.responses == {} and
  .authorization_schemes == [{"type":"AzureRbac"},{"type":"BotServiceTenant"}]'

export GET_EXIT_CODE=17
assert_failure 'Reading agent endpoint configuration failed with exit code 17'
export GET_EXIT_CODE=0 PATCH_EXIT_CODE=23
assert_failure 'Updating agent endpoint configuration failed with exit code 23'
assert_cleaned
export PATCH_EXIT_CODE=0 AGENT_JSON='{}'
assert_failure 'did not contain agent_endpoint'
export AGENT_JSON='not-json'
assert_failure 'did not contain agent_endpoint'
for invalid_endpoint in \
  '{"protocol_configuration":[]}' \
  '{"protocol_configuration":false}' \
  '{"protocol_configuration":{"activity":"invalid"}}' \
  '{"protocol_configuration":{"responses":[]}}' \
  '{"authorization_schemes":{}}' \
  '{"authorization_schemes":false}' \
  '{"authorization_schemes":[null]}' \
  '{"authorization_schemes":[{}]}'; do
  export AGENT_JSON="{\"agent_endpoint\":$invalid_endpoint}"
  assert_failure 'invalid protocol or authorization configuration'
done
export ENABLE_M365_PUBLIC_ENDPOINT=invalid
assert_failure 'must be true or false'
export ENABLE_M365_PUBLIC_ENDPOINT=true M365_AUTHORIZATION_SCHEME=Anonymous
assert_failure 'must be BotServiceRbac or BotServiceTenant'
export M365_AUTHORIZATION_SCHEME=BotServiceRbac FOUNDRY_AGENT_NAME=''
assert_failure 'FOUNDRY_AGENT_NAME is required'
export FOUNDRY_AGENT_NAME='test agent/with?symbols' FOUNDRY_PROJECT_ENDPOINT='http://invalid'
assert_failure 'must use HTTPS'
export FOUNDRY_PROJECT_ENDPOINT='https://test.services.ai.azure.com/api/projects/test/?query=invalid'
assert_failure 'without a query string or fragment'
export FOUNDRY_PROJECT_ENDPOINT='https://test.services.ai.azure.com/api/projects/test/'
export AGENT_JSON='{"agent_endpoint":{}}'
unset M365_AUTHORIZATION_SCHEME
bash "$configure_script"
assert_patch '.agent_endpoint.authorization_schemes[1].type == "BotServiceRbac"'
assert_cleaned

printf 'All Activity Protocol endpoint configuration tests passed.\n'
