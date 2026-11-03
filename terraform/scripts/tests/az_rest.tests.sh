#!/usr/bin/env bash
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
rest_script="$script_dir/../az_rest.sh"
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT
mkdir "$test_dir/payloads"
export TMPDIR="$test_dir/payloads" TEST_CAPTURE="$test_dir"
export REST_METHOD=put
export REST_URL='https://test.search.windows.net/indexes/ragdocs?api-version=2024-07-01'
export REST_RESOURCE='https://search.azure.com'
export REST_PAYLOAD_BASE64
REST_PAYLOAD_BASE64=$(printf '%s' '{"name":"ragdocs","description":"UTF-8: \u00e9; quotes: \"hello\"; shell: $(false)"}' | base64)
export AZ_EXIT_CODE=0

az() {
  local method='' url='' resource='' headers='' prefer='' body='' output=''
  [[ "${1:-}" == rest ]] || return 90
  shift
  while (($#)); do
    case "$1" in
      --method) method=$2 ;;
      --url) url=$2 ;;
      --resource) resource=$2 ;;
      --headers)
        headers=$2
        shift 2
        if [[ "${1:-}" == Prefer=* ]]; then
          prefer=$1
          shift
        fi
        continue
        ;;
      --body) body=$2 ;;
      --output) output=$2 ;;
      *) printf 'Unexpected Azure CLI argument: %s\n' "$1" >&2; return 91 ;;
    esac
    shift 2
  done
  [[ "$method" == "$REST_METHOD" && "$url" == "$REST_URL" &&
    "$resource" == "$REST_RESOURCE" && "$headers" == 'Content-Type=application/json' &&
    "$body" == @* && "$output" == none ]] || return 92
  if [[ "$method" == put ]]; then
    [[ "$prefer" == 'Prefer=return=representation' ]] || return 94
  else
    [[ -z "$prefer" ]] || return 95
  fi
  [[ "$(stat -c '%a' "${body#@}")" == 600 ]] || return 93
  printf '%s' "${body#@}" > "$TEST_CAPTURE/payload_path"
  cp -- "${body#@}" "$TEST_CAPTURE/payload.json"
  return "$AZ_EXIT_CODE"
}
export -f az

assert_cleaned() {
  [[ ! -e "$(cat "$test_dir/payload_path")" ]]
  [[ -z "$(find "$TMPDIR" -type f -print -quit)" ]]
}
assert_failure() {
  local expected_status=$1 status=0
  bash "$rest_script" > "$test_dir/output" 2>&1 || status=$?
  [[ "$status" -eq "$expected_status" ]] || {
    printf 'Expected exit code %s, received %s.\n' "$expected_status" "$status" >&2
    cat "$test_dir/output" >&2
    exit 1
  }
}

bash "$rest_script"
jq -e '.name == "ragdocs" and (.description | contains("$(false)"))' "$test_dir/payload.json" >/dev/null
cmp "$test_dir/payload.json" <(printf '%s' "$REST_PAYLOAD_BASE64" | base64 --decode)
assert_cleaned

export REST_METHOD=post REST_RESOURCE='https://ai.azure.com'
export REST_URL='https://test.services.ai.azure.com/api/projects/test/agents/test-agent/versions?api-version=v1'
bash "$rest_script"
assert_cleaned
export AZ_EXIT_CODE=42
assert_failure 42
grep -Fq 'REST request failed with exit code 42' "$test_dir/output"
assert_cleaned
export AZ_EXIT_CODE=0 REST_PAYLOAD_BASE64=invalid-base64
assert_failure 1
assert_cleaned
for invalid_json in 'not-json' '[]' '{}' 'null' '{"one":1} {"two":2}'; do
  REST_PAYLOAD_BASE64=$(printf '%s' "$invalid_json" | base64)
  status=0
  bash "$rest_script" > "$test_dir/output" 2>&1 || status=$?
  [[ "$status" -ne 0 ]]
  grep -Fq 'must decode to one nonempty JSON object' "$test_dir/output"
  assert_cleaned
done
export REST_METHOD=delete
assert_failure 1
grep -Fq 'REST_METHOD must be post or put' "$test_dir/output"
export REST_METHOD=post REST_PAYLOAD_BASE64=''
assert_failure 1
grep -Fq 'REST_PAYLOAD_BASE64 is required' "$test_dir/output"
export REST_PAYLOAD_BASE64=e30= REST_URL='http://invalid'
assert_failure 1
grep -Fq 'must use HTTPS' "$test_dir/output"

printf 'All JSON REST submission tests passed.\n'
