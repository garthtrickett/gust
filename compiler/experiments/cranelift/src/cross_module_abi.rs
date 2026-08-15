use std::collections::{HashMap, HashSet};
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;
const FORMAT: &str = "gust.compiler_cross_module_abi.v1";
#[derive(Debug)]
pub struct CrossModuleAbiError {
    reason_code: &'static str,
    detail: String,
}
impl CrossModuleAbiError {
    fn new(reason_code: &'static str, detail: impl Into<String>) -> Self {
        Self {
            reason_code,
            detail: detail.into(),
        }
    }
}
impl fmt::Display for CrossModuleAbiError {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            f,
            "gust_cross_module_abi_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}
impl Error for CrossModuleAbiError {}
fn error(reason: &'static str, detail: impl Into<String>) -> CrossModuleAbiError {
    CrossModuleAbiError::new(reason, detail)
}
fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, CrossModuleAbiError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("cross_module_unknown_format", key))
}
fn row(line: &str) -> Result<HashMap<String, String>, CrossModuleAbiError> {
    let body = line
        .strip_prefix("cross_module_plan:")
        .ok_or_else(|| error("cross_module_unknown_format", "row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|p| !p.is_empty()) {
        let Some((k, v)) = part.split_once('=') else {
            return Err(error("cross_module_unknown_format", part));
        };
        if fields.insert(k.into(), v.into()).is_some() {
            return Err(error("cross_module_duplicate_identity", k));
        }
    }
    Ok(fields)
}
fn field<'a>(f: &'a HashMap<String, String>, k: &str) -> Result<&'a str, CrossModuleAbiError> {
    f.get(k)
        .map(String::as_str)
        .ok_or_else(|| error("cross_module_missing_abi_descriptor", k))
}
fn same(
    f: &HashMap<String, String>,
    a: &str,
    b: &str,
    r: &'static str,
) -> Result<(), CrossModuleAbiError> {
    if field(f, a)? != field(f, b)? {
        return Err(error(r, a));
    }
    Ok(())
}
fn validate_row(f: &HashMap<String, String>, target: &str) -> Result<(), CrossModuleAbiError> {
    for k in [
        "id",
        "exporter",
        "importer",
        "symbol",
        "export_abi",
        "import_abi",
        "export_signature",
        "import_signature",
        "export_layout",
        "import_layout",
        "source",
    ] {
        if field(f, k)?.is_empty() {
            return Err(error("cross_module_missing_abi_descriptor", k));
        }
    }
    if !matches!(
        field(f, "scenario")?,
        "aggregate_parameter"
            | "aggregate_result"
            | "resource_aggregate_transfer"
            | "multiple_selected_modules"
    ) {
        return Err(error("cross_module_missing_abi_descriptor", "scenario"));
    }
    if field(f, "same_version")? != "1" {
        return Err(error("cross_module_stale_import", field(f, "id")?));
    }
    if field(f, "foreign")? != "0" {
        return Err(error(
            "cross_module_unsupported_foreign_symbol",
            field(f, "id")?,
        ));
    }
    if field(f, "linkage")? != "same_version_gust_static"
        || field(f, "symbol_authority")? != "compiler_semantic_module_and_declaration_identity"
    {
        return Err(error(
            "cross_module_missing_abi_descriptor",
            field(f, "id")?,
        ));
    }
    same(
        f,
        "export_abi",
        "import_abi",
        "cross_module_signature_mismatch",
    )?;
    same(
        f,
        "export_signature",
        "import_signature",
        "cross_module_signature_mismatch",
    )?;
    if field(f, "export_target")? != target || field(f, "import_target")? != target {
        return Err(error("cross_module_target_mismatch", field(f, "id")?));
    }
    if field(f, "export_cc")? != "gust_canonical_v1" {
        return Err(error(
            "cross_module_calling_convention_mismatch",
            field(f, "id")?,
        ));
    }
    same(
        f,
        "export_cc",
        "import_cc",
        "cross_module_calling_convention_mismatch",
    )?;
    same(
        f,
        "export_layout",
        "import_layout",
        "cross_module_layout_mismatch",
    )?;
    same(
        f,
        "export_placement",
        "import_placement",
        "cross_module_placement_mismatch",
    )?;
    same(
        f,
        "export_hidden",
        "import_hidden",
        "cross_module_hidden_result_mismatch",
    )?;
    same(
        f,
        "export_resource",
        "import_resource",
        "cross_module_resource_policy_mismatch",
    )?;
    if field(f, "artifact_owner")? != "phase9g_owns_object_link_temporary_and_atomic_publication" {
        return Err(error(
            "cross_module_artifact_ownership_mismatch",
            field(f, "id")?,
        ));
    }
    same(
        f,
        "expected_value",
        "actual_value",
        "cross_module_value_mismatch",
    )?;
    Ok(())
}
fn validate(contents: &str) -> Result<(), CrossModuleAbiError> {
    let lines: Vec<_> = contents.lines().collect();
    if header(&lines, "cross_module_format")? != FORMAT {
        return Err(error("cross_module_unknown_format", "format"));
    }
    let target = header(&lines, "cross_module_target_id")?;
    let count: usize = header(&lines, "cross_module_plan_count")?
        .parse()
        .map_err(|_| error("cross_module_unknown_format", "count"))?;
    let rows: Vec<_> = lines
        .iter()
        .filter(|l| l.starts_with("cross_module_plan:"))
        .map(|l| row(l))
        .collect::<Result<_, _>>()?;
    if rows.len() != count || rows.is_empty() {
        return Err(error("cross_module_missing_abi_descriptor", "count"));
    }
    let mut ids = HashSet::new();
    let mut symbols = HashSet::new();
    let mut scenarios = HashSet::new();
    for f in &rows {
        if !ids.insert(field(f, "id")?) || !symbols.insert(field(f, "symbol")?) {
            return Err(error("cross_module_duplicate_identity", field(f, "id")?));
        }
        scenarios.insert(field(f, "scenario")?);
        validate_row(f, target)?;
    }
    for s in [
        "aggregate_parameter",
        "aggregate_result",
        "resource_aggregate_transfer",
        "multiple_selected_modules",
    ] {
        if !scenarios.contains(s) {
            return Err(error("cross_module_missing_abi_descriptor", s));
        }
    }
    Ok(())
}
pub fn lower_cross_module_abi_witness_path(path: &Path) -> Result<String, CrossModuleAbiError> {
    let contents = fs::read_to_string(path)
        .map_err(|e| error("cross_module_request_read_failed", e.to_string()))?;
    validate(&contents)?;
    let mut witness = contents;
    if !witness.ends_with('\n') {
        witness.push('\n');
    }
    Ok(witness)
}
const _WORKER_POLICY:&str="worker_consumes_compiler_cross_module_signature_target_layout_placement_hidden_result_resource_and_symbol_descriptors_no_backend_abi_invention";
