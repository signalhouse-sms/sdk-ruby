#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

SDK=ruby

# >>> version-files (S3; must match versionFiles("ruby") in ci/sdk-mirror/set-version.mjs)
VERSION_FILES=(
	lib/signalhouse_sms/version.rb
)
# <<< version-files

fail() { echo "::error::$SDK: $1" >&2; exit 1; }
check() { local name=$1; shift; "$@" || fail "$name"; }

T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

# Prints "<file> <field> <value>" per version field.
read_versions() {
	local f
	for f in "${VERSION_FILES[@]}"; do
		case $f in
			lib/signalhouse_sms/version.rb) sed -nE "s/^  VERSION = \"([^\"]+)\"$/$(sed 's#/#\\/#g' <<<"$f") VERSION \1/p" "$f" ;;
			*) fail "version-files: no reader for $f" ;;
		esac
	done
}

check_versions() {
	local lines want
	lines=$(read_versions) || return 1
	[ -n "$lines" ] || { echo "  VERSION not found" >&2; return 1; }
	want=${EXPECTED_VERSION:-$(head -1 <<<"$lines" | awk '{print $NF}')}
	echo "$lines" | awk -v want="$want" '$NF != want { print "  " $0 " != " want; bad=1 } END { exit bad }'
}

# Gemfile.lock pins the gem's own version, so a release-time bundle install rewrites it; restore it after.
bundle_install() {
	local rc=0
	cp Gemfile.lock "$T/Gemfile.lock.orig"
	BUNDLE_PATH="$T/bundle" BUNDLE_APP_CONFIG="$T/bundle-config" bundle install --quiet || rc=1
	cp "$T/Gemfile.lock.orig" Gemfile.lock
	return $rc
}

# ruby -wc must print only "Syntax OK".
check_syntax() {
	local f out
	while IFS= read -r f; do
		out=$(ruby -wc "$f" 2>&1) || { echo "$out" >&2; return 1; }
		[ "$out" = "Syntax OK" ] || { echo "  $f: $out" >&2; return 1; }
	done < <(find lib -name '*.rb' | sort)
}

check_tests() {
	local t
	for t in test/*_test.rb; do
		ruby -Ilib -Itest "$t" || { echo "  $t" >&2; return 1; }
	done
}

check_gem() {
	local v gem=$T/signalhouse-sms.gem bad
	v=$(read_versions | awk '{print $NF}')
	gem build signalhouse-sms.gemspec --output "$gem" >"$T/gem.log" 2>&1 || { cat "$T/gem.log" >&2; return 1; }
	[ "$(ruby -rrubygems/package -e 's = Gem::Package.new(ARGV[0]).spec; puts "#{s.name} #{s.version}"' "$gem")" = "signalhouse-sms $v" ] || { echo "  gem name/version" >&2; return 1; }
	tar -xOf "$gem" data.tar.gz | tar tzf - | sort >"$T/gem.list"
	bad=$(grep -vE '^(lib/.*|signalhouse-sms\.gemspec|Gemfile|README\.md)$' "$T/gem.list" || true)
	[ -z "$bad" ] || { echo "  unexpected gem entries:" >&2; echo "$bad" >&2; return 1; }
	grep -qx README.md "$T/gem.list" && grep -q '^lib/signalhouse_sms\.rb$' "$T/gem.list" || { echo "  gem missing lib/ or README.md" >&2; return 1; }
}

check_smoke() {
	ruby -Ilib -e 'require "signalhouse_sms"; SignalHouseSms::Client.new(api_key: "x", base_url: "http://127.0.0.1:9")'
}

echo "== $SDK: versions"; check versions check_versions
echo "== $SDK: bundle install"; check "bundle install" bundle_install
echo "== $SDK: ruby -wc"; check "ruby -wc" check_syntax
echo "== $SDK: tests"; check tests check_tests
echo "== $SDK: gem"; check gem check_gem
echo "== $SDK: smoke"; check smoke check_smoke
echo "gate passed: $SDK"
