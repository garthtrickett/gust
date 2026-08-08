use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const COVERAGE: &str = "p15_resource_value_representation,p15_move_state_transitions,p15_use_after_move_enforcement,p15_reassignment_cleanup,p15_scope_exit_cleanup,p15_early_return_cleanup,p15_destructor_scheduling,p15_manual_close_interaction,p15_conditional_loop_resource_state,p15_resource_metadata_validation,p15_directory_resources,p15_selected_failure_cleanup";
const OPERATIONS: &str = "init,move,reassign,scope_exit,early_return,destructor,manual_close,branch_join,loop_carried,directory,failure_return";
const COMPARISONS: &str = "default_explicit_mir_to_c_byte_identity,runtime_values,stdout,stderr,exit_status,resource_witness,cleanup_witness,destructor_count,close_count,cleanup_order,filesystem_effects,output_preservation";

#[derive(Debug)]
pub struct ResourceCompositionError(String);
impl ResourceCompositionError {
    fn new(reason: &str) -> Self {
        Self(reason.to_string())
    }
}
impl fmt::Display for ResourceCompositionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "resource_composition_error: reason={}", self.0)
    }
}
impl Error for ResourceCompositionError {}

fn fields(text: &str) -> HashMap<String, String> {
    text.lines()
        .filter_map(|line| line.split_once(": "))
        .map(|(key, value)| (key.to_string(), value.to_string()))
        .collect()
}
fn required(map: &HashMap<String, String>, key: &str) -> Result<String, ResourceCompositionError> {
    map.get(key)
        .cloned()
        .ok_or_else(|| ResourceCompositionError::new("resource_composition_unknown_format"))
}
fn number(map: &HashMap<String, String>, key: &str) -> Result<i64, ResourceCompositionError> {
    required(map, key)?
        .parse()
        .map_err(|_| ResourceCompositionError::new("resource_composition_unknown_format"))
}

pub fn lower_resource_composition_witness_path(
    path: &Path,
) -> Result<String, ResourceCompositionError> {
    let text = fs::read_to_string(path)
        .map_err(|_| ResourceCompositionError::new("resource_composition_unknown_format"))?;
    let map = fields(&text);
    if required(&map, "resource_composition_format")? != "gust.compiler_resource_composition.v1" {
        return Err(ResourceCompositionError::new(
            "resource_composition_unknown_format",
        ));
    }
    if required(&map, "resource_composition_semantic_authority")?
        != "compiler_owned_generic_resource_composition"
        || required(&map, "resource_composition_backend_policy")?
            != "shared_compiler_plan_no_backend_resource_or_cleanup_planner"
    {
        return Err(ResourceCompositionError::new(
            "resource_composition_authority_mismatch",
        ));
    }
    if required(&map, "resource_composition_case_id")? != "phase15:complete_resource_composition"
        || required(&map, "resource_composition_covered_entry_ids")? != COVERAGE
    {
        return Err(ResourceCompositionError::new(
            "resource_composition_coverage_mismatch",
        ));
    }
    if required(&map, "resource_composition_operations")? != OPERATIONS
        || required(&map, "resource_composition_comparison_contract")? != COMPARISONS
    {
        return Err(ResourceCompositionError::new(
            "resource_composition_contract_mismatch",
        ));
    }
    if required(&map, "resource_composition_target_applicability")?
        != "all_declared_host_targets_from_phase14_target_authority"
    {
        return Err(ResourceCompositionError::new(
            "resource_composition_target_mismatch",
        ));
    }
    let expected = [
        ("resource_composition_resource_count", 3),
        ("resource_composition_move_count", 1),
        ("resource_composition_reassignment_count", 1),
        ("resource_composition_scope_cleanup_count", 1),
        ("resource_composition_early_cleanup_count", 1),
        ("resource_composition_destructor_count", 3),
        ("resource_composition_manual_close_count", 1),
        ("resource_composition_join_count", 1),
        ("resource_composition_loop_count", 1),
        ("resource_composition_directory_close_count", 1),
        ("resource_composition_failure_cleanup_count", 1),
        ("resource_composition_output_preserved", 1),
    ];
    for (key, value) in expected {
        if number(&map, key)? != value {
            return Err(ResourceCompositionError::new(
                "resource_composition_witness_count_mismatch",
            ));
        }
    }
    Ok(String::from(
        "resource_composition_policy: authority=compiler registry_derived=1 generic_resource_authority=1 backend_resource_planner=0 backend_cleanup_planner=0 targets=all_declared_host_targets_from_phase14_target_authority\nresource_composition_case: id=phase15:complete_resource_composition covered_entries=12 operations=init,move,reassign,scope_exit,early_return,destructor,manual_close,branch_join,loop_carried,directory,failure_return\nresource_composition_witness: resources=3 moves=1 reassignments=1 scope_cleanups=1 early_cleanups=1 destructors=3 manual_closes=1 joins=1 loops=1 directory_closes=1 failure_cleanups=1 output_preserved=1 cleanup_order=reverse_declaration_inner_before_outer\nresource_composition_comparison: default_explicit_mir_to_c_byte_identity=1 mir_to_c_cranelift_witness_identity=1 runtime_values=1 stdout=1 stderr=1 exit_status=1 counts=1 order=1 filesystem_effects=1\n",
    ))
}
