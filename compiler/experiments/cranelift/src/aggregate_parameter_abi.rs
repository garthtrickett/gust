use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_aggregate_parameter_abi.v1";

#[derive(Debug)]
pub struct AggregateParameterError {
    reason_code: &'static str,
    detail: String,
}

impl AggregateParameterError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}

impl fmt::Display for AggregateParameterError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_aggregate_parameter_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for AggregateParameterError {}

#[derive(Debug)]
struct Plan {
    id: String,
    abi: String,
    placement: String,
    parameter: String,
    ordinal: usize,
    type_id: String,
    layout: String,
    abi_value: String,
    shape: String,
    mode: String,
    size: usize,
    align: usize,
    caller: String,
    callee: String,
    padding: String,
    resource: String,
    transfer: String,
    resource_id: String,
    initialized: String,
    target: String,
    triple: String,
}

#[derive(Debug)]
struct Location {
    id: String,
    plan: String,
    ordinal: usize,
    logical_location: String,
    offset: usize,
    size: usize,
    align: usize,
    value: i64,
}

#[derive(Debug)]
struct Table {
    target: String,
    triple: String,
    plans: Vec<Plan>,
    locations: Vec<Location>,
}

fn error(reason: &'static str, detail: impl Into<String>) -> AggregateParameterError {
    AggregateParameterError::new(reason, detail)
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, AggregateParameterError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| {
            error(
                "aggregate_parameter_unknown_format",
                format!("missing {key}"),
            )
        })
}

fn count(lines: &[&str], key: &str) -> Result<usize, AggregateParameterError> {
    header(lines, key)?.parse().map_err(|_| {
        error(
            "aggregate_parameter_unknown_format",
            format!("invalid {key}"),
        )
    })
}

fn row(line: &str, prefix: &str) -> Result<HashMap<String, String>, AggregateParameterError> {
    let body = line
        .strip_prefix(prefix)
        .ok_or_else(|| error("aggregate_parameter_unknown_format", "invalid row prefix"))?;
    let mut fields = HashMap::new();
    for part in body.split(';') {
        let Some((key, value)) = part.split_once('=') else {
            return Err(error(
                "aggregate_parameter_unknown_format",
                format!("invalid field {part}"),
            ));
        };
        if fields.insert(key.to_owned(), value.to_owned()).is_some() {
            return Err(error(
                "aggregate_parameter_duplicate_plan",
                format!("duplicate field {key}"),
            ));
        }
    }
    Ok(fields)
}

fn field<'a>(
    fields: &'a HashMap<String, String>,
    key: &str,
) -> Result<&'a str, AggregateParameterError> {
    fields.get(key).map(String::as_str).ok_or_else(|| {
        error(
            "aggregate_parameter_invalid_record",
            format!("missing {key}"),
        )
    })
}

fn number<T: std::str::FromStr>(
    fields: &HashMap<String, String>,
    key: &str,
    reason: &'static str,
) -> Result<T, AggregateParameterError> {
    field(fields, key)?
        .parse()
        .map_err(|_| error(reason, format!("invalid {key}")))
}

fn parse(contents: &str) -> Result<Table, AggregateParameterError> {
    let lines: Vec<_> = contents.lines().collect();
    if header(&lines, "aggregate_parameter_format")? != FORMAT {
        return Err(error(
            "aggregate_parameter_unknown_format",
            "unsupported format",
        ));
    }
    let target = header(&lines, "aggregate_parameter_target_id")?.to_owned();
    let triple = header(&lines, "aggregate_parameter_target_triple")?.to_owned();
    let plan_count = count(&lines, "aggregate_parameter_plan_count")?;
    let location_count = count(&lines, "aggregate_parameter_location_count")?;
    let mut plans = Vec::new();
    let mut locations = Vec::new();
    for line in lines {
        if line.starts_with("aggregate_parameter_plan:") {
            let fields = row(line, "aggregate_parameter_plan:")?;
            plans.push(Plan {
                id: field(&fields, "id")?.to_owned(),
                abi: field(&fields, "abi")?.to_owned(),
                placement: field(&fields, "placement")?.to_owned(),
                parameter: field(&fields, "parameter")?.to_owned(),
                ordinal: number(
                    &fields,
                    "ordinal",
                    "aggregate_parameter_argument_order_mismatch",
                )?,
                type_id: field(&fields, "type")?.to_owned(),
                layout: field(&fields, "layout")?.to_owned(),
                abi_value: field(&fields, "abi_value")?.to_owned(),
                shape: field(&fields, "shape")?.to_owned(),
                mode: field(&fields, "mode")?.to_owned(),
                size: number(
                    &fields,
                    "size",
                    "aggregate_parameter_invalid_layout_identity",
                )?,
                align: number(
                    &fields,
                    "align",
                    "aggregate_parameter_invalid_layout_identity",
                )?,
                caller: field(&fields, "caller")?.to_owned(),
                callee: field(&fields, "callee")?.to_owned(),
                padding: field(&fields, "padding")?.to_owned(),
                resource: field(&fields, "resource")?.to_owned(),
                transfer: field(&fields, "transfer")?.to_owned(),
                resource_id: field(&fields, "resource_id")?.to_owned(),
                initialized: field(&fields, "initialized")?.to_owned(),
                target: field(&fields, "target")?.to_owned(),
                triple: field(&fields, "triple")?.to_owned(),
            });
        } else if line.starts_with("aggregate_parameter_location:") {
            let fields = row(line, "aggregate_parameter_location:")?;
            locations.push(Location {
                id: field(&fields, "id")?.to_owned(),
                plan: field(&fields, "plan")?.to_owned(),
                ordinal: number(
                    &fields,
                    "ordinal",
                    "aggregate_parameter_illegal_split_boundary",
                )?,
                logical_location: field(&fields, "location")?.to_owned(),
                offset: number(
                    &fields,
                    "offset",
                    "aggregate_parameter_illegal_split_boundary",
                )?,
                size: number(
                    &fields,
                    "size",
                    "aggregate_parameter_illegal_split_boundary",
                )?,
                align: number(
                    &fields,
                    "align",
                    "aggregate_parameter_insufficient_alignment",
                )?,
                value: number(&fields, "value", "aggregate_parameter_invalid_record")?,
            });
        }
    }
    if plans.len() != plan_count || locations.len() != location_count {
        return Err(error(
            "aggregate_parameter_invalid_record",
            "record count disagreement",
        ));
    }
    Ok(Table {
        target,
        triple,
        plans,
        locations,
    })
}

fn shape(shape: &str) -> Option<(&'static str, usize, usize, usize, &'static str)> {
    match shape {
        "struct_single_i32" => Some(("direct", 4, 4, 1, "DirectI32")),
        "struct_pair_i32" => Some(("split", 8, 4, 2, "PairI32")),
        "struct_triple_i64" => Some(("indirect_by_value", 24, 8, 1, "TripleI64")),
        _ => None,
    }
}

fn validate(table: &Table) -> Result<(), AggregateParameterError> {
    let mut ids = HashSet::new();
    let mut ordinals = HashSet::new();
    let known_plans: HashSet<_> = table.plans.iter().map(|plan| plan.id.as_str()).collect();
    for location in &table.locations {
        if !known_plans.contains(location.plan.as_str()) {
            return Err(error(
                "aggregate_parameter_caller_callee_disagreement",
                "unknown plan location",
            ));
        }
        if location.id.is_empty() || location.logical_location.is_empty() {
            return Err(error(
                "aggregate_parameter_invalid_record",
                "empty location identity",
            ));
        }
    }
    for plan in &table.plans {
        if !ids.insert(plan.id.as_str()) {
            return Err(error(
                "aggregate_parameter_duplicate_plan",
                format!("duplicate {}", plan.id),
            ));
        }
        if !ordinals.insert(plan.ordinal) {
            return Err(error(
                "aggregate_parameter_argument_order_mismatch",
                "duplicate argument ordinal",
            ));
        }
        if plan.target != table.target || plan.triple != table.triple {
            return Err(error(
                "aggregate_parameter_target_mismatch",
                format!("plan {}", plan.id),
            ));
        }
        let Some((expected_mode, expected_size, expected_align, expected_locations, layout_name)) =
            shape(&plan.shape)
        else {
            return Err(error(
                "aggregate_parameter_unsupported_shape",
                format!("shape {}", plan.shape),
            ));
        };
        if plan.mode != expected_mode || plan.size != expected_size || plan.align != expected_align
        {
            return Err(error(
                "aggregate_parameter_unsupported_shape",
                format!("classification {}", plan.id),
            ));
        }
        if !plan.layout.contains(layout_name)
            || !plan.layout.contains(&format!("size={}", plan.size))
            || !plan.layout.contains(&format!("align={}", plan.align))
            || !plan.type_id.contains(layout_name)
        {
            return Err(error(
                "aggregate_parameter_invalid_layout_identity",
                format!("layout {}", plan.layout),
            ));
        }
        if plan.abi.is_empty()
            || plan.placement.is_empty()
            || plan.parameter.is_empty()
            || plan.abi_value.is_empty()
        {
            return Err(error(
                "aggregate_parameter_caller_callee_disagreement",
                "missing ABI identity",
            ));
        }
        let materialization_ok = match plan.mode.as_str() {
            "direct" => plan.caller == "canonical_value" && plan.callee == "canonical_value",
            "split" => {
                plan.caller == "split_initialized_fields"
                    && plan.callee == "join_initialized_fields"
            }
            "indirect_by_value" => {
                plan.caller == "caller_owned_readonly_slot"
                    && plan.callee == "read_indirect_by_value"
            }
            _ => false,
        };
        if !materialization_ok {
            return Err(error(
                "aggregate_parameter_caller_callee_disagreement",
                format!("materialization {}", plan.id),
            ));
        }
        if plan.padding != "initialized_fields_only_padding_not_semantic"
            || plan.initialized.is_empty()
        {
            return Err(error(
                "aggregate_parameter_padding_policy_mismatch",
                format!("padding {}", plan.id),
            ));
        }
        if plan.resource != "non_resource"
            || plan.transfer != "copy"
            || !plan.resource_id.is_empty()
        {
            return Err(error(
                "aggregate_parameter_move_only_copy_rejected",
                format!("resource disposition {}", plan.id),
            ));
        }
        let mut selected: Vec<_> = table
            .locations
            .iter()
            .filter(|location| location.plan == plan.id)
            .collect();
        selected.sort_by_key(|location| location.ordinal);
        if selected.len() != expected_locations
            || selected
                .iter()
                .enumerate()
                .any(|(ordinal, location)| location.ordinal != ordinal)
        {
            return Err(error(
                "aggregate_parameter_illegal_split_boundary",
                format!("location count {}", plan.id),
            ));
        }
        for (index, location) in selected.iter().enumerate() {
            if location.align < plan.align {
                return Err(error(
                    "aggregate_parameter_insufficient_alignment",
                    format!("location {}", location.id),
                ));
            }
            if location.size == 0
                || location.offset % plan.align != 0
                || location.offset + location.size > plan.size
            {
                return Err(error(
                    "aggregate_parameter_illegal_split_boundary",
                    format!("location {}", location.id),
                ));
            }
            for prior in &selected[..index] {
                if location.offset < prior.offset + prior.size
                    && prior.offset < location.offset + location.size
                {
                    return Err(error(
                        "aggregate_parameter_overlapping_placements",
                        format!("location {}", location.id),
                    ));
                }
            }
            let _initialized_field_value = location.value;
        }
    }
    Ok(())
}

pub fn lower_aggregate_parameter_witness_path(
    path: &Path,
) -> Result<String, AggregateParameterError> {
    let contents = fs::read_to_string(path)
        .map_err(|cause| error("aggregate_parameter_request_read_failed", cause.to_string()))?;
    let table = parse(&contents)?;
    validate(&table)?;
    // This normalized request is already the compiler-produced semantic
    // witness. Cranelift validates and consumes it without reclassification.
    let mut witness = contents;
    if !witness.ends_with('\n') {
        witness.push('\n');
    }
    Ok(witness)
}

const _WORKER_POLICY: &str = "worker_no_backend_local_aggregate_parameter_classifier_no_source_text_no_generated_c_no_host_abi_guess";
