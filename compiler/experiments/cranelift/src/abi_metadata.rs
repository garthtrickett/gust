use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_abi_metadata_request.v1";
const RESTORE_POLICY: &str = "phase15_cleanup_then_lifetime_end_then_stack_restore";

#[derive(Debug)]
pub struct AbiMetadataError {
    reason_code: &'static str,
    detail: String,
}

impl AbiMetadataError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}

impl fmt::Display for AbiMetadataError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "gust_abi_metadata_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for AbiMetadataError {}

fn error(reason: &'static str, detail: impl Into<String>) -> AbiMetadataError {
    AbiMetadataError::new(reason, detail)
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, AbiMetadataError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("abi_metadata_unknown_format", key))
}

fn parse_row(line: &str) -> Result<HashMap<String, String>, AbiMetadataError> {
    let body = line
        .strip_prefix("abi_metadata_record:")
        .ok_or_else(|| error("abi_metadata_unknown_format", "record"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|part| !part.is_empty()) {
        let Some((key, value)) = part.split_once('=') else {
            return Err(error("abi_metadata_unknown_format", part));
        };
        if fields.insert(key.into(), value.into()).is_some() {
            return Err(error("abi_metadata_duplicate_conflicting_record", key));
        }
    }
    Ok(fields)
}

fn field<'a>(fields: &'a HashMap<String, String>, key: &str) -> Result<&'a str, AbiMetadataError> {
    fields
        .get(key)
        .map(String::as_str)
        .ok_or_else(|| error("abi_metadata_unknown_format", key))
}

fn optional<'a>(fields: &'a HashMap<String, String>, key: &str) -> &'a str {
    fields.get(key).map(String::as_str).unwrap_or("")
}

fn parse_nonnegative(
    fields: &HashMap<String, String>,
    key: &str,
) -> Result<usize, AbiMetadataError> {
    field(fields, key)?
        .parse::<usize>()
        .map_err(|_| error("abi_metadata_impossible_placement", key))
}

fn validate(contents: &str) -> Result<(), AbiMetadataError> {
    let lines: Vec<_> = contents.lines().collect();
    if header(&lines, "abi_metadata_format")? != FORMAT {
        return Err(error("abi_metadata_unknown_format", "format"));
    }
    let target = header(&lines, "abi_metadata_target_id")?;
    let triple = header(&lines, "abi_metadata_target_triple")?;
    if target.is_empty() || triple.is_empty() {
        return Err(error("abi_metadata_target_mismatch", "request target"));
    }
    let count: usize = header(&lines, "abi_metadata_record_count")?
        .parse()
        .map_err(|_| error("abi_metadata_unknown_format", "count"))?;
    let rows: Vec<_> = lines
        .iter()
        .filter(|line| line.starts_with("abi_metadata_record:"))
        .map(|line| parse_row(line))
        .collect::<Result<_, _>>()?;
    if rows.len() != count || rows.is_empty() {
        return Err(error("abi_metadata_unknown_format", "record count"));
    }

    let mut ids = HashSet::new();
    let mut abi_ids = HashSet::new();
    let mut classifications = HashSet::new();
    let mut parameters = HashSet::new();
    let mut results = HashSet::new();
    let mut hidden_values = HashSet::new();
    let mut call_plans = HashSet::new();
    let mut compatibility_decisions = HashSet::new();
    let mut frames = HashSet::new();
    let mut layouts = HashSet::new();
    let mut resources = HashSet::new();
    let mut mir_owners = HashMap::new();

    for (index, fields) in rows.iter().enumerate() {
        if parse_nonnegative(fields, "sequence")? != index {
            return Err(error(
                "abi_metadata_nondeterministic_ordering",
                field(fields, "id")?,
            ));
        }
        let id = field(fields, "id")?;
        if id.is_empty() || !ids.insert(id) {
            return Err(error("abi_metadata_duplicate_conflicting_record", id));
        }
        match field(fields, "kind")? {
            "function_abi" => {
                abi_ids.insert(field(fields, "abi")?);
            }
            "classification" => {
                classifications.insert(field(fields, "classification")?);
            }
            "parameter_placement" => {
                parameters.insert(field(fields, "parameter")?);
            }
            "result_placement" => {
                results.insert(field(fields, "result")?);
            }
            "hidden_value" => {
                hidden_values.insert(field(fields, "hidden")?);
            }
            "call_plan" => {
                call_plans.insert(field(fields, "call_plan")?);
            }
            "compatibility" => {
                compatibility_decisions.insert(field(fields, "compatibility")?);
            }
            "dynamic_frame" => {
                frames.insert(field(fields, "frame")?);
            }
            "layout_reference" => {
                layouts.insert(field(fields, "layout")?);
            }
            "resource_transfer" => {
                resources.insert(field(fields, "resource")?);
            }
            "mir_owner" => {
                mir_owners.insert(field(fields, "mir_owner")?, field(fields, "mir_kind")?);
            }
            kind => return Err(error("abi_metadata_unknown_format", kind)),
        }
    }

    let mut stack_areas: Vec<(usize, usize, &str)> = Vec::new();
    for fields in &rows {
        let id = field(fields, "id")?;
        let kind = field(fields, "kind")?;
        if kind != "mir_owner" {
            let owner = field(fields, "owner")?;
            if !mir_owners.contains_key(owner) {
                return Err(error("abi_metadata_without_mir_owner", id));
            }
        }
        if kind == "mir_owner" && field(fields, "mir_kind")? == "call" {
            let plan = field(fields, "call_plan")?;
            if plan.is_empty() || !call_plans.contains(plan) {
                return Err(error("abi_metadata_mir_call_missing_metadata", id));
            }
        }
        for key in ["abi", "expected_abi", "actual_abi"] {
            let value = optional(fields, key);
            if !value.is_empty() && !abi_ids.contains(value) {
                return Err(error("abi_metadata_unknown_abi_id", value));
            }
        }
        let layout = optional(fields, "layout");
        if !layout.is_empty() && kind != "layout_reference" && !layouts.contains(layout) {
            return Err(error("abi_metadata_unknown_layout_or_resource_id", layout));
        }
        let resource = optional(fields, "resource");
        if !resource.is_empty() && kind != "resource_transfer" && !resources.contains(resource) {
            return Err(error(
                "abi_metadata_unknown_layout_or_resource_id",
                resource,
            ));
        }
        let row_target = optional(fields, "target");
        if !row_target.is_empty() && row_target != target {
            return Err(error("abi_metadata_target_mismatch", id));
        }
        match kind {
            "function_abi" => {
                if field(fields, "signature")?.is_empty()
                    || field(fields, "cc")? != "gust_canonical_v1"
                    || !parameters.contains(field(fields, "parameter")?)
                    || !results.contains(field(fields, "result")?)
                    || !hidden_values.contains(field(fields, "hidden")?)
                    || !frames.contains(field(fields, "frame")?)
                {
                    return Err(error("abi_metadata_signature_mismatch", id));
                }
            }
            "classification" => {
                if !layouts.contains(field(fields, "layout")?) {
                    return Err(error("abi_metadata_unknown_layout_or_resource_id", id));
                }
            }
            "parameter_placement" | "result_placement" => {
                if !classifications.contains(field(fields, "classification")?)
                    || !matches!(
                        field(fields, "passing_mode")?,
                        "direct" | "split" | "indirect_by_value" | "indirect_by_reference"
                    )
                {
                    return Err(error("abi_metadata_impossible_placement", id));
                }
                let start = parse_nonnegative(fields, "stack_offset")?;
                let size = parse_nonnegative(fields, "stack_size")?;
                if size == 0 {
                    return Err(error("abi_metadata_impossible_placement", id));
                }
                stack_areas.push((start, start + size, id));
            }
            "hidden_value" => {
                if field(fields, "passing_mode")? != "hidden_pointer"
                    || !results.contains(field(fields, "result")?)
                {
                    return Err(error("abi_metadata_invalid_hidden_result", id));
                }
                let start = parse_nonnegative(fields, "stack_offset")?;
                let size = parse_nonnegative(fields, "stack_size")?;
                if size == 0 {
                    return Err(error("abi_metadata_invalid_hidden_result", id));
                }
                stack_areas.push((start, start + size, id));
            }
            "call_plan" => {
                if field(fields, "signature")? != field(fields, "actual_signature")?
                    || field(fields, "cc")? != "gust_canonical_v1"
                    || !compatibility_decisions.contains(field(fields, "compatibility")?)
                {
                    return Err(error("abi_metadata_signature_mismatch", id));
                }
            }
            "compatibility" => {
                if field(fields, "compatible")? != "1" {
                    return Err(error("abi_metadata_signature_mismatch", id));
                }
            }
            "dynamic_frame" => {
                if field(fields, "restore")? != RESTORE_POLICY {
                    return Err(error("abi_metadata_invalid_frame_restoration", id));
                }
                let start = parse_nonnegative(fields, "stack_offset")?;
                let size = parse_nonnegative(fields, "stack_size")?;
                if size == 0 {
                    return Err(error("abi_metadata_impossible_placement", id));
                }
                stack_areas.push((start, start + size, id));
            }
            "resource_transfer" => {
                if field(fields, "transfer")?.is_empty()
                    || field(fields, "source_cleanup_cancelled")? != "1"
                    || field(fields, "destination_cleanup_created")? != "1"
                    || field(fields, "live_owner_count")? != "1"
                {
                    return Err(error("abi_metadata_resource_transfer_inconsistent", id));
                }
            }
            _ => {}
        }
    }

    stack_areas.sort_by_key(|area| area.0);
    for pair in stack_areas.windows(2) {
        if pair[0].1 > pair[1].0 {
            return Err(error(
                "abi_metadata_overlapping_stack_areas",
                format!("{} and {}", pair[0].2, pair[1].2),
            ));
        }
    }
    Ok(())
}

pub fn lower_abi_metadata_witness_path(path: &Path) -> Result<String, AbiMetadataError> {
    let contents = fs::read_to_string(path)
        .map_err(|cause| error("abi_metadata_request_read_failed", cause.to_string()))?;
    validate(&contents)?;
    let mut witness = contents;
    if !witness.ends_with('\n') {
        witness.push('\n');
    }
    Ok(witness)
}

const _WORKER_POLICY: &str = "worker_validates_compiler_produced_abi_metadata_but_never_invents_classification_placement_signature_hidden_result_frame_or_resource_transfer";
