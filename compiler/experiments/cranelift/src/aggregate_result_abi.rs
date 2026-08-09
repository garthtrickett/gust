use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_aggregate_result_abi.v1";

#[derive(Debug)]
pub struct AggregateResultError {
    reason_code: &'static str,
    detail: String,
}

impl AggregateResultError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}

impl fmt::Display for AggregateResultError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_aggregate_result_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for AggregateResultError {}

#[derive(Debug)]
struct Plan {
    id: String,
    abi: String,
    placement: String,
    result: String,
    ordinal: usize,
    type_id: String,
    layout: String,
    abi_value: String,
    shape: String,
    mode: String,
    size: usize,
    align: usize,
    owner: String,
    storage: String,
    init_point: String,
    hidden_parameter: String,
    callee_write: String,
    caller_extract: String,
    failure: String,
    cleanup: String,
    padding: String,
    published: bool,
    resource: String,
    transition: String,
    target: String,
    triple: String,
}

#[derive(Debug)]
struct Write {
    id: String,
    plan: String,
    ordinal: usize,
    offset: usize,
    size: usize,
    align: usize,
    initialized: bool,
    value: i64,
}

#[derive(Debug)]
struct Operation {
    id: String,
    plan: String,
    kind: String,
    sequence: usize,
    storage: String,
    terminal: bool,
}

#[derive(Debug)]
struct Table {
    target: String,
    triple: String,
    plans: Vec<Plan>,
    writes: Vec<Write>,
    operations: Vec<Operation>,
}

fn error(reason: &'static str, detail: impl Into<String>) -> AggregateResultError {
    AggregateResultError::new(reason, detail)
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, AggregateResultError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("aggregate_result_unknown_format", format!("missing {key}")))
}

fn count(lines: &[&str], key: &str) -> Result<usize, AggregateResultError> {
    header(lines, key)?
        .parse()
        .map_err(|_| error("aggregate_result_unknown_format", format!("invalid {key}")))
}

fn row(line: &str, prefix: &str) -> Result<HashMap<String, String>, AggregateResultError> {
    let body = line
        .strip_prefix(prefix)
        .ok_or_else(|| error("aggregate_result_unknown_format", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';') {
        let Some((key, value)) = part.split_once('=') else {
            return Err(error(
                "aggregate_result_unknown_format",
                format!("invalid field {part}"),
            ));
        };
        if fields.insert(key.to_owned(), value.to_owned()).is_some() {
            return Err(error(
                "aggregate_result_duplicate_identity",
                format!("duplicate field {key}"),
            ));
        }
    }
    Ok(fields)
}

fn field<'a>(
    fields: &'a HashMap<String, String>,
    key: &str,
) -> Result<&'a str, AggregateResultError> {
    fields
        .get(key)
        .map(String::as_str)
        .ok_or_else(|| error("aggregate_result_invalid_record", format!("missing {key}")))
}

fn number<T: std::str::FromStr>(
    fields: &HashMap<String, String>,
    key: &str,
    reason: &'static str,
) -> Result<T, AggregateResultError> {
    field(fields, key)?
        .parse()
        .map_err(|_| error(reason, format!("invalid {key}")))
}

fn flag(
    fields: &HashMap<String, String>,
    key: &str,
    reason: &'static str,
) -> Result<bool, AggregateResultError> {
    match field(fields, key)? {
        "0" => Ok(false),
        "1" => Ok(true),
        _ => Err(error(reason, format!("invalid {key}"))),
    }
}

fn parse(contents: &str) -> Result<Table, AggregateResultError> {
    let lines: Vec<_> = contents.lines().collect();
    if header(&lines, "aggregate_result_format")? != FORMAT {
        return Err(error(
            "aggregate_result_unknown_format",
            "unsupported format",
        ));
    }
    let target = header(&lines, "aggregate_result_target_id")?.to_owned();
    let triple = header(&lines, "aggregate_result_target_triple")?.to_owned();
    let plan_count = count(&lines, "aggregate_result_plan_count")?;
    let write_count = count(&lines, "aggregate_result_write_count")?;
    let operation_count = count(&lines, "aggregate_result_operation_count")?;
    let mut plans = Vec::new();
    let mut writes = Vec::new();
    let mut operations = Vec::new();
    for line in lines {
        if line.starts_with("aggregate_result_plan:") {
            let f = row(line, "aggregate_result_plan:")?;
            plans.push(Plan {
                id: field(&f, "id")?.into(),
                abi: field(&f, "abi")?.into(),
                placement: field(&f, "placement")?.into(),
                result: field(&f, "result")?.into(),
                ordinal: number(&f, "ordinal", "aggregate_result_caller_callee_disagreement")?,
                type_id: field(&f, "type")?.into(),
                layout: field(&f, "layout")?.into(),
                abi_value: field(&f, "abi_value")?.into(),
                shape: field(&f, "shape")?.into(),
                mode: field(&f, "mode")?.into(),
                size: number(&f, "size", "aggregate_result_wrong_layout_or_alignment")?,
                align: number(&f, "align", "aggregate_result_wrong_layout_or_alignment")?,
                owner: field(&f, "owner")?.into(),
                storage: field(&f, "storage")?.into(),
                init_point: field(&f, "init_point")?.into(),
                hidden_parameter: field(&f, "hidden_parameter")?.into(),
                callee_write: field(&f, "callee_write")?.into(),
                caller_extract: field(&f, "caller_extract")?.into(),
                failure: field(&f, "failure")?.into(),
                cleanup: field(&f, "cleanup")?.into(),
                padding: field(&f, "padding")?.into(),
                published: flag(
                    &f,
                    "published",
                    "aggregate_result_uninitialized_publication",
                )?,
                resource: field(&f, "resource")?.into(),
                transition: field(&f, "transition")?.into(),
                target: field(&f, "target")?.into(),
                triple: field(&f, "triple")?.into(),
            });
        } else if line.starts_with("aggregate_result_write:") {
            let f = row(line, "aggregate_result_write:")?;
            writes.push(Write {
                id: field(&f, "id")?.into(),
                plan: field(&f, "plan")?.into(),
                ordinal: number(&f, "ordinal", "aggregate_result_uninitialized_publication")?,
                offset: number(&f, "offset", "aggregate_result_wrong_layout_or_alignment")?,
                size: number(&f, "size", "aggregate_result_wrong_layout_or_alignment")?,
                align: number(&f, "align", "aggregate_result_wrong_layout_or_alignment")?,
                initialized: flag(
                    &f,
                    "initialized",
                    "aggregate_result_uninitialized_publication",
                )?,
                value: number(&f, "value", "aggregate_result_invalid_record")?,
            });
        } else if line.starts_with("aggregate_result_operation:") {
            let f = row(line, "aggregate_result_operation:")?;
            operations.push(Operation {
                id: field(&f, "id")?.into(),
                plan: field(&f, "plan")?.into(),
                kind: field(&f, "kind")?.into(),
                sequence: number(
                    &f,
                    "sequence",
                    "aggregate_result_caller_callee_disagreement",
                )?,
                storage: field(&f, "storage")?.into(),
                terminal: flag(&f, "terminal", "aggregate_result_written_after_terminal")?,
            });
        }
    }
    if plans.len() != plan_count
        || writes.len() != write_count
        || operations.len() != operation_count
    {
        return Err(error(
            "aggregate_result_invalid_record",
            "record count disagreement",
        ));
    }
    Ok(Table {
        target,
        triple,
        plans,
        writes,
        operations,
    })
}

fn shape(value: &str) -> Option<(&'static str, usize, usize, usize, &'static str)> {
    match value {
        "struct_single_i32" => Some(("direct", 4, 4, 1, "ResultDirectI32")),
        "struct_pair_i32" => Some(("split", 8, 4, 2, "ResultPairI32")),
        "struct_triple_i64" => Some(("hidden_pointer", 24, 8, 3, "ResultTripleI64")),
        _ => None,
    }
}

fn valid_operation(value: &str) -> bool {
    matches!(
        value,
        "allocate_hidden_storage"
            | "evaluate_return_value"
            | "write_result_field"
            | "phase15_cleanup"
            | "publish_result"
            | "extract_result"
    )
}

fn validate(table: &Table) -> Result<(), AggregateResultError> {
    let mut ids = HashSet::new();
    let mut results = HashSet::new();
    let mut hidden_storage = HashSet::new();
    let known: HashSet<_> = table.plans.iter().map(|p| p.id.as_str()).collect();
    for write in &table.writes {
        if !known.contains(write.plan.as_str()) || write.id.is_empty() {
            return Err(error(
                "aggregate_result_caller_callee_disagreement",
                "unknown write plan",
            ));
        }
    }
    for operation in &table.operations {
        if !known.contains(operation.plan.as_str()) || operation.id.is_empty() {
            return Err(error(
                "aggregate_result_caller_callee_disagreement",
                "unknown operation plan",
            ));
        }
    }
    for plan in &table.plans {
        if !ids.insert(plan.id.as_str()) || !results.insert(plan.result.as_str()) {
            return Err(error(
                "aggregate_result_duplicate_identity",
                format!("plan {}", plan.id),
            ));
        }
        if plan.target != table.target || plan.triple != table.triple {
            return Err(error(
                "aggregate_result_target_mismatch",
                format!("plan {}", plan.id),
            ));
        }
        let Some((mode, size, align, write_count, layout_name)) = shape(&plan.shape) else {
            return Err(error(
                "aggregate_result_unsupported_shape",
                format!("shape {}", plan.shape),
            ));
        };
        if plan.mode != mode || plan.size != size || plan.align != align {
            return Err(error(
                "aggregate_result_unsupported_shape",
                format!("classification {}", plan.id),
            ));
        }
        if !plan.layout.contains(layout_name)
            || !plan.layout.contains(&format!("size={}", plan.size))
            || !plan.layout.contains(&format!("align={}", plan.align))
            || !plan.type_id.contains(layout_name)
        {
            return Err(error(
                "aggregate_result_wrong_layout_or_alignment",
                format!("layout {}", plan.layout),
            ));
        }
        if plan.abi.is_empty()
            || plan.placement.is_empty()
            || plan.abi_value.is_empty()
            || plan.ordinal != 0
        {
            return Err(error(
                "aggregate_result_caller_callee_disagreement",
                format!("ABI {}", plan.id),
            ));
        }
        if plan.cleanup != "return_evaluation_then_phase15_cleanup_then_result_transfer"
            || plan.padding != "initialized_fields_only_padding_not_semantic"
            || plan.resource != "non_resource"
            || !plan.transition.is_empty()
        {
            return Err(error(
                "aggregate_result_caller_callee_disagreement",
                format!("policy {}", plan.id),
            ));
        }
        if !plan.published {
            return Err(error(
                "aggregate_result_uninitialized_publication",
                format!("plan {}", plan.id),
            ));
        }
        if plan.mode == "hidden_pointer" {
            if plan.storage.is_empty() || plan.hidden_parameter.is_empty() {
                return Err(error(
                    "aggregate_result_missing_hidden_storage",
                    format!("plan {}", plan.id),
                ));
            }
            if !hidden_storage.insert(plan.storage.as_str()) {
                return Err(error(
                    "aggregate_result_duplicate_hidden_identity",
                    format!("storage {}", plan.storage),
                ));
            }
            if plan.owner != "caller_compiler_plan"
                || plan.init_point != "before_call"
                || plan.callee_write != "write_all_initialized_fields_before_return"
                || plan.caller_extract != "after_successful_publication"
                || plan.failure != "do_not_publish_uninitialized_storage"
            {
                return Err(error(
                    "aggregate_result_backend_invented_storage",
                    format!("plan {}", plan.id),
                ));
            }
        } else if !plan.storage.is_empty() || !plan.hidden_parameter.is_empty() {
            return Err(error(
                "aggregate_result_caller_callee_disagreement",
                format!("unexpected hidden storage {}", plan.id),
            ));
        }
        let mut selected: Vec<_> = table.writes.iter().filter(|w| w.plan == plan.id).collect();
        selected.sort_by_key(|w| w.ordinal);
        if selected.len() != write_count
            || selected
                .iter()
                .enumerate()
                .any(|(i, w)| w.ordinal != i || !w.initialized)
        {
            return Err(error(
                "aggregate_result_uninitialized_publication",
                format!("writes {}", plan.id),
            ));
        }
        for write in selected {
            if write.size == 0 || write.offset + write.size > plan.size || write.align < plan.align
            {
                return Err(error(
                    "aggregate_result_wrong_layout_or_alignment",
                    format!("write {}", write.id),
                ));
            }
            let _returned_field_value = write.value;
        }
        let mut ops: Vec<_> = table
            .operations
            .iter()
            .filter(|o| o.plan == plan.id)
            .collect();
        ops.sort_by_key(|o| o.sequence);
        if ops
            .iter()
            .enumerate()
            .any(|(i, o)| o.sequence != i || !valid_operation(&o.kind))
        {
            return Err(error(
                "aggregate_result_caller_callee_disagreement",
                format!("operation sequence {}", plan.id),
            ));
        }
        if ops
            .iter()
            .any(|o| o.kind == "write_result_field" && o.terminal)
        {
            return Err(error(
                "aggregate_result_written_after_terminal",
                format!("plan {}", plan.id),
            ));
        }
        if !ops.iter().any(|o| o.kind == "publish_result")
            || !ops.iter().any(|o| o.kind == "extract_result")
        {
            return Err(error(
                "aggregate_result_uninitialized_publication",
                format!("publication {}", plan.id),
            ));
        }
        if plan.mode == "hidden_pointer"
            && (!ops
                .iter()
                .any(|o| o.kind == "allocate_hidden_storage" && o.storage == plan.storage)
                || ops
                    .iter()
                    .any(|o| !o.storage.is_empty() && o.storage != plan.storage))
        {
            return Err(error(
                "aggregate_result_backend_invented_storage",
                format!("operation storage {}", plan.id),
            ));
        }
    }
    Ok(())
}

pub fn lower_aggregate_result_witness_path(path: &Path) -> Result<String, AggregateResultError> {
    let contents = fs::read_to_string(path)
        .map_err(|cause| error("aggregate_result_request_read_failed", cause.to_string()))?;
    let table = parse(&contents)?;
    validate(&table)?;
    let mut witness = contents;
    if !witness.ends_with('\n') {
        witness.push('\n');
    }
    Ok(witness)
}

const _WORKER_POLICY:&str="worker_no_backend_local_aggregate_result_classifier_no_backend_invented_hidden_storage_no_generated_c_or_host_abi_guess";
