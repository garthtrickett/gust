#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
build_dir="build/guards/phase16_abi_metadata"
fixture="compiler/fixtures/native_backend_abi_metadata_valid.request"
manifest="tests/cranelift/phase16_abi_metadata_malformed.tsv"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
mkdir -p "$build_dir"
cargo build --manifest-path compiler/experiments/cranelift/Cargo.toml >"$build_dir/cargo-build.log" 2>&1
"$worker" phase16-abi-metadata-witness "$fixture" >"$build_dir/valid.witness"
cmp -s "$fixture" "$build_dir/valid.witness"
poison="$build_dir/poison-driver.sh"
poison_marker="$build_dir/poisoned-driver-was-invoked"
printf '#!/usr/bin/env bash\nprintf invoked >"%s"\nexit 99\n' "$poison_marker" >"$poison"
chmod +x "$poison"
while IFS=$'\t' read -r label reason old new; do
  [ "$label" != "fixture" ] || continue
  mutated="$build_dir/$label.request"; output="$build_dir/$label.output"; temporary="$build_dir/$label.tmp"
  cp "$fixture" "$mutated"
  OLD="$old" NEW="$new" python3 - "$mutated" <<'PY'
import os,sys
from pathlib import Path
path=Path(sys.argv[1]);source=path.read_text();old=os.environ["OLD"];new=os.environ["NEW"]
if source.count(old)!=1: raise SystemExit(f"mutation source count for {old!r}: {source.count(old)}")
path.write_text(source.replace(old,new,1))
PY
  printf 'sentinel: preserve-existing-output\n' >"$output"
  if GUST_NATIVE_DRIVER="$poison" "$worker" phase16-abi-metadata-witness "$mutated" >"$temporary" 2>"$build_dir/$label.stderr"; then
    echo "malformed ABI metadata unexpectedly succeeded: $label" >&2; exit 1
  fi
  rg -n -F "reason=$reason" "$build_dir/$label.stderr" >/dev/null
  rg -n -F 'sentinel: preserve-existing-output' "$output" >/dev/null
  [ ! -e "$poison_marker" ]
done <"$manifest"
echo "guard-cranelift-phase16-abi-metadata-contract: malformed request validation ok"
