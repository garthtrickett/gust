set shell := ["bash", "-eu", "-o", "pipefail", "-c"]

default:
    just --list

# Canonical build graph stays in Make.
gust:
    make gust

test:
    make test

bootstrap:
    make bootstrap

make-target target:
    make "{{target}}"

# Rust test helpers.
gtl:
    RUST_LOG=debug cargo test test -- --nocapture --test-threads=1 > to.log 2>&1
    echo "📝 All tests run. Output written to to.log"

gt-one name:
    RUST_LOG=debug cargo test "{{name}}" -- --nocapture > to.log 2>&1
    echo "📝 Test '{{name}}' run. Output written to to.log"

# Focused self-hosted Gust workflows use the shared script.
gt-one-gst file:
    bash scripts/run-gust-file.sh "{{file}}"

guard file:
    bash scripts/run-gust-file.sh "{{file}}"

guard-step51-hashmap-get-value:
    just guard compiler/typechecker_hashmap_get_value_provenance_test_entry.gst

guard-step51-hashmap-get-value-field:
    just guard compiler/typechecker_hashmap_get_value_field_provenance_test_entry.gst

guard-step51-non-launder-hashmap-get-value:
    just guard compiler/typechecker_non_laundering_hashmap_get_value_test_entry.gst

guard-step51-non-launder-hashmap-get-value-field:
    just guard compiler/typechecker_non_laundering_hashmap_get_value_field_test_entry.gst

# Report aliases stay informational; Makefile policy guards keep reports out of make test.
report-step51:
    make report_step51_status_matrix
    make report_step51_deferred_unsafe_semantics_status

report-step52:
    make report_step52_status_matrix
    make report_step52_final_validation

check:
    make
    make test
    make bootstrap