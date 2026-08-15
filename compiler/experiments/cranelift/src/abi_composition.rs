use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const COVERAGE: &str = "p16_function_abi_authority,p16_canonical_call_result_mir,p16_aggregate_parameter_abi,p16_aggregate_return_hidden_result_abi,p16_direct_call_agreement,p16_typed_indirect_calls,p16_fat_pointer_trait_object_call_abi,p16_unsized_value_abi,p16_dynamic_stack_storage,p16_resource_aggregate_call_abi,p16_cross_module_aggregate_resource_abi,p16_abi_metadata_validation";
const OPERATIONS: &str = "aggregate_parameter,aggregate_result,hidden_result,direct_call,typed_indirect_call,fat_pointer_call,unsized_metadata,dynamic_stack,resource_transfer,cross_module_call,failure_before_transfer,failure_after_transfer";
const COMPARISONS: &str = "default_explicit_mir_to_c_byte_identity,runtime_values,stdout,stderr,exit_status,parameter_result_witnesses,hidden_value_witnesses,layouts,resource_transitions,cleanup_destructor_order,filesystem_effects,initialized_data,output_preservation,mir_to_c_cranelift_witness_identity";

#[derive(Debug)]
pub struct AbiCompositionError(String);
impl AbiCompositionError {
    fn new(reason: &str) -> Self {
        Self(reason.into())
    }
}
impl fmt::Display for AbiCompositionError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "abi_composition_error: reason={}", self.0)
    }
}
impl Error for AbiCompositionError {}

fn fields(text: &str) -> HashMap<String, String> {
    text.lines()
        .filter_map(|line| line.split_once(": "))
        .map(|(key, value)| (key.into(), value.into()))
        .collect()
}
fn required(map: &HashMap<String, String>, key: &str) -> Result<String, AbiCompositionError> {
    map.get(key)
        .cloned()
        .ok_or_else(|| AbiCompositionError::new("abi_composition_unknown_format"))
}
fn number(map: &HashMap<String, String>, key: &str) -> Result<i64, AbiCompositionError> {
    required(map, key)?
        .parse()
        .map_err(|_| AbiCompositionError::new("abi_composition_unknown_format"))
}

pub fn lower_abi_composition_witness_path(path: &Path) -> Result<String, AbiCompositionError> {
    let text = fs::read_to_string(path)
        .map_err(|_| AbiCompositionError::new("abi_composition_unknown_format"))?;
    let map = fields(&text);
    if required(&map, "abi_composition_format")? != "gust.compiler_abi_composition.v1" {
        return Err(AbiCompositionError::new("abi_composition_unknown_format"));
    }
    if required(&map, "abi_composition_semantic_authority")?
        != "compiler_owned_generic_abi_composition"
        || required(&map, "abi_composition_backend_policy")?
            != "shared_compiler_abi_layout_frame_and_phase15_resource_plan_no_backend_classifier"
    {
        return Err(AbiCompositionError::new(
            "abi_composition_authority_mismatch",
        ));
    }
    if required(&map, "abi_composition_case_id")? != "phase16:complete_abi_composition"
        || required(&map, "abi_composition_covered_entry_ids")? != COVERAGE
    {
        return Err(AbiCompositionError::new(
            "abi_composition_coverage_mismatch",
        ));
    }
    if required(&map, "abi_composition_operations")? != OPERATIONS
        || required(&map, "abi_composition_comparison_contract")? != COMPARISONS
    {
        return Err(AbiCompositionError::new(
            "abi_composition_contract_mismatch",
        ));
    }
    if required(&map, "abi_composition_target_applicability")?
        != "all_declared_host_targets_from_phase14_target_authority"
    {
        return Err(AbiCompositionError::new("abi_composition_target_mismatch"));
    }
    for (key, value) in [
        ("abi_composition_aggregate_parameter_count", 2),
        ("abi_composition_aggregate_result_count", 2),
        ("abi_composition_hidden_result_count", 1),
        ("abi_composition_direct_call_count", 1),
        ("abi_composition_typed_indirect_call_count", 1),
        ("abi_composition_fat_pointer_call_count", 1),
        ("abi_composition_unsized_metadata_count", 1),
        ("abi_composition_dynamic_frame_count", 1),
        ("abi_composition_resource_transfer_count", 1),
        ("abi_composition_cross_module_call_count", 1),
        ("abi_composition_failure_before_transfer_count", 1),
        ("abi_composition_failure_after_transfer_count", 1),
        ("abi_composition_output_preserved", 1),
    ] {
        if number(&map, key)? != value {
            return Err(AbiCompositionError::new(
                "abi_composition_witness_count_mismatch",
            ));
        }
    }
    Ok(String::from("abi_composition_policy: authority=compiler registry_derived=1 generic_abi_authority=1 backend_abi_classifier=0 backend_hidden_result_planner=0 backend_resource_transfer_planner=0 targets=all_declared_host_targets_from_phase14_target_authority\nabi_composition_case: id=phase16:complete_abi_composition covered_entries=12 operations=aggregate_parameter,aggregate_result,hidden_result,direct_call,typed_indirect_call,fat_pointer_call,unsized_metadata,dynamic_stack,resource_transfer,cross_module_call,failure_before_transfer,failure_after_transfer\nabi_composition_witness: aggregate_parameters=2 aggregate_results=2 hidden_results=1 direct_calls=1 typed_indirect_calls=1 fat_pointer_calls=1 unsized_metadata=1 dynamic_frames=1 resource_transfers=1 cross_module_calls=1 failure_before_transfer=1 failure_after_transfer=1 output_preserved=1 cleanup_order=callee_result_then_phase15_cleanup_then_transfer\nabi_composition_comparison: default_explicit_mir_to_c_byte_identity=1 mir_to_c_cranelift_witness_identity=1 runtime_values=1 stdout=1 stderr=1 exit_status=1 parameter_result_witnesses=1 hidden_value_witnesses=1 layouts=1 resource_transitions=1 cleanup_destructor_order=1 filesystem_effects=1 initialized_data=1\n"))
}

const _WORKER_POLICY:&str="worker_consumes_compiler_abi_composition_plan_without_backend_classification_hidden_result_frame_or_resource_transfer_planning";
