#!/usr/bin/env bash
set -euo pipefail

guard="guard-cranelift-phase22-default-native-package-evidence"
build_dir="build/guards/cranelift_phase22_default_native_package"
package_bin="build/phase10-package/bin"
scalar_fixture="compiler/phase10_scalar_return_source.gst"
runtime_fixture="compiler/phase20_component_allocation_source.gst"

fail() {
  echo "$guard: $1" >&2
  exit 1
}

for required in gust gust-native-backend gust-runtime-package.a; do
  test -e "$package_bin/$required" || fail "package is missing $required"
done

rm -rf "$build_dir"
mkdir -p "$build_dir"
install_root="$(mktemp -d "$PWD/build/phase22-default-native-install.XXXXXX")"
trap 'rm -rf "$install_root"' EXIT

check_modes() {
  local bin_dir="$1"
  test "$(stat -c '%a' "$bin_dir/gust")" = "755" || fail "gust mode drifted"
  test "$(stat -c '%a' "$bin_dir/gust-native-backend")" = "755" || fail "worker mode drifted"
  test "$(stat -c '%a' "$bin_dir/gust-runtime-package.a")" = "644" || fail "runtime package mode drifted"
}

assert_clean_failure() {
  local output="$1"
  local expected="$2"
  cmp -s "$expected" "$output" || fail "failure changed existing output: $output"
  test ! -e "$output.phase10.bundle" || fail "failure left a canonical-MIR bundle"
  test ! -e "$output.phase10.request" || fail "failure left a backend request"
  if find "$(dirname "$output")" -maxdepth 1 -type f \
    \( -name ".$(basename "$output").phase9g-*" -o -name ".$(basename "$output").phase10-*" \) \
    | grep -q .; then
    fail "failure left an owned hidden artifact for $output"
  fi
}

run_status() {
  local executable="$1"
  local prefix="$2"
  set +e
  "$executable" >"$prefix.stdout" 2>"$prefix.stderr"
  local status="$?"
  set -e
  printf '%s\n' "$status"
}

check_modes "$package_bin"

# The repository package is already a relocatable sibling set. Use implicit
# native output without the ambient worker override introduced for development.
repo_case="$build_dir/repository-scalar.gst"
cp "$scalar_fixture" "$repo_case"
env -u GUST_NATIVE_BACKEND_DRIVER \
  "$package_bin/gust" --backend cranelift "$repo_case" \
  >"$build_dir/repository.stdout" 2>"$build_dir/repository.stderr"
test -x "$build_dir/repository-scalar" || fail "repository package produced no inferred executable"
test ! -s "$build_dir/repository.stdout" || fail "repository native compilation emitted stdout"
test ! -s "$build_dir/repository.stderr" || fail "repository native compilation emitted stderr"
test "$(run_status "$build_dir/repository-scalar" "$build_dir/repository-run")" = "7" ||
  fail "repository package scalar behavior drifted"

# Install into an otherwise empty prefix and require the exact three-artifact
# set with the same modes.
make install DESTDIR="$install_root" PREFIX=/opt/gust \
  >"$build_dir/install.stdout" 2>"$build_dir/install.stderr"
installed_bin="$install_root/opt/gust/bin"
check_modes "$installed_bin"
installed_inventory="$(find "$installed_bin" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | sort)"
test "$installed_inventory" = $'gust\ngust-native-backend\ngust-runtime-package.a' ||
  fail "installed package is not the exact three-artifact set: $installed_inventory"

installed_case="$build_dir/installed-runtime.gst"
cp "$runtime_fixture" "$installed_case"
env -u GUST_NATIVE_BACKEND_DRIVER \
  "$installed_bin/gust" --backend cranelift "$installed_case" \
  >"$build_dir/installed.stdout" 2>"$build_dir/installed.stderr"
test -x "$build_dir/installed-runtime" || fail "installed package produced no inferred executable"
test ! -s "$build_dir/installed.stdout" || fail "installed native compilation emitted stdout"
test ! -s "$build_dir/installed.stderr" || fail "installed native compilation emitted stderr"
test "$(run_status "$build_dir/installed-runtime" "$build_dir/installed-run")" = "0" ||
  fail "installed runtime-boundary behavior drifted"

# Explicit C remains the oracle and does not need worker discovery.
"$installed_bin/gust" --backend c "$installed_case" \
  >"$build_dir/installed.c" 2>"$build_dir/installed-c.stderr"
test ! -s "$build_dir/installed-c.stderr" || fail "installed explicit C emitted diagnostics"
cat src/runtime.c "$build_dir/installed.c" >"$build_dir/installed-final.c"
"${CC:-cc}" ${CFLAGS:--O2 -Wall -pthread} ${INCLUDES:--Isrc} \
  "$build_dir/installed-final.c" -o "$build_dir/installed-oracle"
test "$(run_status "$build_dir/installed-oracle" "$build_dir/oracle-run")" = "0" ||
  fail "installed explicit-C oracle behavior drifted"
cmp -s "$build_dir/installed-run.stdout" "$build_dir/oracle-run.stdout" ||
  fail "installed native stdout differs from explicit C"
cmp -s "$build_dir/installed-run.stderr" "$build_dir/oracle-run.stderr" ||
  fail "installed native stderr differs from explicit C"

# Relocate only the installed sibling directory. Discovery and runtime-package
# selection must remain executable-relative, not tied to the staging prefix.
relocated_bin="$build_dir/relocated/bin"
mkdir -p "$(dirname "$relocated_bin")"
cp -a "$installed_bin" "$relocated_bin"
check_modes "$relocated_bin"
relocated_case="$build_dir/relocated-runtime.gst"
cp "$runtime_fixture" "$relocated_case"
env -u GUST_NATIVE_BACKEND_DRIVER \
  "$relocated_bin/gust" --backend cranelift "$relocated_case" \
  >"$build_dir/relocated.stdout" 2>"$build_dir/relocated.stderr"
test -x "$build_dir/relocated-runtime" || fail "relocated package produced no executable"
test "$(run_status "$build_dir/relocated-runtime" "$build_dir/relocated-run")" = "0" ||
  fail "relocated package behavior drifted"

# With the worker and archive absent, explicit C is still byte-identical even
# when the complete package is on PATH. Native discovery must not search PATH.
missing_bin="$build_dir/missing-worker-package/bin"
mkdir -p "$missing_bin"
cp "$installed_bin/gust" "$missing_bin/gust"
"$missing_bin/gust" --backend c "$installed_case" \
  >"$build_dir/missing-worker.c" 2>"$build_dir/missing-worker-c.stderr"
cmp -s "$build_dir/installed.c" "$build_dir/missing-worker.c" ||
  fail "explicit C depends on installed native components"

missing_case="$build_dir/missing-worker.gst"
cp "$scalar_fixture" "$missing_case"
printf '%s\n' 'phase22-missing-worker-output-sentinel' >"$build_dir/missing-worker"
cp "$build_dir/missing-worker" "$build_dir/missing-worker.expected"
set +e
env -u GUST_NATIVE_BACKEND_DRIVER PATH="$installed_bin:$PATH" \
  "$missing_bin/gust" --backend cranelift "$missing_case" \
  >"$build_dir/missing-worker.stdout" 2>"$build_dir/missing-worker.stderr"
missing_status="$?"
set -e
test "$missing_status" -ne 0 || fail "missing sibling worker unexpectedly succeeded through PATH"
cat "$build_dir/missing-worker.stdout" "$build_dir/missing-worker.stderr" \
  >"$build_dir/missing-worker.diagnostic"
rg -F 'Native backend driver discovery error: sibling native backend driver path is unavailable or not executable' \
  "$build_dir/missing-worker.diagnostic" >/dev/null || fail "missing-worker diagnostic drifted"
assert_clean_failure "$build_dir/missing-worker" "$build_dir/missing-worker.expected"

# A compatible worker with a missing runtime archive reaches the worker but
# fails deterministically without replacing the final path or leaving requests.
missing_runtime_bin="$build_dir/missing-runtime-package/bin"
mkdir -p "$missing_runtime_bin"
cp "$installed_bin/gust" "$missing_runtime_bin/gust"
cp "$installed_bin/gust-native-backend" "$missing_runtime_bin/gust-native-backend"
missing_runtime_case="$build_dir/missing-runtime.gst"
cp "$runtime_fixture" "$missing_runtime_case"
printf '%s\n' 'phase22-missing-runtime-output-sentinel' >"$build_dir/missing-runtime"
cp "$build_dir/missing-runtime" "$build_dir/missing-runtime.expected"
set +e
env -u GUST_NATIVE_BACKEND_DRIVER \
  "$missing_runtime_bin/gust" --backend cranelift "$missing_runtime_case" \
  >"$build_dir/missing-runtime.stdout" 2>"$build_dir/missing-runtime.stderr"
missing_runtime_status="$?"
set -e
test "$missing_runtime_status" -ne 0 || fail "missing runtime archive unexpectedly succeeded"
cat "$build_dir/missing-runtime.stdout" "$build_dir/missing-runtime.stderr" \
  >"$build_dir/missing-runtime.diagnostic"
rg -F 'gust-runtime-package.a' "$build_dir/missing-runtime.diagnostic" >/dev/null ||
  fail "missing-runtime diagnostic does not name the required component"
assert_clean_failure "$build_dir/missing-runtime" "$build_dir/missing-runtime.expected"

# An incompatible sibling is rejected by the frozen handshake before request
# or output access. It cannot be replaced by a PATH worker.
incompatible_bin="$build_dir/incompatible-worker-package/bin"
mkdir -p "$incompatible_bin"
cp "$installed_bin/gust" "$incompatible_bin/gust"
cp "$installed_bin/gust-runtime-package.a" "$incompatible_bin/gust-runtime-package.a"
"$installed_bin/gust-native-backend" phase10-driver-handshake \
  | sed 's/^protocol: .*/protocol: gust.native_backend.driver.incompatible/' \
  >"$incompatible_bin/incompatible.handshake"
cat >"$incompatible_bin/gust-native-backend" <<'EOF_INCOMPATIBLE_WORKER'
#!/usr/bin/env bash
set -euo pipefail
self_dir="$(cd "$(dirname "$0")" && pwd)"
if [ "${1:-}" = "phase10-driver-handshake" ]; then
  cat "$self_dir/incompatible.handshake"
  exit 0
fi
exit 74
EOF_INCOMPATIBLE_WORKER
chmod +x "$incompatible_bin/gust-native-backend"
incompatible_case="$build_dir/incompatible-worker.gst"
cp "$scalar_fixture" "$incompatible_case"
printf '%s\n' 'phase22-incompatible-worker-output-sentinel' >"$build_dir/incompatible-worker"
cp "$build_dir/incompatible-worker" "$build_dir/incompatible-worker.expected"
set +e
env -u GUST_NATIVE_BACKEND_DRIVER PATH="$installed_bin:$PATH" \
  "$incompatible_bin/gust" --backend cranelift "$incompatible_case" \
  >"$build_dir/incompatible-worker.stdout" 2>"$build_dir/incompatible-worker.stderr"
incompatible_status="$?"
set -e
test "$incompatible_status" -ne 0 || fail "incompatible sibling worker unexpectedly succeeded"
cat "$build_dir/incompatible-worker.stdout" "$build_dir/incompatible-worker.stderr" \
  >"$build_dir/incompatible-worker.diagnostic"
rg -F 'Native backend driver handshake [protocol_mismatch]: native backend driver protocol mismatch' \
  "$build_dir/incompatible-worker.diagnostic" >/dev/null || fail "incompatible-worker diagnostic drifted"
assert_clean_failure "$build_dir/incompatible-worker" "$build_dir/incompatible-worker.expected"

echo "$guard: ok"
