use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_dynamic_stack.v1";
const OPERATION_ORDER: &str = "checked_dynamic_size>aligned_stack_allocate>lifetime_start>write_element>read_element>resource_cleanup>lifetime_end>restore_stack";
const CLEANUP_ORDER: &str = "resource_cleanup_then_lifetime_end_then_stack_restore";

#[derive(Debug)]
pub struct DynamicStackError {
    reason_code: &'static str,
    detail: String,
}

impl DynamicStackError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}

impl fmt::Display for DynamicStackError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "gust_dynamic_stack_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for DynamicStackError {}

fn error(reason: &'static str, detail: impl Into<String>) -> DynamicStackError {
    DynamicStackError::new(reason, detail)
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, DynamicStackError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("dynamic_stack_unknown_format", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, DynamicStackError> {
    let body = line
        .strip_prefix("dynamic_stack_plan:")
        .ok_or_else(|| error("dynamic_stack_unknown_format", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|part| !part.is_empty()) {
        let Some((key, value)) = part.split_once('=') else {
            return Err(error("dynamic_stack_unknown_format", part));
        };
        if fields.insert(key.into(), value.into()).is_some() {
            return Err(error("dynamic_stack_duplicate_identity", key));
        }
    }
    Ok(fields)
}

fn field<'a>(fields: &'a HashMap<String, String>, key: &str) -> Result<&'a str, DynamicStackError> {
    fields
        .get(key)
        .map(String::as_str)
        .ok_or_else(|| error("dynamic_stack_record_invalid", format!("missing {key}")))
}

fn number(fields: &HashMap<String, String>, key: &str) -> Result<i64, DynamicStackError> {
    field(fields, key)?
        .parse()
        .map_err(|_| error("dynamic_stack_record_invalid", key))
}

fn same(
    fields: &HashMap<String, String>,
    left: &str,
    right: &str,
    reason: &'static str,
) -> Result<(), DynamicStackError> {
    if field(fields, left)? != field(fields, right)? {
        return Err(error(reason, format!("{left} disagrees with {right}")));
    }
    Ok(())
}

fn validate_row(
    fields: &HashMap<String, String>,
    target: &str,
    triple: &str,
) -> Result<(), DynamicStackError> {
    for key in [
        "id",
        "storage",
        "function",
        "scope",
        "size_operand",
        "element_layout",
        "lifetime_start",
        "lifetime_end",
        "restore_point",
        "source",
    ] {
        if field(fields, key)?.is_empty() {
            return Err(error("dynamic_stack_record_invalid", key));
        }
    }
    if !matches!(
        (field(fields, "form")?, field(fields, "exit_kind")?),
        ("bounded_vla_normal_exit", "normal_return")
            | ("bounded_vla_early_return", "early_return")
            | ("bounded_nested_vla", "normal_return")
    ) {
        return Err(error("dynamic_stack_record_invalid", "form/exit"));
    }
    if field(fields, "size_dominates")? != "1" {
        return Err(error(
            "dynamic_stack_non_dominating_size",
            field(fields, "id")?,
        ));
    }
    let count = number(fields, "element_count")?;
    let element_size = number(fields, "element_size")?;
    let checked_size = number(fields, "checked_size")?;
    if !(0..=1024).contains(&count)
        || element_size != 4
        || checked_size != count * element_size
        || number(fields, "actual_size")? != checked_size
        || number(fields, "maximum_size")? != 4096
        || checked_size > 4096
    {
        return Err(error(
            "dynamic_stack_size_limit_exceeded",
            field(fields, "id")?,
        ));
    }
    if field(fields, "overflow_checked")? != "1"
        || !field(fields, "operations")?.contains("checked_dynamic_size")
    {
        return Err(error(
            "dynamic_stack_unchecked_overflow",
            field(fields, "id")?,
        ));
    }
    if field(fields, "required_alignment")? != "4" || field(fields, "actual_alignment")? != "4" {
        return Err(error(
            "dynamic_stack_unsupported_alignment",
            field(fields, "id")?,
        ));
    }
    if field(fields, "zero_size_policy")? != "allow_zero_bytes_preserve_restore_marker"
        || !(0..=2).contains(&number(fields, "nesting_depth")?)
    {
        return Err(error("dynamic_stack_record_invalid", field(fields, "id")?));
    }
    if field(fields, "use_within_lifetime")? != "1"
        || !field(fields, "operations")?.contains("lifetime_start")
        || !field(fields, "operations")?.contains("lifetime_end")
    {
        return Err(error(
            "dynamic_stack_use_outside_lifetime",
            field(fields, "id")?,
        ));
    }
    if field(fields, "restoration_present")? != "1"
        || !field(fields, "operations")?.contains("restore_stack")
    {
        return Err(error(
            "dynamic_stack_missing_restoration",
            field(fields, "id")?,
        ));
    }
    if !field(fields, "operations")?.contains("aligned_stack_allocate") {
        return Err(error(
            "dynamic_stack_backend_invented_size",
            field(fields, "id")?,
        ));
    }
    if field(fields, "resource_cleanup_complete")? != "1"
        || field(fields, "restoration_after_cleanup")? != "1"
        || field(fields, "cleanup_order")? != CLEANUP_ORDER
        || field(fields, "operations")? != OPERATION_ORDER
    {
        return Err(error(
            "dynamic_stack_restore_before_cleanup",
            field(fields, "id")?,
        ));
    }
    same(
        fields,
        "expected_value",
        "actual_value",
        "dynamic_stack_value_mismatch",
    )?;
    if target != "target:x86_64-unknown-linux-gnu"
        || triple != "x86_64-unknown-linux-gnu"
        || field(fields, "target")? != target
        || field(fields, "actual_target")? != target
        || field(fields, "triple")? != triple
        || field(fields, "actual_triple")? != triple
    {
        return Err(error(
            "dynamic_stack_unsupported_target",
            field(fields, "id")?,
        ));
    }
    Ok(())
}

fn validate(contents: &str) -> Result<(), DynamicStackError> {
    let lines: Vec<_> = contents.lines().collect();
    if header(&lines, "dynamic_stack_format")? != FORMAT {
        return Err(error("dynamic_stack_unknown_format", "unsupported format"));
    }
    let target = header(&lines, "dynamic_stack_target_id")?;
    let triple = header(&lines, "dynamic_stack_target_triple")?;
    let count: usize = header(&lines, "dynamic_stack_plan_count")?
        .parse()
        .map_err(|_| error("dynamic_stack_unknown_format", "count"))?;
    let rows: Vec<_> = lines
        .iter()
        .filter(|line| line.starts_with("dynamic_stack_plan:"))
        .map(|line| row(line))
        .collect::<Result<_, _>>()?;
    if rows.len() != count || rows.is_empty() {
        return Err(error("dynamic_stack_record_invalid", "count"));
    }
    let mut ids = HashSet::new();
    let mut storage_ids = HashSet::new();
    let mut forms = HashSet::new();
    for fields in &rows {
        if !ids.insert(field(fields, "id")?) || !storage_ids.insert(field(fields, "storage")?) {
            return Err(error(
                "dynamic_stack_duplicate_identity",
                field(fields, "id")?,
            ));
        }
        forms.insert(field(fields, "form")?);
        validate_row(fields, target, triple)?;
    }
    for form in [
        "bounded_vla_normal_exit",
        "bounded_vla_early_return",
        "bounded_nested_vla",
    ] {
        if !forms.contains(form) {
            return Err(error(
                "dynamic_stack_record_invalid",
                format!("missing {form}"),
            ));
        }
    }
    Ok(())
}

pub fn lower_dynamic_stack_witness_path(path: &Path) -> Result<String, DynamicStackError> {
    let contents = fs::read_to_string(path)
        .map_err(|cause| error("dynamic_stack_request_read_failed", cause.to_string()))?;
    validate(&contents)?;
    let mut witness = contents;
    if !witness.ends_with('\n') {
        witness.push('\n');
    }
    Ok(witness)
}

const _WORKER_POLICY: &str = "worker_consumes_compiler_dynamic_size_alignment_lifetime_cleanup_and_restore_plan_no_backend_frame_planner";
