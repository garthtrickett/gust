use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

#[derive(Debug)]
pub struct FailureCleanupError {
    reason: String,
}

impl FailureCleanupError {
    fn new(reason: &str) -> Self {
        Self {
            reason: reason.to_string(),
        }
    }

    pub fn machine_line(&self) -> String {
        format!("failure_cleanup_error: reason={}", self.reason)
    }
}

impl fmt::Display for FailureCleanupError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}", self.machine_line())
    }
}

impl Error for FailureCleanupError {}

#[derive(Clone)]
struct Form {
    id: String,
    failure_stage: String,
    terminal_kind: String,
    stable_authority: String,
    cleanup_policy: String,
    resource_id: String,
    scope_exit_id: String,
    final_state: String,
    cleanup_count: i64,
    destructor_count: i64,
    exit_status: i64,
    output_preserved: i64,
}

fn fields(text: &str) -> HashMap<String, String> {
    text.lines()
        .filter_map(|line| line.split_once(": "))
        .map(|(key, value)| (key.to_string(), value.to_string()))
        .collect()
}

fn required(map: &HashMap<String, String>, key: &str) -> Result<String, FailureCleanupError> {
    map.get(key)
        .cloned()
        .ok_or_else(|| FailureCleanupError::new("failure_cleanup_unknown_format"))
}

fn number(map: &HashMap<String, String>, key: &str) -> Result<i64, FailureCleanupError> {
    required(map, key)?
        .parse::<i64>()
        .map_err(|_| FailureCleanupError::new("failure_cleanup_unknown_format"))
}

fn validate_form(form: &Form) -> Result<(), FailureCleanupError> {
    match form.id.as_str() {
        "trap_before_exec" => {
            if form.failure_stage != "before_driver_discovery"
                || form.terminal_kind != "compiler_rejection"
                || form.stable_authority != "compiler_resource_cleanup_verifier"
                || form.cleanup_policy != "no_cleanup_resource_not_initialized"
                || form.resource_id != "none"
                || form.scope_exit_id != "none"
                || form.final_state != "uninitialized"
                || form.cleanup_count != 0
                || form.destructor_count != 0
                || form.exit_status != 65
                || form.output_preserved != 1
            {
                return Err(FailureCleanupError::new(
                    "failure_cleanup_form_policy_mismatch",
                ));
            }
        }
        "runtime_failure_return" => validate_cleanup_form(
            form,
            "runtime_failure_status_edge",
            "failure_return",
            "canonical_mir_failure_return.v1",
            82,
        )?,
        "selected_panic" => validate_cleanup_form(
            form,
            "compiler_selected_panic_edge",
            "trap_after_cleanup",
            "gust.compiler_panic.v1",
            101,
        )?,
        "native_op_failure_edge" => validate_cleanup_form(
            form,
            "canonical_mir_native_failure_edge",
            "propagate_native_status",
            "gust.compiler_native_failure.v1",
            74,
        )?,
        _ => {
            return Err(FailureCleanupError::new(
                "failure_cleanup_form_policy_mismatch",
            ));
        }
    }
    Ok(())
}

fn validate_cleanup_form(
    form: &Form,
    stage: &str,
    terminal: &str,
    authority: &str,
    status: i64,
) -> Result<(), FailureCleanupError> {
    if form.failure_stage != stage
        || form.terminal_kind != terminal
        || form.stable_authority != authority
        || form.cleanup_policy != "cleanup_live_resources_then_terminate"
        || form.resource_id == "none"
        || form.scope_exit_id == "none"
        || form.final_state != "destroyed"
        || form.cleanup_count != 1
        || form.destructor_count != 1
        || form.exit_status != status
        || form.output_preserved != 1
    {
        return Err(FailureCleanupError::new(
            "failure_cleanup_form_policy_mismatch",
        ));
    }
    Ok(())
}

pub fn lower_failure_cleanup_witness_path(path: &Path) -> Result<String, FailureCleanupError> {
    let text = fs::read_to_string(path)
        .map_err(|_| FailureCleanupError::new("failure_cleanup_unknown_format"))?;
    let map = fields(&text);
    if required(&map, "failure_cleanup_format")? != "gust.compiler_failure_cleanup.v1" {
        return Err(FailureCleanupError::new("failure_cleanup_unknown_format"));
    }
    if required(&map, "failure_cleanup_semantic_authority")?
        != "compiler_owned_failure_cleanup_policy"
        || required(&map, "failure_cleanup_backend_policy")?
            != "shared_canonical_mir_failure_edges_no_backend_cleanup_planner"
    {
        return Err(FailureCleanupError::new(
            "failure_cleanup_authority_mismatch",
        ));
    }
    if required(&map, "failure_cleanup_selected_forms")?
        != "trap_before_exec,runtime_failure_return,selected_panic,native_op_failure_edge"
    {
        return Err(FailureCleanupError::new(
            "failure_cleanup_inventory_unfrozen",
        ));
    }
    if required(&map, "failure_cleanup_deferred_forms")?
        != "async_unwind,foreign_exception,cancellation"
    {
        return Err(FailureCleanupError::new(
            "failure_cleanup_deferred_boundary_mismatch",
        ));
    }
    if required(&map, "failure_cleanup_order_policy")? != "reverse_declaration_inner_before_outer"
        || required(&map, "failure_cleanup_target_applicability")?
            != "all_declared_host_targets_from_phase14_target_authority"
    {
        return Err(FailureCleanupError::new("failure_cleanup_policy_mismatch"));
    }

    let count = number(&map, "failure_cleanup_form_count")?;
    if count != 4 {
        return Err(FailureCleanupError::new(
            "failure_cleanup_form_count_mismatch",
        ));
    }
    let mut forms = Vec::new();
    let mut seen = HashSet::new();
    for index in 0..count {
        let prefix = format!("failure_cleanup_form_{index}");
        let form = Form {
            id: required(&map, &format!("{prefix}_id"))?,
            failure_stage: required(&map, &format!("{prefix}_failure_stage"))?,
            terminal_kind: required(&map, &format!("{prefix}_terminal_kind"))?,
            stable_authority: required(&map, &format!("{prefix}_stable_authority"))?,
            cleanup_policy: required(&map, &format!("{prefix}_cleanup_policy"))?,
            resource_id: required(&map, &format!("{prefix}_resource_id"))?,
            scope_exit_id: required(&map, &format!("{prefix}_scope_exit_id"))?,
            final_state: required(&map, &format!("{prefix}_final_state"))?,
            cleanup_count: number(&map, &format!("{prefix}_cleanup_count"))?,
            destructor_count: number(&map, &format!("{prefix}_destructor_count"))?,
            exit_status: number(&map, &format!("{prefix}_exit_status"))?,
            output_preserved: number(&map, &format!("{prefix}_output_preserved"))?,
        };
        if !seen.insert(form.id.clone()) {
            return Err(FailureCleanupError::new("failure_cleanup_duplicate_form"));
        }
        validate_form(&form)?;
        forms.push(form);
    }

    let mut output = String::from(
        "failure_cleanup_policy: authority=compiler selected_forms=trap_before_exec,runtime_failure_return,selected_panic,native_op_failure_edge deferred_forms=async_unwind,foreign_exception,cancellation order=reverse_declaration_inner_before_outer exactly_once=1 backend_cleanup_planner=0\n",
    );
    let mut total_cleanup = 0;
    let mut total_destructor = 0;
    for form in &forms {
        output.push_str(&format!(
            "failure_cleanup: form={} stage={} terminal={} stable_authority={} cleanup_policy={} final_state={} cleanup_count={} destructor_count={} exit_status={} output_preserved={}\n",
            form.id,
            form.failure_stage,
            form.terminal_kind,
            form.stable_authority,
            form.cleanup_policy,
            form.final_state,
            form.cleanup_count,
            form.destructor_count,
            form.exit_status,
            form.output_preserved,
        ));
        total_cleanup += form.cleanup_count;
        total_destructor += form.destructor_count;
    }
    output.push_str(&format!(
        "failure_cleanup_witness: selected_form_count=4 cleanup_count={total_cleanup} destructor_count={total_destructor} exactly_once=1 order=reverse_declaration_inner_before_outer output_preserved=1 generic_authority=1\n"
    ));
    Ok(output)
}
