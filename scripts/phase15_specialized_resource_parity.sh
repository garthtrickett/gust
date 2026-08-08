#!/usr/bin/env bash
set -euo pipefail
echo "🧪 Running Phase 15.11 specialized resource parity..."
python3 scripts/cranelift_test_levels.py validate
python3 scripts/cranelift_test_levels.py level guard-cranelift-phase15-specialized-resource-parity | grep -F $'guard-cranelift-phase15-specialized-resource-parity\t2\t' >/dev/null
python3 scripts/phase15_specialized_resource.py --check >/dev/null

request="/tmp/gust-phase15-specialized-resource.request"
mir_to_c="/tmp/gust-phase15-specialized-resource.mir-to-c.witness"
build_dir="build/guards/phase15_specialized_resource"
worker_manifest="compiler/experiments/cranelift/Cargo.toml"
worker="compiler/experiments/cranelift/target/debug/gust-cranelift-experiment"
rm -rf "$build_dir"
rm -f "$request" "$mir_to_c"
mkdir -p "$build_dir"

XDG_RUNTIME_DIR=/tmp TMPDIR=/tmp bash scripts/run-gust-file.sh compiler/future/p15_directory_resources_source.gst
grep -F 'SUCCESS: Phase 15.11 directory source fixture passed' to.log >/dev/null
XDG_RUNTIME_DIR=/tmp TMPDIR=/tmp bash scripts/run-gust-file.sh compiler/mir_specialized_resource_state_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.11 specialized resource state policy passed' to.log >/dev/null
XDG_RUNTIME_DIR=/tmp TMPDIR=/tmp bash scripts/run-gust-file.sh compiler/mir_specialized_resource_parity_smoke_test_entry.gst
grep -F 'SUCCESS: Phase 15.11 specialized resource parity smoke passed' to.log >/dev/null
test -s "$request"
test -s "$mir_to_c"

cargo build --quiet --manifest-path "$worker_manifest"
"$worker" phase15-specialized-resource-witness "$request" >"$build_dir/cranelift.witness"
diff -u "$mir_to_c" "$build_dir/cranelift.witness"

for token in \
  'specialized_resource_policy: authority=compiler selected_kinds=os_Dir_ctx generic_state_machine=1 backend_local_state_machine=0 non_resource_views=os_DirEntry_ctx' \
  'specialized_resource_kind: kind=directory resource_type=os_Dir_ctx constructor=os.OpenDir destructor=os.CloseDir close=os.CloseDir copy=prohibited move=immovable_while_open cleanup=manual_or_scope_exit_exactly_once runtime_constructor=os_OpenDir runtime_close=os_CloseDir targets=all_declared_host_targets_from_phase14_target_authority layout=layout:os_dir' \
  'specialized_resource: resource=resource:specialized:directory kind=directory state=manually_closed operation=open_read_close entries_observed=1 close_count=1 destructor_count=0 filesystem_effect=directory_entry_observed' \
  'specialized_resource_witness: selected_kind_count=1 resource_count=1 close_count=1 destructor_count=0 filesystem_effects_compared=1 generic_authority=1'
do
  grep -F "$token" "$build_dir/cranelift.witness" >/dev/null
done

echo "guard-cranelift-phase15-specialized-resource-parity: ok (Level 2)"
