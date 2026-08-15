use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_resource_aggregate_abi.v1";
const CLEANUP_ORDER: &str =
    "cancel_source>transfer>create_destination>destination_cleanup>destructor";

#[derive(Debug)]
pub struct ResourceAggregateAbiError {
    reason_code: &'static str,
    detail: String,
}
impl ResourceAggregateAbiError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}
impl fmt::Display for ResourceAggregateAbiError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "gust_resource_aggregate_abi_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}
impl Error for ResourceAggregateAbiError {}
fn error(reason: &'static str, detail: impl Into<String>) -> ResourceAggregateAbiError {
    ResourceAggregateAbiError::new(reason, detail)
}
fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, ResourceAggregateAbiError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| {
            error(
                "resource_aggregate_unknown_format",
                format!("missing {key}"),
            )
        })
}
fn row(line: &str) -> Result<HashMap<String, String>, ResourceAggregateAbiError> {
    let body = line
        .strip_prefix("resource_aggregate_plan:")
        .ok_or_else(|| error("resource_aggregate_unknown_format", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|part| !part.is_empty()) {
        let Some((key, value)) = part.split_once('=') else {
            return Err(error("resource_aggregate_unknown_format", part));
        };
        if fields.insert(key.into(), value.into()).is_some() {
            return Err(error("resource_aggregate_duplicate_identity", key));
        }
    }
    Ok(fields)
}
fn field<'a>(
    fields: &'a HashMap<String, String>,
    key: &str,
) -> Result<&'a str, ResourceAggregateAbiError> {
    fields.get(key).map(String::as_str).ok_or_else(|| {
        error(
            "resource_aggregate_record_invalid",
            format!("missing {key}"),
        )
    })
}
fn same(
    fields: &HashMap<String, String>,
    left: &str,
    right: &str,
    reason: &'static str,
) -> Result<(), ResourceAggregateAbiError> {
    if field(fields, left)? != field(fields, right)? {
        return Err(error(reason, format!("{left} disagrees with {right}")));
    }
    Ok(())
}
fn validate_row(
    fields: &HashMap<String, String>,
    target: &str,
    triple: &str,
) -> Result<(), ResourceAggregateAbiError> {
    for key in [
        "id",
        "call",
        "function_abi",
        "placement",
        "type",
        "layout",
        "abi_value",
        "source_resource",
        "source_owner",
        "destination_resource",
        "destination_owner",
        "transition",
        "destination_cleanup",
        "destructor",
        "transfer_point",
        "source",
    ] {
        if field(fields, key)?.is_empty() {
            return Err(error("resource_aggregate_record_invalid", key));
        }
    }
    if !matches!(
        (
            field(fields, "scenario")?,
            field(fields, "position")?,
            field(fields, "transport")?
        ),
        ("move_into_call", "parameter", "by_value_move")
            | ("aggregate_return_new_owner", "result", "direct_result_move")
            | ("nested_resource_aggregate", "result", "hidden_result_move")
            | (
                "early_return_after_receipt",
                "parameter",
                "indirect_by_value_move"
            )
            | (
                "reassign_returned_aggregate",
                "result",
                "hidden_result_move"
            )
    ) {
        return Err(error(
            "resource_aggregate_record_invalid",
            "scenario/position/transport",
        ));
    }
    if field(fields, "size")? != "16" || field(fields, "alignment")? != "8" {
        return Err(error(
            "resource_aggregate_layout_mismatch",
            field(fields, "id")?,
        ));
    }
    if field(fields, "silent_copy")? != "0" || !field(fields, "transport")?.contains("move") {
        return Err(error(
            "resource_aggregate_silent_copy",
            field(fields, "id")?,
        ));
    }
    if field(fields, "source_resource")? == field(fields, "destination_resource")? {
        return Err(error(
            "resource_aggregate_missing_destination_identity",
            field(fields, "id")?,
        ));
    }
    if field(fields, "transfer_validated")? != "1" {
        return Err(error(
            "resource_aggregate_transfer_point_invalid",
            field(fields, "id")?,
        ));
    }
    if field(fields, "live_owner_count")? != "1" {
        return Err(error(
            "resource_aggregate_two_live_owners",
            field(fields, "id")?,
        ));
    }
    if field(fields, "old_cleanup_cancelled")? != "1"
        || field(fields, "destination_cleanup_created")? != "1"
    {
        return Err(error(
            "resource_aggregate_stale_source_cleanup",
            field(fields, "id")?,
        ));
    }
    same(
        fields,
        "destructor",
        "actual_destructor",
        "resource_aggregate_destructor_mismatch",
    )?;
    if field(fields, "destructor_count")? != "1" {
        return Err(error(
            "resource_aggregate_destructor_mismatch",
            field(fields, "id")?,
        ));
    }
    if field(fields, "transport")? == "hidden_result_move"
        && field(fields, "publication_initialized")? != "1"
    {
        return Err(error(
            "resource_aggregate_uninitialized_publication",
            field(fields, "id")?,
        ));
    }
    same(
        fields,
        "caller_policy",
        "callee_policy",
        "resource_aggregate_caller_callee_disagreement",
    )?;
    if field(fields, "caller_policy")? != "move_only_exact_transfer"
        || field(fields, "failure_before")? != "source_retains_ownership_and_cleanup"
        || field(fields, "failure_after")? != "destination_owns_cleanup"
    {
        return Err(error(
            "resource_aggregate_caller_callee_disagreement",
            field(fields, "id")?,
        ));
    }
    same(
        fields,
        "cleanup_order",
        "actual_cleanup_order",
        "resource_aggregate_stale_source_cleanup",
    )?;
    if field(fields, "cleanup_order")? != CLEANUP_ORDER {
        return Err(error(
            "resource_aggregate_stale_source_cleanup",
            field(fields, "id")?,
        ));
    }
    same(
        fields,
        "expected_value",
        "actual_value",
        "resource_aggregate_value_mismatch",
    )?;
    if target != "target:x86_64-unknown-linux-gnu"
        || triple != "x86_64-unknown-linux-gnu"
        || field(fields, "target")? != target
        || field(fields, "actual_target")? != target
        || field(fields, "triple")? != triple
        || field(fields, "actual_triple")? != triple
    {
        return Err(error(
            "resource_aggregate_target_mismatch",
            field(fields, "id")?,
        ));
    }
    Ok(())
}
fn validate(contents: &str) -> Result<(), ResourceAggregateAbiError> {
    let lines: Vec<_> = contents.lines().collect();
    if header(&lines, "resource_aggregate_format")? != FORMAT {
        return Err(error(
            "resource_aggregate_unknown_format",
            "unsupported format",
        ));
    }
    let target = header(&lines, "resource_aggregate_target_id")?;
    let triple = header(&lines, "resource_aggregate_target_triple")?;
    let count: usize = header(&lines, "resource_aggregate_plan_count")?
        .parse()
        .map_err(|_| error("resource_aggregate_unknown_format", "count"))?;
    let rows: Vec<_> = lines
        .iter()
        .filter(|line| line.starts_with("resource_aggregate_plan:"))
        .map(|line| row(line))
        .collect::<Result<_, _>>()?;
    if rows.len() != count || rows.is_empty() {
        return Err(error("resource_aggregate_record_invalid", "count"));
    }
    let mut ids = HashSet::new();
    let mut destination_resources = HashSet::new();
    let mut cleanups = HashSet::new();
    let mut scenarios = HashSet::new();
    for fields in &rows {
        if !ids.insert(field(fields, "id")?)
            || !destination_resources.insert(field(fields, "destination_resource")?)
            || !cleanups.insert(field(fields, "destination_cleanup")?)
        {
            return Err(error(
                "resource_aggregate_duplicate_identity",
                field(fields, "id")?,
            ));
        }
        scenarios.insert(field(fields, "scenario")?);
        validate_row(fields, target, triple)?;
    }
    for scenario in [
        "move_into_call",
        "aggregate_return_new_owner",
        "nested_resource_aggregate",
        "early_return_after_receipt",
        "reassign_returned_aggregate",
    ] {
        if !scenarios.contains(scenario) {
            return Err(error(
                "resource_aggregate_record_invalid",
                format!("missing {scenario}"),
            ));
        }
    }
    Ok(())
}
pub fn lower_resource_aggregate_abi_witness_path(
    path: &Path,
) -> Result<String, ResourceAggregateAbiError> {
    let contents = fs::read_to_string(path)
        .map_err(|cause| error("resource_aggregate_request_read_failed", cause.to_string()))?;
    validate(&contents)?;
    let mut witness = contents;
    if !witness.ends_with('\n') {
        witness.push('\n');
    }
    Ok(witness)
}
const _WORKER_POLICY: &str = "worker_consumes_compiler_aggregate_abi_phase15_resource_transition_cleanup_and_destructor_plan_no_backend_ownership_transfer";
