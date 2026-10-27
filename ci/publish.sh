#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

SDK=ruby
fail() { echo "::error::$SDK: $1" >&2; exit 1; }
run() { if [ "${PUBLISH_DRY_RUN:-}" = 1 ]; then printf '+ (dry run) would run:'; printf ' %q' "$@"; echo; else "$@"; fi; }

# Exit 0 = published, 1 = absent; anything else fails.
published() {
	local code
	code=$(curl -sS -o /dev/null -w '%{http_code}' --retry 3 "https://rubygems.org/api/v2/rubygems/$1/versions/$2.json") || fail "registry check $1 $2"
	case $code in
		200) return 0 ;;
		404) return 1 ;;
		*) fail "registry check $1 $2: HTTP $code" ;;
	esac
}

V=$(sed -nE 's/^  VERSION = "([^"]+)"$/\1/p' lib/signalhouse_sms/version.rb)
[ -n "$V" ] || fail "read VERSION"
if published signalhouse-sms "$V"; then echo "signalhouse-sms $V exists, skipping"; exit 0; fi

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT
run gem build signalhouse-sms.gemspec --output "$T/signalhouse-sms-$V.gem" || fail "gem build"
run gem push "$T/signalhouse-sms-$V.gem" || fail "gem push"
