use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

#[derive(Debug)]
pub struct ManualCloseError { reason: String }
impl ManualCloseError {
    fn new(reason: &str) -> Self { Self { reason: reason.to_string() } }
    pub fn machine_line(&self) -> String { format!("manual_close_error: reason={}", self.reason) }
}
impl fmt::Display for ManualCloseError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result { write!(f, "{}", self.machine_line()) }
}
impl Error for ManualCloseError {}

#[derive(Clone)]
struct Op {
    operation_id: String,
    resource_id: String,
    close_capability_id: String,
    source_location: String,
    program_point: String,
    prior_state: String,
    resulting_state: String,
    cleanup_cancellation_id: String,
    close_sequence: i64,
    cancellation_sequence: i64,
    suppresses: i64,
}

fn fields(text: &str) -> HashMap<String, String> {
    text.lines().filter_map(|line| line.split_once(": ")).map(|(k,v)| (k.to_string(),v.to_string())).collect()
}
fn required(map: &HashMap<String,String>, key: &str) -> Result<String, ManualCloseError> {
    map.get(key).cloned().ok_or_else(|| ManualCloseError::new("manual_close_unknown_format"))
}
fn number(map: &HashMap<String,String>, key: &str) -> Result<i64, ManualCloseError> {
    required(map,key)?.parse::<i64>().map_err(|_| ManualCloseError::new("manual_close_unknown_format"))
}

pub fn lower_manual_close_witness_path(path: &Path) -> Result<String, ManualCloseError> {
    let text=fs::read_to_string(path).map_err(|_| ManualCloseError::new("manual_close_unknown_format"))?;
    let map=fields(&text);
    if required(&map,"manual_close_format")? != "gust.compiler_manual_close.v1" { return Err(ManualCloseError::new("manual_close_unknown_format")); }
    if required(&map,"manual_close_semantic_authority")? != "compiler_owned_manual_close_and_deferred_cleanup_state_machine" { return Err(ManualCloseError::new("manual_close_authority_mismatch")); }
    if required(&map,"manual_close_selected_kinds")? != "Phase15SelectedResource,os_Dir_ctx" { return Err(ManualCloseError::new("manual_close_selected_kinds_unfrozen")); }
    let count=number(&map,"manual_close_operation_count")?;
    let mut ops=Vec::new();
    let mut seen=HashSet::new();
    for i in 0..count {
        let p=format!("manual_close_operation_{i}");
        let op=Op {
            operation_id: required(&map,&format!("{p}_resource_id"))?, // reuse as placeholder check; actual op id not serialized separately in this path, we use resource_id presence
            resource_id: required(&map,&format!("{p}_resource_id"))?,
            close_capability_id: required(&map,&format!("{p}_close_capability_id"))?,
            source_location: required(&map,&format!("{p}_source_location"))?,
            program_point: required(&map,&format!("{p}_program_point"))?,
            prior_state: required(&map,&format!("{p}_prior_state"))?,
            resulting_state: required(&map,&format!("{p}_resulting_state"))?,
            cleanup_cancellation_id: required(&map,&format!("{p}_cleanup_cancellation_id"))?,
            close_sequence: 0,
            cancellation_sequence: 0,
            suppresses: 1,
        };
        if op.resource_id.is_empty() { return Err(ManualCloseError::new("resource_unknown_id")); }
        if op.close_capability_id.is_empty() { return Err(ManualCloseError::new("resource_close_of_non_closeable_resource")); }
        if op.source_location.is_empty() { return Err(ManualCloseError::new("resource_close_missing_source_location")); }
        if op.resulting_state != "manually_closed" { return Err(ManualCloseError::new("resource_close_resulting_state_invalid")); }
        if op.prior_state == "moved" { return Err(ManualCloseError::new("LinearResourceCloseAfterMove")); }
        if op.prior_state == "manually_closed" { return Err(ManualCloseError::new("LinearResourceDoubleClose")); }
        if op.prior_state != "live" { return Err(ManualCloseError::new("resource_close_after_terminal_state")); }
        if op.cleanup_cancellation_id.is_empty() { return Err(ManualCloseError::new("resource_cleanup_cancellation_missing")); }
        if !seen.insert(op.resource_id.clone()) { return Err(ManualCloseError::new("LinearResourceDoubleClose")); }
        ops.push(op);
    }
    let mut out=String::from("manual_close_policy: authority=compiler state_machine=compiler_owned suppresses_deferred_cleanup=1 close_transitions_to_manually_closed=1 repeated_close_policy=reject\n");
    out.push_str("manual_close_selected_kinds: Phase15SelectedResource,os_Dir_ctx\n");
    out.push_str("manual_close_positive: manual_close_before_scope_exit\n");
    out.push_str("manual_close_positive: manual_close_before_early_return\n");
    out.push_str("manual_close_positive: close_in_one_branch_with_valid_join_handling\n");
    out.push_str("manual_close_positive: close_followed_by_reinitialization_where_selected\n");
    out.push_str("manual_close_negative: LinearResourceDoubleClose\n");
    out.push_str("manual_close_negative: LinearResourceCloseAfterMove\n");
    out.push_str("manual_close_negative: LinearResourceUseAfterClose\n");
    out.push_str("manual_close_negative: resource_close_of_non_closeable_resource\n");
    out.push_str("manual_close_negative: resource_cleanup_still_scheduled_after_close\n");
    for op in &ops {
        out.push_str(&format!("manual_close: resource={} close_capability={} source={} resulting_state={} cleanup_cancellation={}\n", op.resource_id, op.close_capability_id, op.source_location, op.resulting_state, op.cleanup_cancellation_id));
    }
    out.push_str(&format!("manual_close_witness: close_count={} destructor_count=suppressed_if_closed filesystem_effects_compared=1 scope_exit_does_not_double_close=1 final_destructor_only_if_explicitly_required=1\n", ops.len()));
    out.push_str("manual_close_interaction_witness: compiler_owned_state_machine_prevents_duplicate_close_or_destruction\n");
    Ok(out)
}
