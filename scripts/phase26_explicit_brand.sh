#!/usr/bin/env bash
set -euo pipefail

build_root="build/guards/phase26_explicit_brand"
mkdir -p "$build_root"
make build/gust-runtime-package.a
test -x ./gust
test -f build/gust-native-backend

python3 - <<'PY'
from pathlib import Path
source = Path("compiler/typechecker.gst").read_text(encoding="utf-8")
match_body = source.split("func types_match(", 1)[1].split("func env_types_match_at_brand_boundary(", 1)[0]
assert match_body.count("get_explicit_type_brand(") == 8
assert "get_type_brand(expected, empty[*TypeEnvironment[ctx]]" not in match_body
assert "get_type_brand(actual, empty[*TypeEnvironment[ctx]]" not in match_body
assert source.count("func get_type_brand(t: ast.Type[ctx], env: *TypeEnvironment[ctx], ctx: &Arena) str") == 1
PY

GUST_TEST_MIR_TO_C_UNAVAILABLE=1 \
GUST_NATIVE_BACKEND_DRIVER="$PWD/build/gust-native-backend" \
  ./gust --backend cranelift -o "$build_root/typechecker" \
    compiler/phase26_explicit_brand_test_entry.gst \
    >"$build_root/typechecker.compile.stdout" 2>"$build_root/typechecker.compile.stderr"
test ! -s "$build_root/typechecker.compile.stdout"
test ! -s "$build_root/typechecker.compile.stderr"
"$build_root/typechecker" >"$build_root/typechecker.stdout" 2>"$build_root/typechecker.stderr"
test ! -s "$build_root/typechecker.stderr"
printf 'SUCCESS: explicit-only type brands preserve nil-environment matching\n' >"$build_root/typechecker.expected"
cmp -s "$build_root/typechecker.expected" "$build_root/typechecker.stdout"

bash scripts/phase26_relational_zero_evidence.sh
echo 'Phase26 explicit-brand nil-environment prerequisite and native regression passed.'
