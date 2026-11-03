#!/usr/bin/env bash
set -euo pipefail

: "${REST_METHOD:?REST_METHOD is required}"
: "${REST_URL:?REST_URL is required}"
: "${REST_RESOURCE:?REST_RESOURCE is required}"
: "${REST_PAYLOAD_BASE64:?REST_PAYLOAD_BASE64 is required}"

case "$REST_METHOD" in
  post|put) ;;
  *) printf 'REST_METHOD must be post or put.\n' >&2; exit 1 ;;
esac
[[ "$REST_URL" == https://* && "$REST_RESOURCE" == https://* ]] || {
  printf 'REST_URL and REST_RESOURCE must use HTTPS.\n' >&2
  exit 1
}
for dependency in az jq base64 mktemp; do
  command -v "$dependency" >/dev/null || {
    printf 'Required command not found: %s\n' "$dependency" >&2
    exit 1
  }
done

umask 077
payload_file=$(mktemp)
trap 'rm -f -- "$payload_file"' EXIT
printf '%s' "$REST_PAYLOAD_BASE64" | base64 --decode > "$payload_file"
if ! jq -se 'length == 1 and (.[0] | type == "object" and length > 0)' "$payload_file" >/dev/null; then
  printf 'REST_PAYLOAD_BASE64 must decode to one nonempty JSON object.\n' >&2
  exit 1
fi

printf 'Submitting %s request to %s\n' "$REST_METHOD" "$REST_URL"
headers=('Content-Type=application/json')
if [[ "$REST_METHOD" == put ]]; then
  headers+=('Prefer=return=representation')
fi
if az rest --method "$REST_METHOD" --url "$REST_URL" --resource "$REST_RESOURCE" \
  --headers "${headers[@]}" --body "@$payload_file" --output none; then
  printf 'Request completed successfully.\n'
else
  status=$?
  printf 'REST request failed with exit code %s: %s\n' "$status" "$REST_URL" >&2
  exit "$status"
fi
