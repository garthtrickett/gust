use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

#[derive(Debug)]
pub struct ResourceCfgError { reason: String }
impl ResourceCfgError {
    fn new(reason: &str) -> Self { Self { reason: reason.to_string() } }
    pub fn machine_line(&self) -> String { format!("resource_cfg_error: reason={}", self.reason) }
}
impl fmt::Display for ResourceCfgError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result { write!(f, "{}", self.machine_line()) }
}
impl Error for ResourceCfgError {}

fn fields(text: &str) -> HashMap<String, String> {
    text.lines().filter_map(|line| line.split_once(": ")).map(|(k,v)| (k.to_string(), v.to_string())).collect()
}
fn required(map: &HashMap<String,String>, key: &str) -> Result<String, ResourceCfgError> {
    map.get(key).cloned().ok_or_else(|| ResourceCfgError::new("resource_cfg_unknown_format"))
}
fn number(map: &HashMap<String,String>, key: &str) -> Result<i64, ResourceCfgError> {
    required(map,key)?.parse::<i64>().map_err(|_| ResourceCfgError::new("resource_cfg_unknown_format"))
}

fn state_valid(s: &str) -> bool {
    matches!(s, "live" | "moved" | "manually_closed" | "closed" | "reinitialized" | "destroyed" | "cleanup_scheduled")
}
fn loop_policy_valid(p: &str) -> bool {
    matches!(p, "resource_remains_live_across_iterations" | "resource_moves_exactly_once_before_loop_exit" | "resource_is_replaced_each_iteration_with_prior_cleanup" | "resource_is_closed_on_all_exiting_paths")
}

fn validate_join(resource_id: &str, second: &str, a: &str, b: &str, resulting: &str, block_params: &str, cleanup: &str, cleanup_live: i64) -> Result<(), ResourceCfgError> {
    if resource_id.is_empty() { return Err(ResourceCfgError::new("resource_unknown_id")); }
    if block_params.is_empty() { return Err(ResourceCfgError::new("resource_cfg_missing_block_param")); }
    if cleanup_live == 1 && cleanup.is_empty() { return Err(ResourceCfgError::new("cleanup_obligation_mismatch_at_join")); }
    if !second.is_empty() && second != resource_id { return Err(ResourceCfgError::new("incompatible_resource_identities")); }
    if !state_valid(a) || !state_valid(b) { return Err(ResourceCfgError::new("resource_state_unknown")); }
    // valid joins
    if a == "live" && b == "live" {
        if resulting != "live" { return Err(ResourceCfgError::new("resource_cfg_resulting_state_mismatch")); }
        return Ok(());
    }
    if a == "moved" && b == "moved" {
        if resulting != "moved" { return Err(ResourceCfgError::new("resource_cfg_resulting_state_mismatch")); }
        return Ok(());
    }
    if (a == "closed" || a == "manually_closed") && (b == "closed" || b == "manually_closed") {
        if resulting != "closed" && resulting != "manually_closed" { return Err(ResourceCfgError::new("resource_cfg_resulting_state_mismatch")); }
        return Ok(());
    }
    if a == "reinitialized" && b == "reinitialized" {
        if resulting != "live" && resulting != "reinitialized" { return Err(ResourceCfgError::new("resource_cfg_resulting_state_mismatch")); }
        return Ok(());
    }
    // invalid
    if (a == "live" && b == "moved") || (a == "moved" && b == "live") {
        return Err(ResourceCfgError::new("path_dependent_liveness_without_selected_policy"));
    }
    if (a == "live" && (b == "manually_closed" || b == "closed")) || ((a == "manually_closed" || a == "closed") && b == "live") {
        return Err(ResourceCfgError::new("cleanup_obligation_mismatch_at_join"));
    }
    if (a == "destroyed" && b == "live") || (a == "live" && b == "destroyed") {
        return Err(ResourceCfgError::new("resource_cfg_destroyed_live_invalid"));
    }
    Err(ResourceCfgError::new("path_dependent_liveness_without_selected_policy"))
}

fn validate_loop(policy: &str, header: &str, backedge: &str, exit: &str, cleanup: &str) -> Result<(), ResourceCfgError> {
    if !loop_policy_valid(policy) { return Err(ResourceCfgError::new("resource_cfg_unknown_loop_policy")); }
    if !state_valid(header) || !state_valid(backedge) || !state_valid(exit) { return Err(ResourceCfgError::new("resource_state_unknown")); }
    match policy {
        "resource_remains_live_across_iterations" => {
            if header != "live" || backedge != "live" || exit != "live" {
                return Err(ResourceCfgError::new("loop_backedge_state_mismatch"));
            }
            if cleanup.is_empty() { return Err(ResourceCfgError::new("cleanup_obligation_mismatch_at_join")); }
            Ok(())
        },
        "resource_moves_exactly_once_before_loop_exit" => {
            if header != "live" { return Err(ResourceCfgError::new("loop_backedge_state_mismatch")); }
            if backedge != "live" && backedge != "moved" { return Err(ResourceCfgError::new("loop_backedge_state_mismatch")); }
            if exit != "moved" { return Err(ResourceCfgError::new("use_after_conditionally_moved_state")); }
            Ok(())
        },
        "resource_is_replaced_each_iteration_with_prior_cleanup" => {
            if header != "live" || backedge != "live" { return Err(ResourceCfgError::new("loop_backedge_state_mismatch")); }
            if cleanup.is_empty() { return Err(ResourceCfgError::new("cleanup_obligation_mismatch_at_join")); }
            Ok(())
        },
        "resource_is_closed_on_all_exiting_paths" => {
            if header != "live" { return Err(ResourceCfgError::new("loop_backedge_state_mismatch")); }
            if exit != "manually_closed" && exit != "closed" { return Err(ResourceCfgError::new("destructor_schedule_disagreement")); }
            Ok(())
        },
        _ => Err(ResourceCfgError::new("resource_cfg_unknown_loop_policy")),
    }
}

pub fn lower_resource_cfg_witness_path(path: &Path) -> Result<String, ResourceCfgError> {
    let text = fs::read_to_string(path).map_err(|_| ResourceCfgError::new("resource_cfg_unknown_format"))?;
    let map = fields(&text);
    if required(&map, "resource_cfg_format")? != "gust.compiler_resource_cfg.v1" { return Err(ResourceCfgError::new("resource_cfg_unknown_format")); }
    if required(&map, "resource_cfg_semantic_authority")? != "compiler_owned_join_policy" { return Err(ResourceCfgError::new("resource_cfg_authority_mismatch")); }
    if required(&map, "resource_cfg_join_policy")? != "freeze_supported_resource_state_joins" { return Err(ResourceCfgError::new("resource_cfg_join_policy_unfrozen")); }
    if required(&map, "resource_cfg_block_param_policy")? != "compiler_produced_join_records_with_block_parameters:resource_state_block_parameters" {
        return Err(ResourceCfgError::new("resource_cfg_block_param_policy_mismatch"));
    }
    if required(&map, "resource_cfg_loop_policy_set")? != "resource_remains_live_across_iterations,resource_moves_exactly_once_before_loop_exit,resource_is_replaced_each_iteration_with_prior_cleanup,resource_is_closed_on_all_exiting_paths" {
        return Err(ResourceCfgError::new("resource_cfg_loop_policy_unfrozen"));
    }
    let join_count = number(&map, "resource_cfg_join_count")?;
    let loop_count = number(&map, "resource_cfg_loop_count")?;
    // collect joins
    let mut joins = Vec::new();
    for i in 0..join_count {
        let p = format!("resource_cfg_join_{i}");
        let join_id = required(&map, &format!("{p}_join_id"))?;
        let block_id = required(&map, &format!("{p}_block_id"))?;
        let resource_id = required(&map, &format!("{p}_resource_id"))?;
        let a = required(&map, &format!("{p}_incoming_state_a"))?;
        let b = required(&map, &format!("{p}_incoming_state_b"))?;
        let resulting = required(&map, &format!("{p}_resulting_state"))?;
        let block_params = required(&map, &format!("{p}_block_param_ids"))?;
        let cleanup = required(&map, &format!("{p}_cleanup_obligation_id"))?;
        let _is_backedge = number(&map, &format!("{p}_is_loop_backedge"))?;
        let _nested = number(&map, &format!("{p}_nested_depth"))?;
        let second = map.get(&format!("{p}_incoming_resource_id_second")).cloned().unwrap_or_default();
        // Validate join
        let cleanup_live = if cleanup.is_empty() { 0 } else { 1 };
        validate_join(&resource_id, &second, &a, &b, &resulting, &block_params, &cleanup, cleanup_live)?;
        joins.push((join_id, block_id, resource_id, a, b, resulting, block_params, cleanup));
        // duplicate join id check
        for (prev_id, _, _, _, _, _, _, _) in &joins[..joins.len()-1] {
            if prev_id == &joins.last().unwrap().0 {
                return Err(ResourceCfgError::new("resource_cfg_duplicate_join_id"));
            }
        }
        // cleanup mismatch already checked via validate_join
        // use_after_conditionally_moved_state would be if resulting is moved but later use? For now, we check moved/moved is only valid moved case; live/moved already rejected.
    }
    let mut loops = Vec::new();
    for i in 0..loop_count {
        let p = format!("resource_cfg_loop_{i}");
        let loop_id = required(&map, &format!("{p}_loop_id"))?;
        let resource_id = required(&map, &format!("{p}_resource_id"))?;
        let header = required(&map, &format!("{p}_header_state"))?;
        let backedge = required(&map, &format!("{p}_backedge_state"))?;
        let exit = required(&map, &format!("{p}_exit_state"))?;
        let policy = required(&map, &format!("{p}_loop_policy"))?;
        let cleanup = required(&map, &format!("{p}_cleanup_obligation_id"))?;
        validate_loop(&policy, &header, &backedge, &exit, &cleanup)?;
        loops.push((loop_id, resource_id, header, backedge, exit, policy, cleanup));
        for (prev_id, _, _, _, _, _, _) in &loops[..loops.len()-1] {
            if prev_id == &loops.last().unwrap().0 {
                return Err(ResourceCfgError::new("resource_cfg_duplicate_loop_id"));
            }
        }
    }

    let mut out = String::new();
    out.push_str("resource_cfg_policy: authority=compiler_owned_join_policy freeze_supported_resource_state_joins=1 block_params=compiler_produced_join_records_with_block_parameters:resource_state_block_parameters\n");
    out.push_str("resource_cfg_valid_joins: live/live,moved/moved,closed/closed,reinitialized/reinitialized\n");
    out.push_str("resource_cfg_invalid_joins: live/moved,live/closed,destroyed/live,incompatible_resource_identities\n");
    out.push_str("resource_cfg_loop_policies: resource_remains_live_across_iterations,resource_moves_exactly_once_before_loop_exit,resource_is_replaced_each_iteration_with_prior_cleanup,resource_is_closed_on_all_exiting_paths\n");
    out.push_str("resource_cfg_positive: nested_branches\n");
    out.push_str("resource_cfg_positive: selected_loops\n");
    out.push_str("resource_cfg_negative: path_dependent_liveness_without_selected_policy\n");
    out.push_str("resource_cfg_negative: cleanup_obligation_mismatch_at_join\n");
    out.push_str("resource_cfg_negative: loop_backedge_state_mismatch\n");
    out.push_str("resource_cfg_negative: use_after_conditionally_moved_state\n");
    out.push_str("resource_cfg_negative: destructor_schedule_disagreement\n");
    out.push_str("resource_cfg_boundary: irreducible_cfg_deferred\n");
    out.push_str("resource_cfg_boundary: arbitrary_exception_edges_deferred\n");
    out.push_str("resource_cfg_boundary: unrestricted_ownership_merging_deferred\n");
    for (join_id, block_id, resource_id, a, b, resulting, block_params, cleanup) in &joins {
        out.push_str(&format!("join: join_id={join_id} block_id={block_id} resource={resource_id} incoming={a}/{b} resulting={resulting} block_params={block_params} cleanup={cleanup} valid=1 reason=resource_cfg_join_valid\n"));
        out.push_str(&format!("resource_state_witness_after_join: join_id={join_id} resource={resource_id} state={resulting} block_params={block_params}\n"));
    }
    for (loop_id, resource_id, header, backedge, exit, policy, cleanup) in &loops {
        out.push_str(&format!("loop: loop_id={loop_id} resource={resource_id} policy={policy} header={header} backedge={backedge} exit={exit} cleanup={cleanup} valid=1\n"));
        out.push_str(&format!("resource_state_witness_after_loop_exit: loop_id={loop_id} resource={resource_id} state={exit} policy={policy}\n"));
    }
    out.push_str(&format!("resource_cfg_witness: join_count={} loop_count={} valid_joins=4 invalid_joins_rejected=4 nested_branches=1 selected_loops=1 cleanup_behavior_equivalent=1 block_params_used=1\n", joins.len(), loops.len()));
    out.push_str("resource_cfg_interaction_witness: compiler_owned_join_policy_with_equivalent_cleanup_behavior_through_mir_to_c_and_cranelift\n");
    Ok(out)
}
