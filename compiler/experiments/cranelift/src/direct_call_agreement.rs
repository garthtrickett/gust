use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_direct_call_agreement.v1";

#[derive(Debug)]
pub struct DirectCallAgreementError {
    reason_code: &'static str,
    detail: String,
}

impl DirectCallAgreementError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}

impl fmt::Display for DirectCallAgreementError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_direct_call_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for DirectCallAgreementError {}

fn error(reason: &'static str, detail: impl Into<String>) -> DirectCallAgreementError {
    DirectCallAgreementError::new(reason, detail)
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, DirectCallAgreementError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("direct_call_unknown_format", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, DirectCallAgreementError> {
    let body = line
        .strip_prefix("direct_call_agreement:")
        .ok_or_else(|| error("direct_call_unknown_format", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|part| !part.is_empty()) {
        let Some((key, value)) = part.split_once('=') else {
            return Err(error(
                "direct_call_unknown_format",
                format!("invalid field {part}"),
            ));
        };
        if fields.insert(key.to_owned(), value.to_owned()).is_some() {
            return Err(error(
                "direct_call_duplicate_identity",
                format!("duplicate field {key}"),
            ));
        }
    }
    Ok(fields)
}

fn field<'a>(
    fields: &'a HashMap<String, String>,
    key: &str,
) -> Result<&'a str, DirectCallAgreementError> {
    fields
        .get(key)
        .map(String::as_str)
        .ok_or_else(|| error("direct_call_record_invalid", format!("missing {key}")))
}

fn same(
    fields: &HashMap<String, String>,
    expected: &str,
    actual: &str,
    reason: &'static str,
) -> Result<(), DirectCallAgreementError> {
    if field(fields, expected)? != field(fields, actual)? {
        return Err(error(reason, format!("{expected} disagrees with {actual}")));
    }
    Ok(())
}

fn supported_kind(value: &str) -> bool {
    matches!(
        value,
        "nested_direct" | "direct_recursion" | "mixed_scalar_aggregate" | "aggregate_result_chain"
    )
}

fn validate_row(
    fields: &HashMap<String, String>,
    target: &str,
    triple: &str,
) -> Result<(), DirectCallAgreementError> {
    for key in [
        "id",
        "call",
        "caller",
        "callee",
        "plan",
        "declaration_abi",
        "definition_abi",
        "expected_abi",
        "actual_abi",
        "source",
    ] {
        if field(fields, key)?.is_empty() {
            return Err(error("direct_call_record_invalid", format!("empty {key}")));
        }
    }
    if !supported_kind(field(fields, "kind")?) {
        return Err(error(
            "direct_call_record_invalid",
            "unsupported composition kind",
        ));
    }
    if field(fields, "target")? != target
        || field(fields, "actual_target")? != target
        || field(fields, "triple")? != triple
        || field(fields, "actual_triple")? != triple
    {
        return Err(error("direct_call_target_mismatch", field(fields, "id")?));
    }
    if field(fields, "freshness")? != "current_compiler_plan" {
        return Err(error("direct_call_stale_plan", field(fields, "id")?));
    }
    if field(fields, "compatible")? != "1" {
        return Err(error(
            "direct_call_caller_callee_disagreement",
            field(fields, "id")?,
        ));
    }
    same(
        fields,
        "declaration_abi",
        "definition_abi",
        "direct_call_signature_drift",
    )?;
    same(
        fields,
        "expected_abi",
        "actual_abi",
        "direct_call_signature_drift",
    )?;
    if field(fields, "expected_abi")? != field(fields, "declaration_abi")? {
        return Err(error("direct_call_signature_drift", field(fields, "id")?));
    }
    same(
        fields,
        "expected_signature",
        "actual_signature",
        "direct_call_signature_drift",
    )?;
    same(
        fields,
        "expected_cc",
        "actual_cc",
        "direct_call_calling_convention_mismatch",
    )?;
    if field(fields, "expected_cc")? != "gust" {
        return Err(error(
            "direct_call_calling_convention_mismatch",
            field(fields, "id")?,
        ));
    }
    same(
        fields,
        "expected_parameters",
        "actual_parameters",
        "direct_call_parameter_permutation",
    )?;
    same(
        fields,
        "expected_results",
        "actual_results",
        "direct_call_result_permutation",
    )?;
    same(
        fields,
        "expected_layouts",
        "actual_layouts",
        "direct_call_layout_mismatch",
    )?;
    same(
        fields,
        "expected_classes",
        "actual_classes",
        "direct_call_placement_class_mismatch",
    )?;
    same(
        fields,
        "expected_extensions",
        "actual_extensions",
        "direct_call_placement_class_mismatch",
    )?;
    same(
        fields,
        "expected_hidden",
        "actual_hidden",
        "direct_call_hidden_result_mismatch",
    )?;
    same(
        fields,
        "expected_transfers",
        "actual_transfers",
        "direct_call_resource_transfer_mismatch",
    )?;
    if field(fields, "expected_layouts")?.is_empty() || field(fields, "flow")?.is_empty() {
        return Err(error("direct_call_layout_mismatch", field(fields, "id")?));
    }
    if field(fields, "kind")? == "direct_recursion"
        && field(fields, "caller")? != field(fields, "callee")?
    {
        return Err(error(
            "direct_call_caller_callee_disagreement",
            "recursive call identity drift",
        ));
    }
    if field(fields, "kind")? == "aggregate_result_chain" {
        if field(fields, "flow")? != "producer_result_to_consumer_argument"
            || field(fields, "expected_hidden")? != "hidden_pointer:0"
        {
            return Err(error(
                "direct_call_hidden_result_mismatch",
                field(fields, "id")?,
            ));
        }
    }
    Ok(())
}

fn validate(contents: &str) -> Result<(), DirectCallAgreementError> {
    let lines: Vec<_> = contents.lines().collect();
    if header(&lines, "direct_call_format")? != FORMAT {
        return Err(error("direct_call_unknown_format", "unsupported format"));
    }
    let target = header(&lines, "direct_call_target_id")?;
    let triple = header(&lines, "direct_call_target_triple")?;
    let expected: usize = header(&lines, "direct_call_agreement_count")?
        .parse()
        .map_err(|_| error("direct_call_unknown_format", "invalid count"))?;
    let rows: Vec<_> = lines
        .iter()
        .filter(|line| line.starts_with("direct_call_agreement:"))
        .map(|line| row(line))
        .collect::<Result<_, _>>()?;
    if rows.len() != expected {
        return Err(error(
            "direct_call_record_invalid",
            "record count disagreement",
        ));
    }
    let mut ids = HashSet::new();
    let mut calls = HashSet::new();
    let mut kinds = HashSet::new();
    for fields in &rows {
        if !ids.insert(field(fields, "id")?) || !calls.insert(field(fields, "call")?) {
            return Err(error(
                "direct_call_duplicate_identity",
                field(fields, "id")?,
            ));
        }
        kinds.insert(field(fields, "kind")?);
        validate_row(fields, target, triple)?;
    }
    for required in [
        "nested_direct",
        "direct_recursion",
        "mixed_scalar_aggregate",
        "aggregate_result_chain",
    ] {
        if !kinds.contains(required) {
            return Err(error(
                "direct_call_record_invalid",
                format!("missing selected composition {required}"),
            ));
        }
    }
    Ok(())
}

pub fn lower_direct_call_agreement_witness_path(
    path: &Path,
) -> Result<String, DirectCallAgreementError> {
    let contents = fs::read_to_string(path)
        .map_err(|cause| error("direct_call_request_read_failed", cause.to_string()))?;
    validate(&contents)?;
    let mut witness = contents;
    if !witness.ends_with('\n') {
        witness.push('\n');
    }
    Ok(witness)
}

const _WORKER_POLICY: &str = "worker_consumes_compiler_direct_call_agreement_no_backend_signature_or_placement_reconstruction_no_generated_c_or_host_abi_guess";
