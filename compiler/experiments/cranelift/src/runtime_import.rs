//! Phase 17.5 stable runtime-library imports.
//!
//! The worker consumes the compiler-produced runtime-import request and emits a
//! witness that must match MIR-to-C byte for byte. Every symbol spelling,
//! version, and signature comes from the request. This module deliberately
//! keeps no table of its own: if the compiler did not declare an import, the
//! backend has no licence to invent one.

use std::collections::HashMap;
use std::error::Error;
use std::fmt;
use std::fs;
use std::path::Path;

const FORMAT: &str = "gust.compiler_runtime_import.v1";
const WITNESS_FORMAT: &str = "gust.runtime_import_witness.v1";
const SUPPORTED_SYMBOL_VERSION: &str = "gust-runtime-symbol-v1";
const STABLE_COMPONENT_KIND: &str = "kind=stable_runtime_library_function";
const LINKAGE: &str = "direct_external_call_no_generated_c_glue";

const SIDE_EFFECT_POLICIES: [&str; 3] = [
    "pure_scalar_no_side_effects",
    "observable_side_effects",
    "allocates_in_caller_arena",
];
const FAILURE_POLICIES: [&str; 3] = [
    "total_cannot_fail",
    "returns_explicit_error",
    "aborts_process_on_failure",
];

#[derive(Debug)]
pub struct RuntimeImportError {
    reason_code: &'static str,
    detail: String,
}

impl fmt::Display for RuntimeImportError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(
            formatter,
            "gust_runtime_import_error: reason={} detail={}",
            self.reason_code, self.detail
        )
    }
}

impl Error for RuntimeImportError {}

fn error(reason: &'static str, detail: impl Into<String>) -> RuntimeImportError {
    RuntimeImportError {
        reason_code: reason,
        detail: detail.into(),
    }
}

/// One compiler-declared runtime import, with the signature derived from the
/// compiler-owned function ABI identity rather than a backend lookup table.
#[derive(Debug, Clone)]
pub struct RuntimeImport {
    pub external_spelling: String,
    pub symbol_version: String,
    pub function_abi_id: String,
    pub component_id: String,
    pub package_id: String,
    pub side_effect_policy: String,
    pub failure_policy: String,
    pub parameter_count: usize,
}

fn header<'a>(lines: &'a [&str], key: &str) -> Result<&'a str, RuntimeImportError> {
    let prefix = format!("{key}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix))
        .ok_or_else(|| error("runtime_import_undeclared", format!("missing {key}")))
}

fn row(line: &str) -> Result<HashMap<String, String>, RuntimeImportError> {
    let body = line
        .strip_prefix("runtime_import:")
        .ok_or_else(|| error("runtime_import_undeclared", "invalid row"))?;
    let mut fields = HashMap::new();
    for part in body.split(';').filter(|part| !part.is_empty()) {
        // Identities embed '=' internally, so only the first separator splits.
        let Some((key, value)) = part.split_once('=') else {
            return Err(error(
                "runtime_import_undeclared",
                format!("invalid field {part}"),
            ));
        };
        if fields.insert(key.to_owned(), value.to_owned()).is_some() {
            return Err(error(
                "runtime_import_undeclared",
                format!("duplicate field {key}"),
            ));
        }
    }
    Ok(fields)
}

fn field<'a>(
    fields: &'a HashMap<String, String>,
    key: &str,
) -> Result<&'a str, RuntimeImportError> {
    fields
        .get(key)
        .map(String::as_str)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| error("runtime_import_undeclared", format!("missing {key}")))
}

/// The signature is read out of the compiler's function ABI identity, which has
/// the shape `function_abi:runtime:<spelling>:<params>_to_<result>:<cc>`.
fn parameter_count(function_abi_id: &str, spelling: &str) -> Result<usize, RuntimeImportError> {
    let expected_prefix = format!("function_abi:runtime:{spelling}:");
    let remainder = function_abi_id
        .strip_prefix(&expected_prefix)
        .ok_or_else(|| {
            error(
                "runtime_import_abi_mismatch",
                format!("{function_abi_id} does not describe {spelling}"),
            )
        })?;
    let signature = remainder.strip_suffix(":gust_canonical_v1").ok_or_else(|| {
        error(
            "runtime_import_abi_mismatch",
            format!("{function_abi_id} is not a canonical Gust signature"),
        )
    })?;
    let (parameters, result) = signature.split_once("_to_").ok_or_else(|| {
        error(
            "runtime_import_abi_mismatch",
            format!("{signature} has no result"),
        )
    })?;
    if result != "i32" {
        return Err(error(
            "runtime_import_abi_mismatch",
            format!("unsupported scalar result {result}"),
        ));
    }
    let mut count = 0usize;
    for parameter in parameters.split('_') {
        if parameter != "i32" {
            return Err(error(
                "runtime_import_abi_mismatch",
                format!("unsupported scalar parameter {parameter}"),
            ));
        }
        count += 1;
    }
    Ok(count)
}

fn parse_row(
    fields: &HashMap<String, String>,
    target: &str,
) -> Result<RuntimeImport, RuntimeImportError> {
    for key in ["id", "helper", "symbol", "spelling"] {
        if field(fields, key).is_err() {
            return Err(error(
                "runtime_import_missing_symbol",
                format!("missing {key}"),
            ));
        }
    }
    let spelling = field(fields, "spelling")?;
    let symbol = field(fields, "symbol")?;
    if !symbol.contains(spelling) {
        return Err(error(
            "runtime_import_missing_symbol",
            format!("symbol {symbol} does not carry {spelling}"),
        ));
    }

    let version = field(fields, "version")?;
    if version != SUPPORTED_SYMBOL_VERSION {
        return Err(error(
            "runtime_import_incompatible_version",
            format!("unsupported symbol version {version}"),
        ));
    }

    let function_abi_id = field(fields, "function_abi")?;
    let parameter_count = parameter_count(function_abi_id, spelling)?;

    // Only stable runtime-library components are migrated by this patch, and the
    // import must belong to the target the request was produced for.
    let component_id = field(fields, "component")?;
    if !component_id.contains(STABLE_COMPONENT_KIND) {
        return Err(error(
            "runtime_import_wrong_target_component",
            format!("{component_id} is not a stable runtime-library component"),
        ));
    }
    let row_target = field(fields, "target")?;
    if row_target != target {
        return Err(error(
            "runtime_import_wrong_target_component",
            format!("{row_target} disagrees with request target"),
        ));
    }
    if field(fields, "applicability")?.is_empty() {
        return Err(error("runtime_import_wrong_target_component", "no applicability"));
    }

    let side_effect_policy = field(fields, "side_effects")?;
    if !SIDE_EFFECT_POLICIES.contains(&side_effect_policy) {
        return Err(error(
            "runtime_import_undeclared",
            format!("undeclared side-effect policy {side_effect_policy}"),
        ));
    }
    let failure_policy = field(fields, "failure")?;
    if !FAILURE_POLICIES.contains(&failure_policy) {
        return Err(error(
            "runtime_import_undeclared",
            format!("undeclared failure policy {failure_policy}"),
        ));
    }

    Ok(RuntimeImport {
        external_spelling: spelling.to_owned(),
        symbol_version: version.to_owned(),
        function_abi_id: function_abi_id.to_owned(),
        component_id: component_id.to_owned(),
        package_id: field(fields, "package")?.to_owned(),
        side_effect_policy: side_effect_policy.to_owned(),
        failure_policy: failure_policy.to_owned(),
        parameter_count,
    })
}

pub fn parse_runtime_import_request(
    request: &str,
) -> Result<(String, Vec<RuntimeImport>), RuntimeImportError> {
    let lines: Vec<&str> = request.lines().collect();
    let format = header(&lines, "format")?;
    if format != FORMAT {
        return Err(error(
            "runtime_import_undeclared",
            format!("unknown format {format}"),
        ));
    }
    let target = header(&lines, "target")?.to_owned();
    header(&lines, "triple")?;

    let mut imports = Vec::new();
    let mut spellings = Vec::new();
    for line in lines.iter().filter(|line| line.starts_with("runtime_import:")) {
        let fields = row(line)?;
        let import = parse_row(&fields, &target)?;
        if spellings.contains(&import.external_spelling) {
            return Err(error(
                "runtime_import_undeclared",
                format!("duplicate import {}", import.external_spelling),
            ));
        }
        spellings.push(import.external_spelling.clone());
        imports.push(import);
    }
    if imports.is_empty() {
        return Err(error("runtime_import_missing_symbol", "no declared imports"));
    }
    Ok((target, imports))
}

pub fn render_runtime_import_witness(target: &str, imports: &[RuntimeImport]) -> String {
    let mut output = format!("witness: {WITNESS_FORMAT}\ntarget: {target}\n");
    for import in imports {
        output.push_str("import:");
        output.push_str(&format!("spelling={};", import.external_spelling));
        output.push_str(&format!("version={};", import.symbol_version));
        output.push_str(&format!("function_abi={};", import.function_abi_id));
        output.push_str(&format!("component={};", import.component_id));
        output.push_str(&format!("package={};", import.package_id));
        output.push_str(&format!("side_effects={};", import.side_effect_policy));
        output.push_str(&format!("failure={};", import.failure_policy));
        output.push_str(&format!("linkage={LINKAGE};"));
        output.push('\n');
    }
    output
}

pub fn lower_runtime_import_witness_path(path: &Path) -> Result<String, Box<dyn Error>> {
    let request = fs::read_to_string(path)?;
    let (target, imports) = parse_runtime_import_request(&request)?;
    Ok(render_runtime_import_witness(&target, &imports))
}
