CC = cc
CFLAGS = -O2 -Wall -pthread
INCLUDES = -Isrc
PREFIX = /usr/local
DESTDIR ?=
CARGO ?= cargo

# The supported default distribution is the executable-relative Cranelift
# package. Bootstrap and oracle targets below continue to select MIR-to-C
# explicitly.
.DEFAULT_GOAL := phase10-native-package

PHASE10_NATIVE_BACKEND_MANIFEST = compiler/experiments/cranelift/Cargo.toml
PHASE10_NATIVE_BACKEND_LOCK = compiler/experiments/cranelift/Cargo.lock
PHASE10_NATIVE_BACKEND_SOURCES = $(wildcard compiler/experiments/cranelift/src/*.rs)
PHASE10_NATIVE_BACKEND_TARGET_DIR = build/phase10-native-backend-cargo
PHASE10_NATIVE_BACKEND_BUILT_BIN = $(PHASE10_NATIVE_BACKEND_TARGET_DIR)/release/gust-cranelift-experiment
PHASE21_RUNTIME_PACKAGE = build/gust-runtime-package.a
# Patch 25.6: defined HERE, above first use. Make expands prerequisite
# lists immediately, so a definition further down is empty at that
# point -- silently, since an undefined variable expands to nothing.
# Measured with --warn-undefined-variables after a "fix" that was a
# no-op: the link lines were edited and the link was unchanged.
PHASE25_RUNTIME_RS = src/runtime-rs/target/release/libgust_runtime_rs.a
PHASE25_RUNTIME_RS_OBJ = build/phase25-runtime-rs/gust_runtime_rs_exports.o
PHASE25_RUNTIME_RS_CANARY = src/runtime-rs/target/canary/release/libgust_runtime_rs.a
PHASE25_RUNTIME_RS_CANARY_OBJ = build/phase25-runtime-rs-canary/gust_runtime_rs_exports.o

# Patch 25.10a: EMPTY, and that is the point. This held
# build/phase21-runtime/strings.o -- "the last C member", as four
# separate guards said in a comment. With the nine pure string
# functions in src/runtime-rs the runtime archive has no C in it at
# all, so $(CC) is off the critical path of every natively compiled
# program. Kept as a variable rather than deleted: the archive rule
# still reads it, and an empty list is the assertion that there is
# nothing left to add back without someone noticing.
PHASE21_RUNTIME_OBJECTS =

PHASE10_DIAG_CC ?= clang
PHASE10_DIAG_CFLAGS ?= -O0 -g3 -fno-omit-frame-pointer -fno-optimize-sibling-calls -fsanitize=address,undefined -fsanitize-address-use-after-scope -fno-sanitize-recover=all -pthread
PYTHON ?= python3

# Force make to use bash with pipefail to prevent silent pipeline errors
SHELL = bash
.SHELLFLAGS = -o pipefail -c

# Keep Make's explicit phony surface small. The Makefile remains the canonical
# build graph for core aggregate commands; focused guard/report discovery lives
# in justfile and concrete recipe names below rather than in a giant .PHONY list.
.PHONY: all clean test bootstrap install test_tree_sitter require_just phase10-native-package

require_just:
	@command -v just >/dev/null 2>&1 || { echo "❌ just is required for focused Make guards. Run nix develop or install just."; exit 1; }

# Track all compiler and runtime source files to ensure correct incremental builds
COMPILER_SRCS = $(wildcard compiler/*.gst)
RUNTIME_SRCS  = src/runtime.c $(wildcard src/runtime/*.c) $(wildcard src/runtime/*.h)

all: phase10-native-package

gust_bootstrap: $(RUNTIME_SRCS) $(PHASE25_RUNTIME_RS_OBJ) docs/RELEASE_MANIFEST.json
	mkdir -p build
	@# Patch 25.9: there is no committed seed any more. gust_v4.c is gone
	@# -- 66,002 lines, 81% of the tree's C, deleted rather than
	@# translated -- so the bootstrap obtains a published bridge compiler
	@# instead of compiling one from a checked-in blob.
	@#
	@# Two routes, and the offline one wins when it is set. 25.8a wired
	@# GUST_BOOTSTRAP_SEED: it names a local bridge binary, verified
	@# against the committed manifest BEFORE use. Unset, fetch-seed pulls
	@# the newest release's bridge for this host and verifies its digest
	@# before installing it -- before, not after, because a
	@# verified-then-replaced artifact is the same hole as an unverified
	@# one.
	@#
	@# The offline path is not a fallback, it is the audit path. A chain
	@# that can ONLY be fetched is not auditable by anyone who does not
	@# already trust the host, which is why that variable exists.
	@if [ -n "$$GUST_BOOTSTRAP_SEED" ]; then \
		echo "offline seed: $$GUST_BOOTSTRAP_SEED"; \
		python3 scripts/phase25_release_manifest.py verify-seed; \
		install -m 0755 "$$GUST_BOOTSTRAP_SEED" gust_bootstrap; \
	else \
		python3 scripts/phase25_release_manifest.py fetch-seed; \
	fi

# Patch 25.10: FOUR RULES DELETED HERE, not left pointing at a missing
# emitter. They were the C stage chain:
#
#   build/gust_stage1_compiler.c   emitted by gust_bootstrap
#   build/gust_stage1_bin          $(CC) of the above
#   diagnose-phase10-stage1        a sanitizer build of the same C
#   build/gust_compiler.c          emitted by the stage-one binary
#
# `gust` no longer depends on any of them -- it is one native compile now
# -- so they are unreachable. A Make rule whose recipe cannot run fails
# only when something asks for it, which is the worst time to find out,
# and the Makefile already states that policy a few rules below: "The
# rules are deleted rather than left pointing at missing sources."
#
# diagnose-phase10-stage1 goes with them and is NOT replaced. It existed
# to debug a SIGSEGV in a stage-one binary built from emitted C; there is
# no stage one. The native route's own diagnostics are the
# gust_native_capability_decision and gust_backend_parity_diagnostic
# lines, which it prints without needing a separate target.


## just "make" doesnt do anything need to run "make gust"
#
# Patch 25.10: ONE STEP, AND NO C. This was
#
#   gust_bootstrap --backend bootstrap-emitter <bridge entry>  -> stage1 C
#   $(CC) stage1 C                                             -> stage1 bin
#   stage1 bin --backend bootstrap-emitter <entry>             -> compiler C
#   cat src/runtime.c compiler C | $(CC)                       -> gust
#
# two emitter invocations and two host-compiler invocations to build the
# compiler. With the emitter deleted there is no stage one, so `make gust`
# either flips onto the native route or stops existing.
#
# MEASURED BEFORE COMMITTING TO IT, because "the native route can build the
# compiler" is exactly the kind of claim that should not be assumed: the
# fetched bridge compiled compiler/test_runner_entry.gst straight through
# to a 9.8MB executable that answers --help, with no emitter and no $(CC)
# anywhere in the path. Patch 25.7's fixed point already did this twice --
# its stage1 and stage2 ARE this command -- so the capability was proven
# before this patch used it.
#
# The driver is a prerequisite and NOT circular: build/gust-native-backend
# comes from a cargo manifest and does not depend on gust. Only
# phase10-native-package depends on gust, and only to package it.
gust: gust_bootstrap $(COMPILER_SRCS) build/gust-native-backend $(PHASE21_RUNTIME_PACKAGE)
	@rm -rf build/native-build/bin
	mkdir -p build/native-build/bin
	install -m 0755 gust_bootstrap build/native-build/bin/gust
	install -m 0755 build/gust-native-backend build/native-build/bin/gust-native-backend
	install -m 0644 $(PHASE21_RUNTIME_PACKAGE) build/native-build/bin/gust-runtime-package.a
	./build/native-build/bin/gust --backend cranelift -o build/.gust.tmp compiler/test_runner_entry.gst
	@test -x build/.gust.tmp || { echo "❌ the native route produced no executable"; exit 1; }
	mv build/.gust.tmp gust
	@# Patch 25.10: the root compiler binary is now NATIVE-ONLY and resolves
	@# its backend driver as a SIBLING. Before this patch it carried the
	@# emitter and worked standalone, so every recipe that invokes it on a
	@# source file inherited that and now fails driver discovery at the repo
	@# root:
	@#
	@#   Native backend driver discovery error: sibling native backend
	@#   driver path is unavailable or not executable
	@#
	@# That took down step51-policy and six step52-* heavy-shard guards on
	@# PR #470. Installing the other two artifacts beside it makes the repo
	@# root the same three-artifact sibling unit Patch 22's delivery
	@# contract names, rather than a loose binary outside it.
	install -m 0755 build/gust-native-backend gust-native-backend
	install -m 0644 $(PHASE21_RUNTIME_PACKAGE) gust-runtime-package.a

build/gust-native-backend: $(PHASE10_NATIVE_BACKEND_MANIFEST) $(PHASE10_NATIVE_BACKEND_LOCK) $(PHASE10_NATIVE_BACKEND_SOURCES)
	mkdir -p build
	CARGO_TARGET_DIR="$(PHASE10_NATIVE_BACKEND_TARGET_DIR)" \
		$(CARGO) build \
		--locked \
		--release \
		--manifest-path "$(PHASE10_NATIVE_BACKEND_MANIFEST)"
	@test -x "$(PHASE10_NATIVE_BACKEND_BUILT_BIN)" || { \
		echo "❌ Missing release native backend worker: $(PHASE10_NATIVE_BACKEND_BUILT_BIN)"; \
		exit 1; \
	}
	@rm -f build/.gust-native-backend.tmp
	install -m 0755 "$(PHASE10_NATIVE_BACKEND_BUILT_BIN)" build/.gust-native-backend.tmp
	mv build/.gust-native-backend.tmp build/gust-native-backend

# Patch 25.6: fiber.c is gone. Its eighteen exports -- the scheduler, the
# context switch, and the Mutex/Channel primitives -- are defined in
# src/runtime-rs and reach the archive through the crate member. The .o
# rule is removed rather than left dangling: a rule whose source does not
# exist fails only when something asks for it.

# Patch 25.5: arena.o, host_io.o, file_io.o, scratch.o and collections.o
# are gone with their sources. Their symbols did not go anywhere -- they
# are defined in src/runtime-rs and reach this archive through the crate
# member, exactly as fiber's eighteen did in 25.6. A member left; no
# symbol did. The rules are deleted rather than left pointing at missing
# sources, because such a rule fails only when something asks for it.

# Patch 25.4: approved_scalar_imports.c is rehomed to the Rust
# crate src/runtime-rs. The fixtures must stay FOREIGN -- a Gust rewrite
# would test Gust calling Gust and the contract would evaporate (O1).
# Symbol names are byte-identical, so the 26 dependent files are unchanged.

# Patch 25.5: the prerequisite list is a WILDCARD, and it has to be.
#
# It used to name src/runtime-rs/src/lib.rs and Cargo.toml. That was true
# when the crate was lib.rs, and quietly stopped being true at the first
# `pub mod`: the crate is now seven files, and editing fiber.rs, arena.rs,
# collections.rs or file_io.rs did not make make rebuild the archive. The
# build then linked YESTERDAY'S runtime and passed -- the worst shape a
# build bug takes, because nothing fails and the green means nothing.
#
# scripts/phase25_runtime_rs_abi_smoke.sh had the identical bug in the
# identical place: it skipped the cargo build when an archive already
# existed, so the harness reported on code it had not compiled. Both were
# written while being careful about everything else in the same file.
#
# cargo does its own change detection, so running it unconditionally would
# also be correct; the wildcard keeps make's own graph honest, which is
# what the incremental-build comment at the top of this file promises.
PHASE25_RUNTIME_RS_SRCS = $(wildcard src/runtime-rs/src/*.rs) src/runtime-rs/Cargo.toml

$(PHASE25_RUNTIME_RS): $(PHASE25_RUNTIME_RS_SRCS)
	$(CARGO) build --release --manifest-path src/runtime-rs/Cargo.toml

# One object joins the runtime archive, not the crate's 310 members.
#
# Patch 25.4 got that object by extracting the single archive member that
# defined the fixtures, which worked while the crate was no_std and the
# fixtures called nothing. Patch 25.6 moved the scheduler in and Patch
# 25.5 moved five more runtime files: the extracted member now carries
# undefined references into core, alloc and std, which live in the 309
# members the extraction discards. It builds and then fails at link.
#
# So the object is produced by a partial link instead. The exports below
# are the roots, --gc-sections drops what they do not reach, and the
# result is self-contained apart from libc. Its exports are then narrowed
# to exactly that list, which also localises the memcpy that
# compiler_builtins brings along, so it can no longer collide with libc's.
#
# The list is NAMED rather than "whatever ended up global". Three parity
# guards compare the archive's defined-symbol set exactly, and the crate's
# codegen unit also defines Rust's panic handler, whose symbol carries a
# content hash that moves on every crate change -- deriving the list from
# the object would make those guards churn forever and assert nothing.
#
# The roots are checked after the link, not assumed. ld does not fail on a
# -u it cannot satisfy, so a renamed export would otherwise leave a quietly
# smaller object and surface much later as an undefined symbol.
PHASE25_RUNTIME_RS_EXPORTS = \
	get_num_threads_to_use \
	gust_check_fail \
	gust_context_switch \
	gust_fiber_create \
	gust_fiber_entry_wrapper \
	gust_fiber_exit \
	gust_fiber_free \
	gust_fiber_switch \
	gust_scheduler_destroy \
	gust_scheduler_init \
	gust_scheduler_spawn \
	gust_shard_loop \
	gust_tick \
	gust_yield \
	os_ArenaAlloc \
	os_Arena_Free \
	os_Arena_New \
	os_Arena_Validate \
	os_Args \
	os_CloseDir \
	os_ExecutablePath \
	os_FileExecutable \
	os_FileExists \
	os_GetEnv \
	os_GetThreadScratch_raw \
	os_HashMapClear_impl \
	os_HashMapContains_impl \
	os_HashMapRef_impl \
	os_HashMapRemove_impl \
	os_LogError \
	os_LogInt \
	os_LogStr \
	os_MockPayload \
	os_NativeObjectFormat \
	os_NativeTargetTriple \
	os_OpenDir \
	os_PathAbsolute \
	os_PathDir \
	os_ReadDir \
	os_ReadFile \
	os_RemoveFile \
	os_RunProcess \
	os_ScratchAlloc \
	os_ScratchReset \
	os_SetThreadScratch \
	os_System \
	os_WriteFile \
	os_argc \
	os_argv \
	os_path_join \
	std_Channel_Alloc \
	std_Channel_Recv_impl \
	std_Channel_Send_impl \
	std_Clone_str \
	std_GenerationalSwap \
	std_Mutex_Alloc \
	std_Mutex_Lock_impl \
	std_Mutex_Unlock_impl \
	std_PoolAlloc_impl \
	std_PoolFree_impl \
	std_is_alpha \
	std_is_digit \
	std_is_whitespace \
	std_parse_int \
	std_str_bounds_fail \
	std_str_byte_at \
	std_str_eq \
	std_str_find \
	std_str_slice \
	std_str_split \
	std_str_trim \
	tiny_host_add_i32 \
	tiny_host_add_one_i32 \
	tiny_host_is_positive_i32

# Both archives are narrowed the same way, so the recipe is written once.
# $(1) staticlib, $(2) output object, $(3) scratch directory.
# The partial link is PLATFORM-SPECIFIC, and Patch 25.6 commits this
# tree to four quadrants: macOS-x86_64, Linux-x86_64, macOS-aarch64,
# Linux-aarch64. fiber_asm.rs preserves all four; a GNU-only build rule
# would keep the assembly portable and make the build that consumes it
# Linux-only.
#
# ELF (GNU ld + objcopy): --gc-sections drops what the roots do not
# reach, --start-group resolves the archive's internal cycles, and
# objcopy localises everything outside the export list.
#
# Mach-O (ld64): none of those options exist. Dead-stripping is
# -dead_strip, archives need no group because ld64 iterates to a fixed
# point, and there is no objcopy -- ld64 narrows with -exported_symbol
# and localises the rest in the same pass. Mach-O symbols carry a
# leading underscore, so the export list is prefixed and the drift check
# strips it back off.
#
# Selected with `ifeq` at parse time rather than a shell test inside the
# recipe, because the two arms are different COMMANDS, not different
# arguments -- one is two steps and one is one.
#
# THE DARWIN ARM IS UNVERIFIED ON THIS HOST. It is written from ld64's
# documented options and has not been run, exactly as this tree's three
# unbuilt assembly quadrants are text-compared rather than byte-compared.
# Labelled rather than presented as tested: one `make
# build/phase25-runtime-rs/gust_runtime_rs_exports.o` on either macOS
# quadrant settles it.
PHASE25_UNAME_S := $(shell uname -s)

ifeq ($(PHASE25_UNAME_S),Darwin)
define narrow_runtime_rs_link
ld -r -dead_strip -o $(2) \
	$(foreach sym,$(PHASE25_RUNTIME_RS_EXPORTS),-u _$(sym)) \
	$(foreach sym,$(PHASE25_RUNTIME_RS_EXPORTS),-exported_symbol _$(sym)) \
	$(1)
endef
else
define narrow_runtime_rs_link
ld -r --gc-sections -o $(3)/combined.o \
	$(foreach sym,$(PHASE25_RUNTIME_RS_EXPORTS),-u $(sym)) \
	--start-group $(1) --end-group
objcopy $(foreach sym,$(PHASE25_RUNTIME_RS_EXPORTS),--keep-global-symbol=$(sym)) \
	$(3)/combined.o $(2)
@rm -f $(3)/combined.o
endef
endif

define narrow_runtime_rs
@rm -rf $(3)
@mkdir -p $(3)
$(call narrow_runtime_rs_link,$(1),$(2),$(3))
@defined=$$(nm -g --defined-only $(2) | awk '$$2 ~ /^[TDBRW]$$/ {print $$3}' \
	| sed 's/^_//' | sort); \
expected=$$(printf '%s\n' $(PHASE25_RUNTIME_RS_EXPORTS) | sort); \
if [ "$$defined" != "$$expected" ]; then \
	echo 'src/runtime-rs exports drifted from the registered set: $(2)' >&2; \
	diff <(echo "$$expected") <(echo "$$defined") >&2; exit 1; \
fi
endef

# The partial link is PLATFORM-SPECIFIC, and this patch is committed to
# four quadrants: macOS-x86_64, Linux-x86_64, macOS-aarch64, Linux-aarch64.
# fiber_asm.rs preserves all four; a GNU-only build rule would have kept
# the assembly portable and made the build that consumes it Linux-only.
#
# ELF (GNU ld + objcopy): --gc-sections drops what the roots do not reach,
# --start-group resolves the archive's internal cycles, and objcopy
# localises everything outside the export list.
#
# Mach-O (ld64): none of those options exist. Dead-stripping is
# -dead_strip, archives need no group because ld64 iterates to a fixed
# point, and there is no objcopy -- ld64 does the narrowing itself with
# -exported_symbol, which localises the rest in the same pass. Mach-O
# symbols carry a leading underscore, so the export list is prefixed.
#
# UNVERIFIED ON THIS HOST. The Linux arm is measured; the Darwin arm is
# written from ld64's documented options and has not been run, exactly as
# this patch's three unbuilt assembly quadrants are text-compared rather
# than byte-compared. Labelled rather than presented as tested: what
# would settle it is one `make build/phase25-runtime-rs/...` on either
# macOS quadrant.

# The export set lives in THIS file, so the Makefile is a real input to both
# narrowed objects. Without it here, editing PHASE25_RUNTIME_RS_EXPORTS leaves
# a stale object carrying the old symbol set, and the drift check inside the
# define passes because it compares the object against the list it was built
# from, not the list as it now reads. Measured on 25.6: make reported the
# object up to date after the export list changed.
$(PHASE25_RUNTIME_RS_OBJ): $(PHASE25_RUNTIME_RS) Makefile
	$(call narrow_runtime_rs,$(PHASE25_RUNTIME_RS),$@,build/phase25-runtime-rs)

# Patch 25.5: the GUST_DEBUG arena, as a SECOND ARCHIVE.
#
# arena.c picked its allocator with `#ifdef GUST_DEBUG`, per translation
# unit, so `-DGUST_DEBUG` on a test's own compile line switched the arena
# to the canary layout. A Rust staticlib is built once and linked into
# both, so the switch moved to the build. tests/test_runner.gst links this
# object for exactly the tests it compiles with -DGUST_DEBUG.
#
# Separate --target-dir, not a rebuild in place: sharing one would make
# the two archives evict each other and whichever was built second would
# be the only one that existed.
$(PHASE25_RUNTIME_RS_CANARY): $(PHASE25_RUNTIME_RS_SRCS)
	$(CARGO) build --release --features gust_debug \
		--manifest-path src/runtime-rs/Cargo.toml \
		--target-dir src/runtime-rs/target/canary

$(PHASE25_RUNTIME_RS_CANARY_OBJ): $(PHASE25_RUNTIME_RS_CANARY) Makefile
	$(call narrow_runtime_rs,$(PHASE25_RUNTIME_RS_CANARY),$@,build/phase25-runtime-rs-canary)

$(PHASE21_RUNTIME_PACKAGE): $(PHASE21_RUNTIME_OBJECTS) $(PHASE25_RUNTIME_RS_OBJ)
	@rm -f build/.gust-runtime-package.a.tmp
	# The Rust fixture object joins the runtime archive, so the archive keeps
	# one name and one shape while its contents move language.
	ar rcs build/.gust-runtime-package.a.tmp $(PHASE21_RUNTIME_OBJECTS) $(PHASE25_RUNTIME_RS_OBJ)
	mv build/.gust-runtime-package.a.tmp $(PHASE21_RUNTIME_PACKAGE)

phase10-native-package: gust build/gust-native-backend $(PHASE21_RUNTIME_PACKAGE)
	@rm -rf build/phase10-package/.bin.tmp
	mkdir -p build/phase10-package/.bin.tmp
	install -m 0755 gust build/phase10-package/.bin.tmp/gust
	install -m 0755 build/gust-native-backend build/phase10-package/.bin.tmp/gust-native-backend
	install -m 0644 $(PHASE21_RUNTIME_PACKAGE) build/phase10-package/.bin.tmp/gust-runtime-package.a
	@rm -rf build/phase10-package/bin
	mv build/phase10-package/.bin.tmp build/phase10-package/bin
	@echo "✅ Phase 10 native package ready: build/phase10-package/bin/gust, build/phase10-package/bin/gust-native-backend, and build/phase10-package/bin/gust-runtime-package.a"

# Fixed-Point Bootstrap Verification
#
# Patch 25.10: THE C FIXED POINT IS RETIRED, and this target is inverted
# rather than deleted.
#
# It compared build/gust_stage2.c against build/gust_stage3.c for byte
# identity -- the current compiler emitting its own C, twice. With the
# emitter deleted there is no stage two, so the comparison has no operands.
#
# Deleting the target would leave `make bootstrap` as "no rule to make
# target", which tells a caller nothing about what happened to the
# property. The property did not go away: Patch 25.7 moved it to the
# EMITTED OBJECTS, stage_n == stage_n+1, which is a strictly stronger
# statement than identical C -- Patch 25.2's artifact set excludes linked
# executables by name because the linker normalises differences away, and
# it was doing exactly that until 25.7's BTreeMap fix.
#
# So this target now says where the fixed point went and runs it.
bootstrap: gust
	@echo "⚙️  The C fixed point is retired. Patch 25.10 deleted the emitter,"
	@echo "   so there is no stage-two C to compare against stage three."
	@echo "   The fixed point moved to the emitted OBJECTS in Patch 25.7:"
	@echo "   stage_n == stage_n+1, which the linker cannot normalise away."
	@echo "   Running it now."
	./scripts/phase25_native_fixed_point.sh
	@# Patch 25.9 removed the seed republication from here; Patch 25.10
	@# removes the stage-two binary that replaced it as the bootstrap.
	@# gust_bootstrap is the fetched, digest-verified bridge now, and
	@# overwriting it with a locally built binary would substitute an
	@# unverified artifact for a verified one.
	touch gust

test: gust require_just
	@CC="${CC}" CFLAGS="${CFLAGS}" INCLUDES="${INCLUDES}" just make-test-suite

test_tree_sitter:
	@echo "🔍 Running Tree-sitter corpus tests..."
	cd tree-sitter-gust && tree-sitter test
	@echo "🔍 Validating all Gust files parse with zero errors (including explicit reference-access tests)..."
	@for f in compiler/*.gst tests/*.gst; do \
		echo "Parsing $$f..."; \
		(cd tree-sitter-gust && tree-sitter parse ../$$f --quiet) || exit 1; \
	done
	@echo "✅ Tree-sitter parsing validation passed!"

JUST_REPORT_TARGETS = \
        report_phase4_formatter_tools \
        report_step51_raw_pointer_deref \
        report_step51_raw_pointer_casts \
        report_step51_address_escapes_focused \
        report_step51_ffi_calls \
        report_step51_ffi_focused \
        report_step51_unsafe_func_signatures \
        report_step51_raw_pointer_classified \
        report_step51_raw_pointer_safe_code_candidates \
        report_step51_phase_b_wrapping_status \
        report_step51_phase_c_basic_unsafe_status \
        report_step51_phase_d_ffi_status \
        report_step51_phase_e_address_escape_status \
        report_step51_phase_f_non_laundering_status \
        report_step51_deferred_unsafe_semantics_status \
        report_step51_status_matrix \
        report_step51_raw_pointer_safety_inventory \
        report_step51_final_validation \
        report_step52_linear_resource_inventory \
        report_step52_linear_resource_focused \
        report_step52_phase_a_status \
        report_step52_phase_b_destructor_status \
        report_step52_phase_c_resource_registry_status \
        report_step52_phase_d_transfer_status \
        report_step52_phase_e_enforcement_preconditions_status \
        report_step52_phase_f_closure_status \
        report_step52_status_matrix \
        report_step52_final_validation \
        report_step44_accessor_contract \
        report_step45_accessor_contract \
        report_step45_final_validation \
        report_compiler_get_opt_migration \
        report_high_level_raw_collection_casts \
        report_step45_subscript_lvalue_writes \
        report_step45_test_subscript_lvalue_writes \
        report_step45_subscript_lvalue_classified

$(JUST_REPORT_TARGETS): require_just
	@just $@

JUST_STEP51_GUARD_TARGETS = \
	guard_step51_report_only_lanes_not_in_test \
	guard_step51_raw_deref_unsafe_enforcement \
	guard_step51_raw_cast_unsafe_enforcement \
	guard_step51_pointer_arithmetic_unsafe_enforcement \
	guard_step51_unsafe_func_call_enforcement \
	guard_step51_raw_pointer_local_escape_enforcement \
	guard_step51_extern_func_parser_metadata \
	guard_step51_extern_func_call_enforcement \
	guard_step51_layout_metadata_defaults \
	guard_step51_layout_ffi_policy_helpers \
	guard_step51_layout_ffi_signature_helpers \
	guard_step51_sandbox_policy_defaults \
	guard_step51_address_origin_metadata \
	guard_step51_expression_provenance_carrier \
	guard_step51_safe_constructor_provenance \
	guard_step51_selector_safe_constructor_provenance \
	guard_step51_container_safe_constructor_provenance \
	guard_step51_container_method_provenance \
	guard_step51_arena_write_provenance \
	guard_step51_container_getref_provenance \
	guard_step51_hashmap_get_value_provenance \
	guard_step51_hashmap_get_value_field_provenance \
	guard_step51_std_vector_getref_provenance \
	guard_step51_std_hashmap_getref_provenance \
	guard_step51_std_hashmap_getref_selector_alias_provenance \
	guard_step51_std_vector_getref_selector_alias_provenance \
	guard_step51_reference_selector_alias_provenance \
	guard_step51_variable_provenance_bindings \
	guard_step51_return_provenance_capture \
	guard_step51_function_call_provenance \
	guard_step51_aggregate_field_provenance \
	guard_step51_container_provenance \
	guard_step51_non_laundering_return_enforcement \
	guard_step51_non_laundering_binding_enforcement \
	guard_step51_non_laundering_call_enforcement \
	guard_step51_non_laundering_field_enforcement \
	guard_step51_non_laundering_container_enforcement \
	guard_step51_non_laundering_container_method_enforcement \
	guard_step51_non_laundering_arena_write_enforcement \
	guard_step51_non_laundering_reference_selector_enforcement \
	guard_step51_non_laundering_hashmap_get_value_enforcement \
	guard_step51_non_laundering_hashmap_get_value_field_enforcement \
	guard_step51_basic_unsafe_enforcement

$(JUST_STEP51_GUARD_TARGETS): gust require_just
	@just $@

guard_step52_report_only_lanes_not_in_test:
	@echo "🔒 Guarding Step 5.2 report-only lanes are not direct just make-test-guards dependencies..."
	@test_deps="$$(awk 'capture == 1 && /^make-test-suite:/ { exit } /^make-test-guards:/ { capture = 1 } capture == 1 { print }' justfile)"; \
	if echo "$$test_deps" | grep -q 'report_step52_'; then \
	        echo "❌ Step 5.2 report-only target is wired into just make-test-guards:"; \
	        echo "$$test_deps"; \
	        exit 1; \
	fi
	@echo "✅ Step 5.2 report-only lanes are not direct just make-test-guards dependencies."

guard_step52_no_post_closure_report_churn:
	@echo "🔒 Guarding Step 5.2 report-only closure against new report target churn..."
	@allowed_reports='^(report_step52_linear_resource_inventory|report_step52_linear_resource_focused|report_step52_phase_a_status|report_step52_phase_b_destructor_status|report_step52_phase_c_resource_registry_status|report_step52_phase_d_transfer_status|report_step52_phase_e_enforcement_preconditions_status|report_step52_phase_f_closure_status|report_step52_status_matrix|report_step52_final_validation):$$'; \
	extra_reports="$$(grep -E '^report_step52_.*:' justfile-reports | grep -Ev "$$allowed_reports" || true)"; \
	if [ -n "$$extra_reports" ]; then \
	        echo "❌ Unexpected post-closure Step 5.2 report target(s):"; \
	        echo "$$extra_reports"; \
	        echo "Step 5.2F closed textual report churn; move to AST/typechecker design or update this whitelist intentionally."; \
	        exit 1; \
	fi
	@echo "✅ Step 5.2 report-only closure whitelist is unchanged."

JUST_STEP45_GUARD_TARGETS = \
	guard_step45_safe_subscript_write_enforcement

$(JUST_STEP45_GUARD_TARGETS): gust require_just
	@just $@

JUST_GUARD_TARGETS = \
	guard_step44_low_risk_entry_raw_casts \
	guard_step44_typechecker_aux_raw_casts \
	guard_step44_typechecker_types_raw_casts \
	guard_step44_codegen_initializer_raw_casts \
	guard_step44_typechecker_early_raw_casts \
	guard_step44_typechecker_methods_raw_casts \
	guard_step44_typechecker_pool_graph_raw_casts \
	guard_step44_typechecker_call_validation_raw_casts \
	guard_step44_typechecker_generic_helpers_raw_casts \
	guard_step44_typechecker_template_registration_raw_casts \
	guard_step44_typechecker_env_registration_raw_casts \
	guard_step44_typechecker_brand_helpers_raw_casts \
	guard_step44_typechecker_function_checks_raw_casts \
	guard_step44_typechecker_statement_traversal_raw_casts \
	guard_step44_codegen_early_helpers_raw_casts \
	guard_step44_codegen_dispatch_methods_raw_casts \
	guard_step44_codegen_pool_graph_std_raw_casts \
	guard_step44_codegen_std_alloc_helpers_raw_casts \
	guard_step44_codegen_runtime_tail_raw_casts \
	guard_step44_codegen_statement_emit_raw_casts \
	guard_step44_codegen_program_passes_raw_casts \
	guard_step44_no_high_level_raw_collection_casts \
	guard_parser_high_level_raw_casts

$(JUST_GUARD_TARGETS): require_just
	@just $@

clean:
	rm -rf gust_bootstrap gust build/

install: phase10-native-package
	install -d "$(DESTDIR)$(PREFIX)/bin"
	install -m 0755 build/phase10-package/bin/gust "$(DESTDIR)$(PREFIX)/bin/gust"
	install -m 0755 build/phase10-package/bin/gust-native-backend "$(DESTDIR)$(PREFIX)/bin/gust-native-backend"
	install -m 0644 build/phase10-package/bin/gust-runtime-package.a "$(DESTDIR)$(PREFIX)/bin/gust-runtime-package.a"
