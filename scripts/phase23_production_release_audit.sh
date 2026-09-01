#!/usr/bin/env bash
set -euo pipefail

guard="guard-cranelift-phase23-production-release-audit-evidence"

# The predecessor owns the clean temporary DESTDIR, relocation, package-mode,
# missing-worker, missing-runtime, cleanup, and explicit-native checks. Reuse it
# instead of creating a second package contract.
bash scripts/phase22_default_native_package.sh

# The supported single-program entry is now native. Poisoning MIR-to-C while it
# builds and executes proves the helper does not use or fall back to C.
GUST_RUNNER_SKIP_BUILD=1 bash scripts/run-gust-file.sh \
  compiler/phase20_component_allocation_source.gst >/dev/null
rg -F 'COMPILING GUST WITH CRANELIFT' to.log >/dev/null || {
  echo "$guard: supported runner did not use its native route" >&2
  exit 1
}

evidence_root="$(mktemp -d)"
trap 'rm -rf "$evidence_root"' EXIT
native_compiler="$PWD/build/phase10-package/bin/gust"
native_output="$evidence_root/no-fallback-native"
GUST_TEST_MIR_TO_C_UNAVAILABLE=1 "$native_compiler" -o "$native_output" \
  compiler/phase10_scalar_return_source.gst >/dev/null 2>"$evidence_root/native.stderr" || {
  echo "$guard: default native compilation failed while MIR-to-C was poisoned" >&2
  exit 1
}
test -x "$native_output" || {
  echo "$guard: no-fallback probe produced no native artifact" >&2
  exit 1
}

echo "phase23_production_release_audit: evidence ok"
