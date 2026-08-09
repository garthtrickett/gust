use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;
const FORMAT: &str = "gust.compiler_typed_indirect_call.v1";
#[derive(Debug)]
pub struct TypedIndirectCallError {
    reason_code: &'static str,
    detail: String,
}
impl TypedIndirectCallError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}
impl fmt::Display for TypedIndirectCallError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "gust_typed_indirect_call_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}
impl Error for TypedIndirectCallError {}
fn error(reason: &'static str, detail: impl Into<String>) -> TypedIndirectCallError {
    TypedIndirectCallError::new(reason, detail)
}
fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, TypedIndirectCallError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("typed_indirect_unknown_format", format!("missing {key}")))
}
fn row(line: &str) -> Result<HashMap<String, String>, TypedIndirectCallError> {
    let body = line
        .strip_prefix("typed_indirect_call:")
        .ok_or_else(|| error("typed_indirect_unknown_format", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((key, value)) = part.split_once('=') else {
            return Err(error("typed_indirect_unknown_format", part));
        };
        if fields.insert(key.into(), value.into()).is_some() {
            return Err(error("typed_indirect_duplicate_identity", key));
        }
    }
    Ok(fields)
}
fn field<'a>(f: &'a HashMap<String, String>, key: &str) -> Result<&'a str, TypedIndirectCallError> {
    f.get(key)
        .map(String::as_str)
        .ok_or_else(|| error("typed_indirect_record_invalid", format!("missing {key}")))
}
fn same(
    f: &HashMap<String, String>,
    a: &str,
    b: &str,
    reason: &'static str,
) -> Result<(), TypedIndirectCallError> {
    if field(f, a)? != field(f, b)? {
        return Err(error(reason, format!("{a} disagrees with {b}")));
    }
    Ok(())
}
fn validate_row(
    f: &HashMap<String, String>,
    target: &str,
    triple: &str,
) -> Result<(), TypedIndirectCallError> {
    for key in [
        "id",
        "function_value",
        "selected",
        "expected_abi",
        "actual_abi",
        "source",
    ] {
        if field(f, key)?.is_empty() {
            return Err(error("typed_indirect_record_invalid", key));
        }
    }
    if !matches!(
        field(f, "form")?,
        "compatible_function_selection" | "typed_function_value_parameter"
    ) {
        return Err(error("typed_indirect_record_invalid", "form"));
    }
    if field(f, "expected_signature")?.is_empty() || field(f, "actual_signature")?.is_empty() {
        return Err(error("typed_indirect_unknown_signature", field(f, "id")?));
    }
    same(
        f,
        "expected_signature",
        "actual_signature",
        "typed_indirect_incompatible_function_value",
    )?;
    same(
        f,
        "expected_parameters",
        "actual_parameters",
        "typed_indirect_incompatible_function_value",
    )?;
    same(
        f,
        "expected_results",
        "actual_results",
        "typed_indirect_incompatible_function_value",
    )?;
    if !field(f, "operations")?.contains("create_typed_function_value")
        || !field(f, "operations")?.contains("typed_indirect_call")
    {
        return Err(error("typed_indirect_signature_erasure", field(f, "id")?));
    }
    if field(f, "nullability")? != "non_null" || field(f, "is_null")? != "0" {
        return Err(error("typed_indirect_null_call", field(f, "id")?));
    }
    if field(f, "cc")? != "gust" {
        return Err(error(
            "typed_indirect_unsupported_calling_convention",
            field(f, "id")?,
        ));
    }
    if field(f, "variadic")? != "0" {
        return Err(error(
            "typed_indirect_variadic_not_selected",
            field(f, "id")?,
        ));
    }
    if field(f, "pointer_policy")? != "compiler_typed_function_value_no_pointer_cast" {
        return Err(error(
            "typed_indirect_unvalidated_pointer_cast",
            field(f, "id")?,
        ));
    }
    if field(f, "transfers")? != "non_resource_copy" {
        return Err(error(
            "typed_indirect_resource_transfer_mismatch",
            field(f, "id")?,
        ));
    }
    if field(f, "target")? != target
        || field(f, "actual_target")? != target
        || field(f, "triple")? != triple
        || field(f, "actual_triple")? != triple
    {
        return Err(error("typed_indirect_target_mismatch", field(f, "id")?));
    }
    if field(f, "form")? == "compatible_function_selection"
        && (!field(f, "candidates")?.contains(field(f, "expected_abi")?)
            || !field(f, "candidates")?.contains(field(f, "actual_abi")?)
            || !field(f, "operations")?.contains("select_compatible_function"))
    {
        return Err(error(
            "typed_indirect_incompatible_function_value",
            field(f, "id")?,
        ));
    }
    if field(f, "form")? == "typed_function_value_parameter"
        && !field(f, "operations")?.contains("pass_typed_function_value")
    {
        return Err(error("typed_indirect_signature_erasure", field(f, "id")?));
    }
    Ok(())
}
fn validate(contents: &str) -> Result<(), TypedIndirectCallError> {
    let lines: Vec<_> = contents.lines().collect();
    if header(&lines, "typed_indirect_format")? != FORMAT {
        return Err(error("typed_indirect_unknown_format", "unsupported format"));
    }
    let target = header(&lines, "typed_indirect_target_id")?;
    let triple = header(&lines, "typed_indirect_target_triple")?;
    let count: usize = header(&lines, "typed_indirect_call_count")?
        .parse()
        .map_err(|_| error("typed_indirect_unknown_format", "count"))?;
    let rows: Vec<_> = lines
        .iter()
        .filter(|line| line.starts_with("typed_indirect_call:"))
        .map(|line| row(line))
        .collect::<Result<_, _>>()?;
    if rows.len() != count {
        return Err(error("typed_indirect_record_invalid", "count"));
    }
    let mut ids = HashSet::new();
    let mut values = HashSet::new();
    let mut forms = HashSet::new();
    for f in &rows {
        if !ids.insert(field(f, "id")?) || !values.insert(field(f, "function_value")?) {
            return Err(error("typed_indirect_duplicate_identity", field(f, "id")?));
        }
        forms.insert(field(f, "form")?);
        validate_row(f, target, triple)?;
    }
    for form in [
        "compatible_function_selection",
        "typed_function_value_parameter",
    ] {
        if !forms.contains(form) {
            return Err(error(
                "typed_indirect_record_invalid",
                format!("missing {form}"),
            ));
        }
    }
    Ok(())
}
pub fn lower_typed_indirect_call_witness_path(
    path: &Path,
) -> Result<String, TypedIndirectCallError> {
    let contents = fs::read_to_string(path)
        .map_err(|e| error("typed_indirect_request_read_failed", e.to_string()))?;
    validate(&contents)?;
    let mut witness = contents;
    if !witness.ends_with('\n') {
        witness.push('\n');
    }
    Ok(witness)
}
const _WORKER_POLICY:&str="worker_consumes_complete_compiler_typed_function_abi_no_signature_erasure_no_backend_indirect_signature_reconstruction_no_pointer_cast_guess";
