use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_unsized_abi.v1";
#[derive(Debug)]
pub struct UnsizedAbiError {
    reason_code: &'static str,
    detail: String,
}
impl UnsizedAbiError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}
impl fmt::Display for UnsizedAbiError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "gust_unsized_abi_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}
impl Error for UnsizedAbiError {}
fn error(reason: &'static str, detail: impl Into<String>) -> UnsizedAbiError {
    UnsizedAbiError::new(reason, detail)
}
fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, UnsizedAbiError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("unsized_unknown_format", format!("missing {key}")))
}
fn row(line: &str) -> Result<HashMap<String, String>, UnsizedAbiError> {
    let body = line
        .strip_prefix("unsized_plan:")
        .ok_or_else(|| error("unsized_unknown_format", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|part| !part.is_empty()) {
        let Some((key, value)) = part.split_once('=') else {
            return Err(error("unsized_unknown_format", part));
        };
        if fields.insert(key.into(), value.into()).is_some() {
            return Err(error("unsized_duplicate_identity", key));
        }
    }
    Ok(fields)
}
fn field<'a>(fields: &'a HashMap<String, String>, key: &str) -> Result<&'a str, UnsizedAbiError> {
    fields
        .get(key)
        .map(String::as_str)
        .ok_or_else(|| error("unsized_record_invalid", format!("missing {key}")))
}
fn same(
    fields: &HashMap<String, String>,
    left: &str,
    right: &str,
    reason: &'static str,
) -> Result<(), UnsizedAbiError> {
    if field(fields, left)? != field(fields, right)? {
        return Err(error(reason, format!("{left} disagrees with {right}")));
    }
    Ok(())
}
fn validate_row(
    fields: &HashMap<String, String>,
    target: &str,
    triple: &str,
) -> Result<(), UnsizedAbiError> {
    for key in [
        "id",
        "value",
        "data",
        "data_layout",
        "element_layout",
        "source",
    ] {
        if field(fields, key)?.is_empty() {
            return Err(error("unsized_record_invalid", key));
        }
    }
    let form = field(fields, "form")?;
    let position = field(fields, "position")?;
    if !matches!(
        (form, position),
        ("borrowed_slice_parameter", "parameter")
            | ("borrowed_slice_result", "result")
            | ("fixed_backing_local_slice_view", "local_view")
    ) {
        return Err(error("unsized_record_invalid", "form/position"));
    }
    if field(fields, "transport")? != "fat_pointer_data_and_length"
        || field(fields, "storage_plan")?.is_empty()
    {
        return Err(error(
            "unsized_by_value_without_storage_plan",
            field(fields, "id")?,
        ));
    }
    if field(fields, "metadata_present")? != "1"
        || field(fields, "metadata")?.is_empty()
        || field(fields, "metadata_kind")? != "length_elements_u64"
    {
        return Err(error("unsized_missing_metadata", field(fields, "id")?));
    }
    if field(fields, "length")? != "4"
        || field(fields, "actual_length")? != "4"
        || field(fields, "element_size")? != "4"
        || field(fields, "checked_size")? != "16"
        || field(fields, "actual_size")? != "16"
    {
        return Err(error(
            "unsized_inconsistent_length_or_layout",
            field(fields, "id")?,
        ));
    }
    if field(fields, "overflow_checked")? != "1"
        || !field(fields, "operations")?.contains("checked_size_multiply")
    {
        return Err(error("unsized_size_overflow", field(fields, "id")?));
    }
    if field(fields, "required_alignment")? != "4" || field(fields, "actual_alignment")? != "4" {
        return Err(error(
            "unsized_insufficient_alignment",
            field(fields, "id")?,
        ));
    }
    let length: i64 = field(fields, "length")?
        .parse()
        .map_err(|_| error("unsized_inconsistent_length_or_layout", "length"))?;
    let access: i64 = field(fields, "access_index")?
        .parse()
        .map_err(|_| error("unsized_bounds_violation", "index"))?;
    if field(fields, "bounds")? != "checked_index_less_than_length"
        || access < 0
        || access >= length
        || field(fields, "access_allowed")? != "1"
        || !field(fields, "operations")?.contains("bounds_check")
    {
        return Err(error("unsized_bounds_violation", field(fields, "id")?));
    }
    same(
        fields,
        "owner",
        "actual_owner",
        "unsized_invalid_storage_ownership",
    )?;
    same(
        fields,
        "lifetime",
        "actual_lifetime",
        "unsized_invalid_storage_ownership",
    )?;
    if field(fields, "owner")?.is_empty() || field(fields, "lifetime")?.is_empty() {
        return Err(error(
            "unsized_invalid_storage_ownership",
            field(fields, "id")?,
        ));
    }
    if position == "result" && field(fields, "owner")? != "caller_backing_borrowed_result" {
        return Err(error(
            "unsized_invalid_result_ownership",
            field(fields, "id")?,
        ));
    }
    let operations = field(fields, "operations")?;
    if !operations.contains("bind_unsized_data")
        || !operations.contains("bind_length_metadata")
        || !operations.contains("transport_unsized_view")
    {
        return Err(error("unsized_backend_invented_size", field(fields, "id")?));
    }
    if field(fields, "resource")? != "borrowed_no_transfer_state_live" {
        return Err(error(
            "unsized_resource_disposition_mismatch",
            field(fields, "id")?,
        ));
    }
    same(
        fields,
        "expected_value",
        "actual_value",
        "unsized_value_mismatch",
    )?;
    if target != "target:x86_64-unknown-linux-gnu"
        || triple != "x86_64-unknown-linux-gnu"
        || field(fields, "target")? != target
        || field(fields, "actual_target")? != target
        || field(fields, "triple")? != triple
        || field(fields, "actual_triple")? != triple
    {
        return Err(error("unsized_unsupported_target", field(fields, "id")?));
    }
    Ok(())
}
fn validate(contents: &str) -> Result<(), UnsizedAbiError> {
    let lines: Vec<_> = contents.lines().collect();
    if header(&lines, "unsized_format")? != FORMAT {
        return Err(error("unsized_unknown_format", "unsupported format"));
    }
    let target = header(&lines, "unsized_target_id")?;
    let triple = header(&lines, "unsized_target_triple")?;
    let count: usize = header(&lines, "unsized_plan_count")?
        .parse()
        .map_err(|_| error("unsized_unknown_format", "count"))?;
    let rows: Vec<_> = lines
        .iter()
        .filter(|line| line.starts_with("unsized_plan:"))
        .map(|line| row(line))
        .collect::<Result<_, _>>()?;
    if rows.len() != count || rows.is_empty() {
        return Err(error("unsized_record_invalid", "count"));
    }
    let mut ids = HashSet::new();
    let mut values = HashSet::new();
    let mut forms = HashSet::new();
    for fields in &rows {
        if !ids.insert(field(fields, "id")?) || !values.insert(field(fields, "value")?) {
            return Err(error("unsized_duplicate_identity", field(fields, "id")?));
        }
        forms.insert(field(fields, "form")?);
        validate_row(fields, target, triple)?;
    }
    for form in [
        "borrowed_slice_parameter",
        "borrowed_slice_result",
        "fixed_backing_local_slice_view",
    ] {
        if !forms.contains(form) {
            return Err(error("unsized_record_invalid", format!("missing {form}")));
        }
    }
    Ok(())
}
pub fn lower_unsized_abi_witness_path(path: &Path) -> Result<String, UnsizedAbiError> {
    let contents = fs::read_to_string(path)
        .map_err(|cause| error("unsized_request_read_failed", cause.to_string()))?;
    validate(&contents)?;
    let mut witness = contents;
    if !witness.ends_with('\n') {
        witness.push('\n');
    }
    Ok(witness)
}
const _WORKER_POLICY:&str="worker_consumes_compiler_unsized_data_metadata_element_layout_storage_lifetime_bounds_and_transport_no_backend_size_calculation";
