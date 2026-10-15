#!/bin/sh
# Prove tall rejects a real Unicode regression, leaving the checkout untouched.
set -eu

xmlan_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
probe_dir=$(mktemp -d)
trap 'rm -rf "$probe_dir"' EXIT HUP INT TERM
rebar_command=${REBAR3:-rebar3}

cp -R "$xmlan_root/src" "$xmlan_root/test" "$probe_dir/"
cp "$xmlan_root/rebar.config" "$xmlan_root/elvis.config" "$probe_dir/"
mkdir -p "$probe_dir/global-config"
sed 's/unicode:characters_to_binary(Text)/list_to_binary(Text)/' \
    "$xmlan_root/src/xmlan.erl" > "$probe_dir/src/xmlan.erl"

if (cd "$probe_dir" && REBAR_GLOBAL_CONFIG_DIR="$probe_dir/global-config" \
    "$rebar_command" tall) > "$probe_dir/output.log" 2>&1; then
    cat "$probe_dir/output.log"
    echo "ERROR: tall accepted the Unicode regression" >&2
    exit 1
fi

if ! grep -q 'Unicode character list' "$probe_dir/output.log" || \
    ! grep -q 'Error running tests' "$probe_dir/output.log"; then
    cat "$probe_dir/output.log"
    echo "ERROR: the probe failed before exercising the Unicode contract" >&2
    exit 1
fi

echo "PASS: tall rejected the Unicode regression through its real tests"
